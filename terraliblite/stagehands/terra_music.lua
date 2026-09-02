require "/scripts/vec2.lua"
require "/scripts/stagehandutil.lua"

local queryPos1
local queryPos2
local music
function init()
    music = config.getParameter("music",{})
    music.id = music.id or entity.uniqueId() or entity.id()
    music.priority = music.priority or 1
    
    script.setUpdateDelta(4)
end
function update(dt)
    local rect = translateBroadcastArea()
    music.rect = rect
    queryPos1 = {rect[1], rect[2]}
    queryPos2 = {rect[3], rect[4]}
    local players = world.playerQuery(queryPos1,queryPos2)
    for k,v in next, players do
        world.sendEntityMessage(v,"terraMusic",music)
    end
end
