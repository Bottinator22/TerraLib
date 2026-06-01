-- for more accurate timekeeping.
-- reasoning: world.time is inaccurate, os.clock behaves differently on Linux (and as such isn't real time), timers on the main thread will be slightly wrong if FPS is imperfect

local timer = 0
function init()
    message.setHandler("getTimer", function(_,_)
        return timer*script.updateDt()
    end)
    message.setHandler("getTimerTicks", function(_,_)
        return timer
    end)
    message.setHandler("resetTimer", function(_,_)
        timer = 0
    end)
    script.setUpdateDelta(1)
end
function update(dt)
    timer = timer + 1
end
function uninit()
end
