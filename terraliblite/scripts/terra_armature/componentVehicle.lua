require "/scripts/terra_vec2ref.lua"
require "/scripts/terra_proxy.lua"

local ownerId
local playerId
function init()
    ownerId = config.getParameter("ownerId")
    playerId = config.getParameter("playerId")
    terra_proxy.setupReceiveMessages("animator",animator)
end
function update(dt)
    if not world.entityExists(ownerId) then
        vehicle.destroy()
        return
    end
    animator.setFlipped(false)
end
function component_setPosition(p)
    mcontroller.setPosition(p)
    mcontroller.setVelocity({0,0})
    vehicle.setInteractive(not vehicle.entityLoungingIn("seat"))
end
function component_setRotation(r)
    mcontroller.setRotation(r)
end
function uninit()
end
function applyDamage(damageRequest)
    return {}
end
function onInteraction(args)
    -- disallow player sitting in own seat
    if playerId == args.sourceId then
        return "None"
    end
end
