require "/scripts/rect.lua"
local lastUsed
local region
function init()
    lastUsed = os.clock()
    region = rect.translate(config.getParameter("broadcastArea"),entity.position())
end
function update(dt)
    if os.clock()-lastUsed > 1 then
        stagehand.die()
        return
    end
end
function sd_isLoaderOf(r)
    local valid = r[1] >= region[1] and r[2] >= region[2] and r[3] <= region[3] and r[4] <= region[4]
    if valid then
        lastUsed = os.clock()
    end
    return valid
end
