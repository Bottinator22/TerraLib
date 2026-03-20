
local safe = {
}
local safeMT = {
    __index=function(t,k)
        if safe[k] ~= nil then
            return safe[k]
        elseif t.table then
            return t.table[k]
        else
            error(string.format("Safe table key '%s' accessed after destruction!",k))
        end
    end
}
function safe.markDestroyed(self)
    self.table = nil
end

function makeSafe(t)
    local out = {
        table=t
    }
    setmetatable(out,safeMT)
    return out
end
