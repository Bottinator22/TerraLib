-- for more accurate timekeeping.
-- reasoning: world.time is inaccurate, os.clock behaves differently on Linux (and as such isn't real time), timers on the main thread will be slightly wrong if FPS is imperfect

local timers = {}
setmetatable(timers,{__index=function(t,k)
    -- create a new timer
    t[k] = 0
    return t[k]
end})
function init()
    for _,v in next, config.getParameter("timers",{}) do
        timers[v] = 0
    end
    message.setHandler("getTimer", function(_,_,t)
        local timer = timers[t or "generic"]
        return timer*script.updateDt()
    end)
    message.setHandler("getTimerTicks", function(_,_,t)
        local timer = timers[t or "generic"]
        return timer
    end)
    message.setHandler("resetTimer", function(_,_,t)
        timers[t or "generic"] = 0
    end)
    script.setUpdateDelta(1)
end
function update(dt)
    for k,v in next, timers do
        timers[k] = v + 1
    end
end
function uninit()
end
