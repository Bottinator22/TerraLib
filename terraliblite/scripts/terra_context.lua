require "/scripts/terra_scriptLoader.lua"
require "/scripts/terra_scriptLoader_loadstring.lua" 

-- requires oSB

function buildContextConfig(cfg)
    local config = {}
    function config.getParameter(p,d)
        local out
        if p == "" then
            out = sb.jsonMerge({}, cfg)
        else
            out = cfg[p] or d
            if type(out) == "table" then
                return sb.jsonMerge({}, out)
            end
        end
        return out
    end
    return config
end
local function nullFunc() end
local nullTable = {}
setmetatable(nullTable, {
    __index=function() 
        return nullFunc
    end
})
-- also pcalls everything
-- oTables contains stuff like emulated tables
function buildContext(scripts, oTables, storage, invokables, params)
    params = params or {}
    if params.subMcontroller then
        params.subMcontroller.clearOnUpdate = false
    end
    local env = params.env or {}
    local tables = {}
    for k,v in next, oTables do
        if type(v) == "table" and (not getmetatable(v) or not getmetatable(v).__index) then
            -- make sure nothing breaks this
            local layer = {}
            setmetatable(layer,{__index=v})
            tables[k] = layer
        else
            tables[k] = v
        end
    end
    local cscript = {}
    local updateDt = 1
    if scripts.scriptDelta then
        updateDt = scripts.scriptDelta
        scripts = scripts.scripts
    end
    function cscript.updateDt()
        if updateDt == 0 then
            return 0
        else
            return script.updateDt()*updateDt
        end
    end
    function cscript.setUpdateDelta(dt)
        updateDt = dt
    end
    tables.script = cscript
    tables.storage = storage or {}
    tables.self = {}
    
    -- this initializes the script too, running everything pre-init. note that the env still inherits from base env. scripts should NOT rely on this.
    local s, o = pcall(scriptLoader.loadMultiple_loadstring,scripts,tables,env,invokables)
    
    if s then
        local out = {}
        local dead = false
        local function pcallWrap(f)
            return function(...)
                if dead then return end
                local s,o = pcall(f,...)
                if s then
                    return o
                else
                    sb.logError("Sandboxed context threw an error on invoke!")
                    sb.logError(o)
                    dead = true
                end
            end
        end
        for _,v in next, invokables do
            out[v] = o[v] and pcallWrap(o[v]) or nullFunc
        end
        if out.update then
            local _update = out.update
            local t = 0
            out.update = function(dt,...)
                local idt
                if type(dt) == "table" then
                    if dt.dt then
                        idt = dt
                        idt.dt = dt.dt*updateDt
                    end
                    -- if not... what. what is this?
                elseif dt then
                    idt = dt*updateDt
                end
                t = t + 1
                if t >= updateDt then
                    t = 0
                    if params.subMcontroller then
                        params.subMcontroller.autoclear()
                    end
                    _update(idt,...)
                end
            end
        end
        function out.contextDead()
            return dead
        end
        if params.subMcontroller then
            out.mcontroller = params.subMcontroller
        end
        return out
    else
        sb.logError("Sandboxed context threw an error on construct!")
        sb.logError(o)
        return nullTable
    end
end

-- TODO: this is a lot of repeated code, maybe reuse some of it
-- this requires ALL context-specific tables be specified
function buildContext_strict(scripts, oTables, storage, invokables, params)
    local function wrap(t)
        return setmetatable({},{__index=t})
    end
    params = params or {}
    if params.subMcontroller then
        params.subMcontroller.clearOnUpdate = false
    end
    local env = params.env or {}
    local tables = {}
    local cscript = {}
    local updateDt = 1
    if scripts.scriptDelta then
        updateDt = scripts.scriptDelta
        scripts = scripts.scripts
    end
    function cscript.updateDt()
        if updateDt == 0 then
            return 0
        else
            return script.updateDt()*updateDt
        end
    end
    function cscript.setUpdateDelta(dt)
        updateDt = dt
    end
    tables.script = cscript
    tables.storage = storage or {}
    tables.self = {}
    tables.root = wrap(root)
    tables.sb = wrap(sb)
    tables.threads = wrap(threads)
    
    for k,v in next, oTables do
        if type(v) == "table" then
            -- make sure nothing breaks this
            tables[k] = wrap(v)
        else
            tables[k] = v
        end
    end
    
    -- this initializes the script too, running everything pre-init. env does not inherit from base env.
    local s, o = pcall(scriptLoader.loadMultiple_strict,scripts,tables,env,invokables)
    
    if s then
        local out = {}
        local dead = false
        local function pcallWrap(f)
            return function(...)
                if dead then return end
                local s,o = pcall(f,...)
                if s then
                    return o
                else
                    sb.logError("Sandboxed context threw an error on invoke!")
                    sb.logError(o)
                    dead = true
                end
            end
        end
        for _,v in next, invokables do
            out[v] = o[v] and pcallWrap(o[v]) or nullFunc
        end
        if out.update then
            local _update = out.update
            local t = 0
            out.update = function(dt,...)
                local idt
                if type(dt) == "table" then
                    if dt.dt then
                        idt = dt
                        idt.dt = dt.dt*updateDt
                    end
                    -- if not... what. what is this?
                elseif dt then
                    idt = dt*updateDt
                end
                t = t + 1
                if t >= updateDt then
                    t = 0
                    if params.subMcontroller then
                        params.subMcontroller.autoclear()
                    end
                    _update(idt,...)
                end
            end
        end
        function out.contextDead()
            return dead
        end
        if params.subMcontroller then
            out.mcontroller = params.subMcontroller
        end
        return out
    else
        sb.logError("Sandboxed context threw an error on construct!")
        sb.logError(o)
        return nullTable
    end
end
