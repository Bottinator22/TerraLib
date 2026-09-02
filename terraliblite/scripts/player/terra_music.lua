require "/scripts/terra_proxy.lua"
require "/scripts/terra_vec2ref.lua"
require "/scripts/rect.lua"
require "/scripts/poly.lua"

local music = {}
-- table format:
-- {
--     id=any string or number, overwrites any existing music instance with the same id,
--     paths="music file path", (can be array)
--     (optional) undergroundPaths=paths but only applies underground,
--     (optional) nightPaths=paths but only applies at night,

--     (optional) expireTime=seconds before expiration,
--     (optional) fadeTime=seconds to fade in or out,

--     (optional) entityId=entity ID to tie music to,
--     (optional) entityDis=distance to entity for expiration,

--     (optional) dis=distance to expire at
--                      disPos=position to check dis against

--     (optional) rect=rect to tie music to, expires if player leaves this area

--     (optional) poly=poly to tie music to, expires if player leaves this poly
--     priority=priority
-- }
-- default priority is 0
-- priority in Terraria Mod has 10-20 for boss music and 5 for evil biome music
-- priority in Almandine has 0 for background music
-- TerraLib music stagehand has a default priority of 1
local playing = nil
function idKey(id)
    if type(id) == "string" then
        return id
    elseif type(id) == "number" then
        return string.format("e_%d",id)
    end
end

local cfg

local debug = false
local function makeCirclePoly(radius, p)
    local output = {}
    local points = 10
    for i = 1, points, 1 do
        local angle = (math.pi * 2) / points * i
        table.insert(output, vec2.add(vec2.withAngle(angle, radius), p))
    end
    return output
end

-- Script for managing music requests; meant to prevent music conflicts.
function init()
    cfg = root.assetJson("/terralib_general.config").music
    message.setHandler("terraMusic", function (_,_,newmusic) 
        local key = idKey(newmusic.id)
        local old = music[key]
        if newmusic.stop or not (newmusic.file or newmusic.paths) then
            -- stop playing
            music[key] = nil
        elseif old then
            for k,v in next, newmusic do
                old[k] = v
            end
        else
            newmusic.priority = newmusic.priority or 0
            newmusic.key = key
            music[key] = newmusic
        end
    end)
    message.setHandler("/terraDebugMusic", function (_,l)
        if not l then return "Unauthorized" end
        debug = not debug
    end)
    message.setHandler("/terraDumpMusic", function (_,l)
        if not l then return "Unauthorized" end
        return string.format("Currently playing: %s\nCurrently active: %s",playing and sb.printJson(playing,1) or "nil",sb.printJson(music,1))
    end)
    script.setUpdateDelta(1)

    -- why make a new script just to do this when I can just add it to an existing one?
    -- TODO: remove the need for this metatable smuggle. the proxy is stabler and works better with puppeteer.
    getmetatable''.player = player
    
    -- proxies! better 
    terra_proxy.setupReceiveMessages("player",player)
    -- this too
    terra_proxy.setupReceiveMessages("celestial",celestial)
end
function update(dt)
    -- can't message an entity on uninit or init, so stop it here on first update
    local stopPlaying = player.getProperty("terra_stopPlaying")
    if stopPlaying then
        player.setProperty("terra_stopPlaying")
        if cfg.useBlankToClear then
            world.sendEntityMessage(player.id(), "playAltMusic", {""}, 0.0)
        else
            world.sendEntityMessage(player.id(), "stopAltMusic", 0.0)
        end
    end
    local lastPlaying = playing
    local mePos = world.entityPosition(player.id())
    if playing and not music[playing.key] then
        playing = nil
    end
    local po = {0,-1000}
    for k,v in next, music do
        local alive = true
        if v.expireTime then
            v.expireTime = v.expireTime - dt
            if v.expireTime < 0 then
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
            if debug then
                world.debugPoly({{v.rect[1],v.rect[2]},{v.rect[3],v.rect[2]},{v.rect[3],v.rect[4]},{v.rect[1],v.rect[4]}},"cyan")
            end
            if not rect.contains(v.rect, mePos) then
                alive = false
            end
        end
        if v.poly then
            if debug then
                world.debugPoly(v.poly,"cyan")
            end
            -- check if within the poly
            -- make poly relative
            local cpol = {}
            for k,v in next, v.poly do
                cpol[k] = world.distance(v,mePos)
            end
            --world.debugPoly(cpol,"red")
            local withinI = 0
            for i=1,#cpol do
                local ca = cpol[i]
                local cb = cpol[i+1] or cpol[1]
                if vec2.intersect({0,0},po,ca,cb) then
                    withinI = withinI + 1
                end
            end
            if withinI & 1 == 0 then -- if it crossed an odd number of lines this means we are inside the poly
                alive = false
            end
        end
        if v.dis then
            if debug then
                world.debugPoly(makeCirclePoly(v.dis,v.disPos),"cyan")
            end
            if world.magnitude(v.disPos, mePos) > v.dis then
                alive = false
            end
        end
        if alive then
            if not playing or v.priority > playing.priority then
                playing = v
            end
        else
            music[k] = nil
        end
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
        local fadeTime = playing.fadeTime or 2.0
        if lastPlaying then
            local oldFadeTime = lastPlaying.fadeTime or 2.0
            fadeTime = (fadeTime + oldFadeTime)/2
        end
        world.sendEntityMessage(player.id(), "playAltMusic", paths, fadeTime)
    elseif lastPlaying then
        if cfg.useBlankToClear then
            world.sendEntityMessage(player.id(), "playAltMusic", {""}, lastPlaying.fadeTime or 2.0)
        else
            world.sendEntityMessage(player.id(), "stopAltMusic", lastPlaying.fadeTime or 2.0)
        end
    end
end

function uninit()
    -- queue a stop alt music after warp (alt music isn't cleared between warps)
    if playing then
        player.setProperty("terra_stopPlaying",true)
    end
end
