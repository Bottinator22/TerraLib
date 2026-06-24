-- Allows easily sharing tables locally without the use of metatables.
-- Target entities must be local (same master).
-- Entity messages are immediately resolved when created for local entities.

-- TODO: clean this up. keys are transferred, which kinda defeats the point of the whole metatable thing on proxies.

-- TODO: fix pcall with proxies. if an error is thrown it will error the proxy, not the calling script.

-- TODO: the current userdata handling system only works for engine userdatas; anything userdata-like won't work. so anything trying to pretend to be a userdata won't work
-- TODO: also won't work when layering proxies on proxies

terra_proxy = {}
local cleanupRequests = {}
local userdataSentProxies = {}
local userdataReceivedProxies = {}
local userdataReceivedProxies_uuids = {}

setmetatable(userdataReceivedProxies,{__mode="v"})

local function makeUserdataProxy(ud,callMsg,delMsg,existsMsg)
    local uuid = sb.makeUuid()
    local obj = {userdata=ud}
    local out = {terra_proxy_special=true,terra_proxy_id=uuid,terra_proxy_callMsg=callMsg,terra_proxy_delMsg=delMsg,terra_proxy_existsMsg=existsMsg}
    userdataSentProxies[uuid] = obj
    return out
end
local lastCleaned = 0
local function cleanUserdata()
    if lastCleaned == world.time() then
        return
    end
    lastCleaned = world.time()
    for k,v in next, userdataReceivedProxies_uuids do
        if not userdataReceivedProxies[k] then
            world.sendEntityMessage(v.eid,v.msg,k)
            userdataReceivedProxies_uuids[k] = nil
        end
    end
end
local function maybeUserdata(v,entityId)
    if type(v) == "table" and v.terra_proxy_special then
        local proxy = {terra_proxy_id=v.terra_proxy_id}
        userdataReceivedProxies_uuids[v.terra_proxy_id] = {msg=v.terra_proxy_delMsg,eid=entityId}
        userdataReceivedProxies[v.terra_proxy_id] = proxy
        setmetatable(proxy,{__index=function(t,k)
            if world.sendEntityMessage(entityId,v.terra_proxy_existsMsg,v.terra_proxy_id,k):result() then
                local func = function(t,...)
                    cleanUserdata()
                    local p = world.sendEntityMessage(entityId,v.terra_proxy_callMsg,v.terra_proxy_id,k,...)
                    return maybeUserdata(p:result(),entityId)
                end
                t[k] = func
                return func
            else
                t[k] = nil
            end
        end})
        return proxy
    else
        return v
    end
end
-- senders
-- both of these functions return a function that will clean up the message handlers, in case it's needed
-- sets up the proxy for messages
local function iterateMessages(name,t,f,msgs)
    -- does this table extend something? if so, setup handlers for its index as well
    local keys = {}
    local mt = getmetatable(t)
    if mt and mt.__index then
        if type(mt.__index) == "table" then
            keys = iterateMessages(name,mt.__index,f,msgs)
        elseif mt.terra_keys then
            for _,k in next, mt.terra_keys do
                local v = t[k]
                if type(v) == "function" then
                    local msg = string.format(f,k)
                    message.setHandler(msg,function(_,isLocal,...)
                        if not isLocal then return end
                        return v(...)
                    end)
                    table.insert(msgs,msg)
                end
            end
        else
            sb.logWarn(string.format("Iterating through messages for proxy %s: Table __index is a function, and no keys are specified!",name))
        end
    end
    for k,v in next, t do
        table.insert(keys,k)
        if type(v) == "function" then
            local msg = string.format(f,k)
            message.setHandler(msg,function(_,isLocal,...)
                if not isLocal then return end
                local out = v(...)
                if type(out) == "userdata" then
                    return makeUserdataProxy(out,msgs[5],msgs[6],msgs[7])
                end
                return out
            end)
            table.insert(msgs,msg)
        end
    end
    return keys
end
local function doCleanup()
    local newCleanupRequests = {}
    for _,v in next, cleanupRequests do
        if world.time() < v.time then
            v.func()
        else
            table.insert(newCleanupRequests,v)
        end
    end
    cleanupRequests = newCleanupRequests
