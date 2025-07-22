require "/scripts/vec2.lua"
require "/scripts/poly.lua"

local spreadTypes = {
    material={},
    mod={}
}
local spreadConversions = {}
local biomes = {}
local spawner = nil
local queuedPlacement = {}
local y = -199
local things = {{t="material",l="foreground"},{t="mod",l="foreground"},{t="material",l="background"},{t="mod",l="background"}}
function table.find(org, findValue)
    for key,value in pairs(org) do
        if value == findValue then
            return key
        end
    end
    return nil
end
function init()
    biomes = config.getParameter("biomes")
    -- compile all blocks that spread into a single array, so spreading is cheaper with lots of spreadable blocks
    for k,biome in next, biomes do
        for k,v in next, biome.spreadTypes.material do
            table.insert(spreadTypes.material, v)
        end
        for k,v in next, biome.spreadTypes.mod do
            table.insert(spreadTypes.mod, v)
        end
    end
    spawner = config.getParameter("spawner")
end
function update(dt)
    if not world.entityExists(spawner) then
        stagehand.die()
        return
    end
    stagehand.setPosition(world.entityPosition(spawner))

    -- Do nothing if there are no biomes defined
    if #biomes == 0 then
        return
    end

    y = y + 1
    if y > 200 then
        y = -200
    end
    local nextQueuedPlacement = {}
    for k,v in next, queuedPlacement do
        local func = world.placeMaterial
        if v.type == "mod" then
            func = world.placeMod
        end
        v.tries = v.tries + 1
        if v.tries < 100 and not func(v.pos, v.layer, v.typeName, 0, true) then
            table.insert(nextQueuedPlacement, v)
        elseif v.mod and v.type == "material" and v.tries < 100 then
            world.placeMod(v.pos, v.layer, v.mod, 0, true)
        end
    end
    queuedPlacement = nextQueuedPlacement
    local allblocks = {}

    local ownPos = stagehand.position()
    local ownPosX = ownPos[1]
    local ownPosY = ownPos[2]
    local world_material = world.material
    local world_mod = world.mod
    local table_find = table.find
    local table_insert = table.insert
    local spreadTypes_material = spreadTypes.material
    local spreadTypes_mod = spreadTypes.mod
    for x=-200,200 do
        local pos = {ownPosX + x, ownPosY + y}  -- Convert to absolute position
        local m
        m = world_material(pos, "foreground")
        if m then
            if table_find(spreadTypes_material, m) then
                table_insert(allblocks, {type="material",typeName=m,pos=pos, layer="foreground"})
            end
        end
        m = world_material(pos, "background")
        if m then
            if table_find(spreadTypes_material, m) then
                table_insert(allblocks, {type="material",typeName=m,pos=pos, layer="background"})
            end
        end
        m = world_mod(pos, "foreground")
        if m then
            if table_find(spreadTypes_mod, m) then
                table_insert(allblocks, {type="mod",typeName=m,pos=pos, layer="foreground"})
            end
        end
        m = world_mod(pos, "background")
        if m then
            if table_find(spreadTypes_mod, m) then
                table_insert(allblocks, {type="mod",typeName=m,pos=pos, layer="background"})
            end
        end
    end

    for biomeName,biome in next, biomes do
        local blocks = {}
        for k,v in next, allblocks do
            if table.find(biome.spreadTypes[v.type], v.typeName) then
                table.insert(blocks, v)
            end
        end
        if #blocks == 0 then
            goto continue
        end
        local musicCount = 0
        local blocksToSpread = {}
        for k,v in next, blocks do
            local sc = biome.matSpreadChance
            if biome.spreadOverrides[v.type][v.typeName] then
                sc = biome.spreadOverrides[v.type][v.typeName].spreadChance
            elseif v.type == "mod" then
                sc = biome.modSpreadChance
            end
            if math.random() < sc then
                table.insert(blocksToSpread, v)
            end
            if world.magnitude(v.pos, stagehand.position()) < biome.musicDis then
                musicCount = musicCount + 1
                if v.type == "mod" then
                    musicCount = musicCount + 1
                end
            end
        end
        for k,v in next, blocksToSpread do
            local replacement = nil
            local tries = 0
            local st = biome.matSpreadTries
            local sr = biome.matSpreadRange
            if biome.spreadOverrides[v.type][v.typeName] then
                st = biome.spreadOverrides[v.type][v.typeName].spreadTries
                sr = biome.spreadOverrides[v.type][v.typeName].spreadRange
            elseif v.type == "mod" then
                st = biome.modSpreadTries
                sr = biome.modSpreadRange
            end
            while tries < st and not replacement do
                tries = tries + 1
                local offset = {math.random(sr * -1, sr), math.random(sr * -1, sr)}
                local pos = vec2.add(v.pos, offset)
                world.debugLine(v.pos, pos, "magenta")
                for k,t in next, things do
                    local block = world[t.t](pos, t.l)
                    replacement = biome.spreadConversions[t.t][block]
                    if replacement then
                        if t.t == "material" and world.replaceMaterials and world.replaceMaterials({pos},t.l,replacement) then
                            -- oSB handles this
                            -- TODO: delete mods in this case
                        else
                            if t.t == "mod" or world.damageTiles({pos}, t.l, v.pos, "blockish", 9999, 0) then
                                local params = {pos=pos,type=t.t, typeName=replacement, layer=t.l, tries=0}
                                if t.t ~= "mod" and not biome.deleteMods then
                                    params.mod = world.mod(pos, t.l)
                                end
                                table.insert(queuedPlacement, params)
                            end
                        end
                    end
                end
                if biome.spreadConversions.liquid then
                    local liquid = world.liquidAt(pos)
                    if liquid then
                        local name = root.liquidName(liquid[1])
                        if name then
                            local convertLiquid = biome.spreadConversions.liquid[name]
                            if convertLiquid then
                                local id = root.liquidId(convertLiquid)
                                world.spawnLiquid(pos, id, 1)
                            end
                        end
                    end
                end
            end
        end
        if biome.music and musicCount > biome.musicBlocks then
            local players = world.players()
            for k,v in next, players do
                if world.magnitude(stagehand.position(), world.entityPosition(v)) < 300 then
                    world.sendEntityMessage(spawner, "terraMusic", {id=biomeName..entity.id(),file=biome.music, undergroundFile=biome.undergroundMusic,nightFile=biome.nightMusic,expireType="duration",expireTime=1000,priority=biome.musicPriority, dt=dt})
                end
            end
        end
        if biome.monsters and musicCount > biome.monsterBlocks then
            local monsters = world.monsterQuery(stagehand.position(), 300)
            if #monsters < biome.monsterLimit then
                local dir = math.random() * math.pi * 2
                local mindis = biome.monsterDisMin or 75
                local offset = vec2.withAngle(dir, mindis + math.random()*((biome.monsterDisMax or 100) - mindis))
                local pos = vec2.add(stagehand.position(), offset)
                world.debugLine(stagehand.position(), pos, "red")
                for mt,p in next, biome.monsters do
                    if math.random() < p.chance then
                        if not p.moveParams then
                            p.moveParams = root.monsterMovementSettings(mt)
                        end
                        local valid = true
                        if p.layer then
                            if p.layer == "underground" then
                                if not world.underground(pos) then
                                    valid = false
                                end
                            elseif p.layer == "surface" then
                                if world.underground(pos) then
                                    valid = false
                                end
                            end
                        end
                        if valid and (p.moveParams.collisionEnabled or p.pos == "underground") then
                            local cpoly = p.moveParams.collisionPoly or p.moveParams.standingPoly
                            if p.pos == "underground" then
                                world.debugPoly(poly.translate(cpoly,pos), "red")
                                if not world.polyCollision(cpoly, pos, {"Block"}) then
                                    valid = false
                                end
                            else
                                world.debugPoint(pos, "green")
                                if world.pointCollision(pos, {"Block"}) then
                                    valid = false
                                end
                                if valid and p.pos == "ground" then
                                    local bb = poly.boundBox(cpoly)
                                    local spos = vec2.sub(pos, {0, (p.groundSearchRange or 6) - bb[2] + bb[4]})
                                    local npos = world.lineCollision(pos, spos, {"Block"})
                                    world.debugLine(pos, spos, "green")
                                    if not npos then
                                        valid = false
                                    else
                                        pos = vec2.add(npos, {0, -bb[2] + (p.groundHeightOffset or 1)})
                                    end
                                end
                                if valid then
                                    world.debugPoly(poly.translate(cpoly,pos), "green")
                                end
                                if valid and world.polyCollision(cpoly, pos, {"Block"}) then
                                    valid = false
                                end
                            end
                        end
                        if valid then
                            local params = p.params or {}
                            params.level = world.threatLevel()
                            world.spawnMonster(mt, pos, params)
                        end
                    end
                end
            end
        end
        ::continue::
    end
end
