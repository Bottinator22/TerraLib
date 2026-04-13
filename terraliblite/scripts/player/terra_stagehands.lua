-- spawns the stagehand that manages biome spreading
-- it does nothing else
local stagehandID = nil
function init()
    script.setUpdateDelta(60)
end
local terralibCheckPromise
local terralibCheckDone = false
local terralibVerified = false
function update(dt)
    if not stagehandID then
        local stagehands = world.entityQuery(world.entityPosition(player.id()), 300, {includedTypes={"stagehand"}, boundMode="position"})
        for k,v in next, stagehands do
            if world.stagehandType(v) == "terra_biomemanager" then
                stagehandID = v
            end
        end
        if not stagehandID then
            world.spawnStagehand(world.entityPosition(player.id()), "terra_biomemanager", {spawner=player.id()})
        end
    elseif not world.entityExists(stagehandID) then
        stagehandID = nil
    elseif world.magnitude(world.entityPosition(stagehandID), world.entityPosition(player.id())) > 300 then
        stagehandID = nil
    elseif not terralibCheckPromise then
        terralibCheckPromise = world.sendEntityMessage(stagehandID,"terra_isTerraLib")
    elseif terralibCheckPromise:finished() and not terralibCheckDone then
        if terralibCheckPromise:succeeded() then
            terralibCheckDone = true
            terralibVerified = true
        else
            if terralibCheckPromise:error() == "Message not handled by entity" then
                terralibCheckDone = true
                terralibVerified = false
                
                local str = "Did not detect TerraLib on the server.\nTerraLib is ^red;not^reset; compatible with servers that do not have it.\n^green;Please switch to ^orange;TerraLib Lite ^green;instead.^reset;"
                sb.logWarn(str)
                player.interact("ShowPopup",{
                    message=str,
                    title="Wrong TerraLib version!",
                    sound="/sfx/interface/nav_insufficient_fuel.ogg"
                })
            else
                -- some other error. try again
                terralibCheckPromise = nil
            end
        end
    end
end
