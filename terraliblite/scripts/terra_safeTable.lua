
-- unlike the original version, doesn't properly inherit from function __index metatables
local safe = {
}
local function safeIndex(t,k)
    if safe[k] ~= nil then
        return safe[k]
    else
        --[[
        local mt = getmetatable(t)
        if not mt.origTable then
            return
        end
        local i = mt.__index
        if type(i) == "table" then
            return i[k]
        elseif type(i) == "function" then
            return i(mt.origTable,k)
        end
        ]]
        return nil
    end
end
function safe.markDestroyed(self)
    getmetatable(self).origTable = nil
end

function makeSafe(t)
    local out = {}
    local mt = {
        origTable=t,
        __index=safeIndex
    }
    -- TODO: also make the metatable of original table safe
    for k,v in next, t do
        if type(v) == "function" then
            out[k] = function(...)
                if mt.origTable then
                    return v(...)
                else
                    error("Safe table function '%s' executed after destruction!")
                end
            end
        end
    end
    setmetatable(out,mt)
    return out
end
