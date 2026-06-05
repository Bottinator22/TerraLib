require "/scripts/terra_proxy.lua"
require "/scripts/terra_vec2ref.lua"
require "/scripts/rect.lua"

local music = {}
-- table format:
-- {
--     id=any string or number, overwrites any existing music instance with the same id,
--     paths="music file path", (can be array)
--     (optional) undergroundPaths=paths but only applies underground,
--     nightPaths=paths but only applies at night,
--     (optional) entityId=entity ID to tie music to,
--     (optional) entityDis=distance to entity for expiration,
--     (optional) expireTime=seconds before expiration,
--     priority=priority
-- }
-- priority in Terraria Mod has 10-20 for boss music and 5 for evil biome music
local playing = nil
function idKey(id)
    if type(id) == "string" then
        return id
    elseif type(id) == "number" then
        return string.format("e_%d",id)
    end
end
-- File for managing music requests; meant to prevent music conflicts.
function init()
    message.setHandler("terraMusic", function (_,_,newmusic) 
        local key = idKey(newmusic.id)
        local old = music[key]
        newmusic.priority = newmusic.priority or 0
        newmusic.key = key
        music[key] = newmusic
    end)
    script.setUpdateDelta(1)

    -- why make a new script just to do this when I can just add it to an existing one?
    -- TODO: remove the need for this. the proxy is stabler and works better with puppeteer.
    getmetatable''.player = player
    
    -- proxies! better 
    terra_proxy.setupReceiveMessages("player",player)
    -- this too
    terra_proxy.setupReceiveMessages("celestial",celestial)
end
function update(dt)
    local newMusic = {}
    local highestPriority
    for k,v in next, music do
        local alive = true
        local mePos = world.entityPosition(player.id())
        if v.expireTime then
            v.expireTime = v.expireTime - dt
            if v.expireTime >= 0 then
                alive = false
            end
        end
        local id = v.entityID or v.entityId
        if id then
            if not world.entityExists(id) then
                alive = false
            else
                local ePos = world.entityPosition(id)
                if v.entityDis and world.magnitude(ePos, mePos) > v.entityDis then
                    alive = false
                end
            end
        end
        if v.rect then
            if not rect.contains(v.rect, mePos) then
                alive = false
            end
        end
        if v.dis then
            if world.magnitude(v.disPos, mePos) > v.dis then
                alive = false
            end
        end
        if alive then
            if not highestPriority or v.priority > highestPriority.priority then
                highestPriority = v
            end
            table.insert(newMusic,v)
        end
    end
    music = newMusic
    if highestPriority then
        playing = highestPriority
    else
        if playing then
            world.sendEntityMessage(player.id(), "stopAltMusic", 2.0)
        end
        playing = nil
    end
    if playing then
        local m = playing
        local paths = m.file or m.paths
        if m.nightFile or m.nightPaths then
            if world.timeOfDay() > 0.5 then
                paths = m.nightFile or m.nightPaths
            end
        end
        if m.undergroundFile or m.undergroundPaths then
            if world.underground(world.entityPosition(player.id())) then
                paths = m.undergroundFile or m.undergroundPaths
            end
        end
        if type(paths) == "string" then
            paths = {paths}
        end
        world.sendEntityMessage(player.id(), "playAltMusic", paths, 2.0)
    end
end
