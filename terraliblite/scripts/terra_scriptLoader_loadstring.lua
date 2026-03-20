scriptLoader = scriptLoader or {}
function scriptLoader.loadMultiple_loadstring(scripts, tables, env, toTrack)
    if not env then
        env = {}
    end
    for k,v in next, _ENV do
        env[k] = v
    end
    for k,v in next, toTrack do
        env[v] = nil
    end
    env.init = nil
    env.update = nil
    env.uninit = nil
    env._SBLOADED = {}
    function env.require(s)
        if not env._SBLOADED[s] then
            env._SBLOADED[s] = true
            loadstring(root.assetData(s),s,env)()
        end
    end
    local toTrackI = {}
    if toTrack then
        for k,v in next, toTrack do
            toTrackI[v] = true
        end
    end
    local mergedScript = ""
    for k,v in next, scripts do
        local s = root.assetData(v)
        loadstring(s, v, env)()
    end
    -- finally, apply the tables
    for k,v in next, tables do
        env[k] = v
    end
    return env
end

-- Does not inherit from base _ENV, but uses base things from there
-- forbids metatable smuggling entirely
-- does not include set/getmetatable, those are defined separately
-- shared table is also not included, defined separately to be non-shared
-- these are base lua bindings accessible in all contexts whether server or client
local baseThings = {
        "assert",
        "error",
        "getmetatable",
        "ipairs",
        "next",
        "pairs",
        "pcall",
        "print",
        "rawequal",
        "rawget",
        "rawlen",
        "rawset",
        "select",
        "setmetatable",
        "tonumber",
        "tostring",
        "type",
        "unpack",
        "_VERSION",
        "xpcall",
        
        "require",
        
        "os",
        "coroutine",
        "math",
        "string",
        "table",
        "utf8",
        
        -- TODO: 'secure' version that forbids these
        "io",
        "package",
        "debug",
        
        "jarray",
        "jobject",
        "jremove",
        "jsize",
        "jresize",
        
        "loadstring"
        
        -- TODO: everything oSB adds later, but this is up to date for now
}
function scriptLoader.loadMultiple_strict(scripts, tables, env, toTrack)
    if not env then
        env = {}
    end
    local stringMT = {__index=string}
    for _,v in next, baseThings do
        local origin = _ENV[v]
        if type(origin) == "table" then
            local t = {}
            setmetatable(t,{__index=_ENV[v]})
            env[v] = t
        else
            env[v] = _ENV[v]
        end
    end
    function env.setmetatable(t,mt)
        if type(t) == "string" then
            stringMT = mt
        else
            setmetatable(t,mt)
        end
        return t
    end
    function env.getmetatable(t)
        if type(t) == "string" then
            return stringMT
        else
            return getmetatable(t)
        end
    end
    env.shared = {}
    for k,v in next, toTrack do
        env[v] = nil
    end
    env.init = nil
    env.update = nil
    env.uninit = nil
    env._SBLOADED = {}
    function env.require(s)
        if not env._SBLOADED[s] then
            env._SBLOADED[s] = true
            loadstring(root.assetData(s),s,env)()
        end
    end
    local toTrackI = {}
    if toTrack then
        for k,v in next, toTrack do
            toTrackI[v] = true
        end
    end
    local mergedScript = ""
    for k,v in next, scripts do
        local s = root.assetData(v)
        loadstring(s, v, env)()
    end
    -- finally, apply the tables
    for k,v in next, tables do
        env[k] = v
    end
    return env
end
