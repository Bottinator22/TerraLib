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
    for k,v in next, tables do
        env[k] = v
    end
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
    return env
end
