require "/scripts/rect.lua"
local lastUsed
local region
local poly
function init()
    lastUsed = os.clock()
    vehicle.setInteractive(false)
    mcontroller.applyParameters(config.getParameter("movementSettings"))
    region = rect.translate(config.getParameter("boundBox"),mcontroller.position())
    poly = {
        {region[1],region[2]},{region[1],region[4]},{region[3],region[4]},{region[3],region[2]}
    }
end
function update(dt)
    world.debugPoly(poly,"red")
    if os.clock()-lastUsed > 1 then
        vehicle.destroy()
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
function applyDamage(damageRequest)
    return {}
end
