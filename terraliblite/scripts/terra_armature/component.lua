require "/scripts/terra_vec2ref.lua"
require "/scripts/terra_proxy.lua"

local ownerId
local playerId
local vuln = false
function init()
    ownerId = config.getParameter("ownerId")
    playerId = config.getParameter("playerId")
    monster.setDamageBar("None")
    monster.setAggressive(true)
    status.setStatusProperty("ownerId",ownerId)
    terra_proxy.setupReceiveMessages("animator",animator)
    mcontroller.setAutoClearControls(true)
    vuln = config.getParameter("vulnerable")
    if vuln then
        status.setStatusProperty("ownerId",ownerId)
    else
        status.setPersistentEffects("componentInvuln",{{stat="invulnerable",amount=1.0}})
    end
end
function update(dt)
    mcontroller.controlFace(1)
    animator.setFlipped(false)
    mcontroller.setVelocity({0,0})
    if vuln then
        monster.setDamageTeam(world.entityDamageTeam(playerId))
    else
        monster.setDamageTeam({type="ghostly",team=1})
    end
end
function shouldDie()
    return not world.entityExists(ownerId)
end
function uninit()
end
function component_setPosition(p)
    mcontroller.setPosition(p)
end
function component_setRotation(r)
    mcontroller.setRotation(r)
end
