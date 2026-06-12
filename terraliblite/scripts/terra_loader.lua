require "/scripts/rect.lua"
local usedTimer = 1
local region
function init()
    region = rect.translate(config.getParameter("broadcastArea"),entity.position())
end
function update(dt)
    usedTimer = usedTimer - dt
    if usedTimer < 0 then
        stagehand.die()
        return
    end
end
function sd_isLoaderOf(r)
    local valid = r[1] >= region[1] and r[2] >= region[2] and r[3] <= region[3] and r[4] <= region[4]
    if valid then
        usedTimer = 1
    end
    return valid
end
