require "/scripts/terra_vec2ref.lua"

-- spawns the stagehand that manages biome spreading and checks if you're in a biome
local stagehandID = nil
local stagehandSpawnDelay = 0
local musicBiomes = {}
function init()
    local biomes = root.assetJson("/terra_biomes.json")
    if next(biomes) then
        for k,v in next, biomes do
            if v.music then
                musicBiomes[k] = v
                v.musicId = string.format("terra_biome_%s",k)
                v.modSet = {}
                v.materialSet = {}
                for _,v2 in next, v.spreadTypes.material do
                    v.materialSet[v2] = true
                end
                for _,v2 in next, v.spreadTypes.mod do
                    v.modSet[v2] = true
                end
            end
        end
        script.setUpdateDelta(60)
    else
        script.setUpdateDelta(0) -- don't update. this also doesn't allow one to be spawned
    end
end

-- TODO: it doesn't spawn the stagehand anymore if there are no biomes to spread. check if the server has TerraLib through other means (briefly spawned punchy, maybe)
local terralibCheckPromise
local terralibCheckDone = false
local terralibVerified = false
function update(dt)
    if not stagehandID then
        stagehandSpawnDelay = stagehandSpawnDelay - dt
        local stagehands = world.entityQuery(world.entityPosition(player.id()), 300, {includedTypes={"stagehand"}, boundMode="position"})
        for k,v in next, stagehands do
            if world.stagehandType(v) == "terra_biomemanager" then
                stagehandID = v
            end
        end
        if not stagehandID and stagehandSpawnDelay <= 0 then
            world.spawnStagehand(world.entityPosition(player.id()), "terra_biomemanager", {spawner=player.id()})
            stagehandSpawnDelay = 10
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
    if stagehandID then
        local mePos = vec2.floor(world.entityPosition(player.id()))
        for k,v in next, musicBiomes do
            local minCount = v.musicBlocks
            local count = 0
            local d = math.ceil(v.musicDis/2)
            for x=-d,d,1 do
                for y=-d,d,1 do
                    local pos = {mePos[1]+x,mePos[2]+y}
                    local matf = world.material(pos,"foreground")
                    local matb = world.material(pos,"background")
                    local modf = world.mod(pos,"foreground")
                    local modb = world.mod(pos,"background")
                    if (matf and v.materialSet[matf]) or (matb and v.materialSet[matb]) or (modf and v.modSet[modf]) or (modb and v.modSet[modb]) then
                        count = count + 1
                    end
                end
                if count > minCount then
                    break
                end
            end
            if count > minCount then
                world.sendEntityMessage(player.id(), "terraMusic", {id=v.musicId,file=v.music, undergroundFile=v.undergroundMusic,nightFile=v.nightMusic,expireTime=1.5,priority=v.musicPriority})
            end
        end
    end
end