end
function terra_proxy.setupReceiveMessages(name,t)
    doCleanup()
    local f = string.format("%s.%%s",name)
    local msgs = {
        string.format(f,"terra_proxy_mode"),
        string.format(f,"terra_proxy_msgs"),
        string.format(f,"terra_proxy_keys"),
        string.format(f,"terra_proxy_exists"),
        string.format(f,"terra_proxy_callUserdata"),
        string.format(f,"terra_proxy_deleteUserdata"),
        string.format(f,"terra_proxy_existsUserdata")
    }
    local keys
    message.setHandler(msgs[1],function(_,isLocal,...)
        if not isLocal then return end
        return "messages"
    end)
    message.setHandler(msgs[2],function(_,isLocal,...)
        if not isLocal then return end
        return msgs
    end)
    message.setHandler(msgs[3],function(_,isLocal,...)
        if not isLocal then return end
        return keys
    end)
    message.setHandler(msgs[4],function(_,isLocal,k)
        if not isLocal then return end
        return not not t[k]
    end)
    message.setHandler(msgs[5],function(_,isLocal,uid,f,...)
        if not isLocal then return end
        local ud = userdataSentProxies[uid]
        local out = ud.userdata[f](ud.userdata,...)
        if type(out) == "userdata" then
            return makeUserdataProxy(out,msgs[5],msgs[6],msgs[7])
        end
        return out
    end)
    message.setHandler(msgs[6],function(_,isLocal,uid)
        if not isLocal then return end
        userdataSentProxies[uid] = nil
    end)
    message.setHandler(msgs[7],function(_,isLocal,uid,k)
        if not isLocal then return end
        return userdataSentProxies[uid] and not not userdataSentProxies[uid].userdata[k]
    end)
    keys = iterateMessages(name,t,f,msgs)
    local function actuallyCleanup()
        -- clean up it all
        for k,v in next, msgs do
            message.setHandler(v,nil)
        end
    end
    return function(later)
        -- also allows cleaning up a bit later so stuff has time to uninitialize
        if later then
            table.insert(cleanupRequests,{time=world.time()+0.5,func=actuallyCleanup})
        else
            actuallyCleanup()
        end
    end
end
-- sets up the proxy for calls (only tells senders to callScriptedEntity)
-- requires the table in question to be present
function terra_proxy.setupReceiveCalls(name)
    doCleanup()
    local msg = string.format("%s.terra_proxy_mode",name)
    local msg2 = string.format("%s.terra_proxy_exists",name)
    message.setHandler(msg,function(_,isLocal,...)
        if not isLocal then return end
        return "calls"
    end)
    message.setHandler(msgs2,function(_,isLocal,k)
        if not isLocal then return end
        return not not t[k]
    end)
    local function actuallyCleanup()
        message.setHandler(msg,nil)
        message.setHandler(msg2,nil)
    end
    return function(later)
        if later then
            table.insert(cleanupRequests,{time=world.time()+0.5,func=actuallyCleanup})
        else
            actuallyCleanup()
        end
    end
end

-- receiver
-- does not immediately have every function, builds as time goes on
-- requires target already have proxy set up, returns nil otherwise
function terra_proxy.setupProxy(name,entityId,throw)
    local proxy = {}
    local fmt = string.format("%s.%%s",name)
    local p = world.sendEntityMessage(entityId,string.format(fmt,"terra_proxy_mode"))
    if not p:finished() or not p:succeeded() then
        return nil
    end
    local builder
    if p:result() == "calls" then
        builder = function(func)
            return function(...)
                return world.callScriptedEntity(entityId,func,...)
            end
        end
    else
        builder = function(func)
            return function(...)
                cleanUserdata()
                local p = world.sendEntityMessage(entityId,func,...)
                if throw and not p:succeeded() then
                    error(string.format("Proxy function %s has no message handler!",func))
                end
                return maybeUserdata(p:result(),entityId)
            end
        end
    end
    local keys = world.sendEntityMessage(entityId,string.format(fmt,"terra_proxy_keys")):result()
    setmetatable(proxy,{__index=function(t,k)
        if world.sendEntityMessage(entityId,string.format(fmt,"terra_proxy_exists"),k):result() then
            local func = builder(string.format(fmt,k))
            t[k] = func
            return func
        else
            t[k] = nil
        end
    end,terra_keys=keys})
    -- define all existent keys for iteration
    local n
    for _,k in next, keys do
        n = proxy[k]
    end
    return proxy
end

-- relay
-- receives messages to send them to the target
-- requires target has receiving messages set up
function terra_proxy.setupRelayMessages(name,targetId)
    local proxy = {}
    local fmt = string.format("%s.%%s",name)
    local mode = world.sendEntityMessage(targetId,string.format(fmt,"terra_proxy_mode")):result()
    if mode == "calls" then
        sb.logError("Attempted to create a proxy message relay with a call proxy!")
        return
    elseif not mode then
        sb.logError("Proxy relays require a receiving proxy on the target!")
        return
    end
    local msgs = world.sendEntityMessage(targetId,string.format(fmt,"terra_proxy_msgs")):result()
    local function relay(msg,isLocal,...)
        if not isLocal then return end
        return world.sendEntityMessage(targetId,msg,...):result()
    end
    for k,v in next, msgs do
        message.setHandler(v,relay)
    end
    return function()
        -- cleanup
        for k,v in next, msgs do
            message.setHandler(v,nil)
        end
    end
end
