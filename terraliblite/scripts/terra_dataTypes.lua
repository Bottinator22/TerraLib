-- CaseInsensitiveTable: a table with case insensitive keys
local citMT = {
    __index=function(t,k)
        return rawget(t,string.lower(k))
    end,
    __newindex=function(t,k,v)
        rawset(t,string.lower(k),v)
    end
}
function CaseInsensitiveTable(i)
    local out = {}
    setmetatable(out, citMT)
    if i then
        for k,v in pairs(i) do
            out[k] = v
        end
    end
    return out
end
-- NumMap: a table which can be accessed numerically but won't behave as a list
-- does so by forcing keys to be strings
local p = "k_"
local l = #p+1
local leng = "terra_length"
local function updateLeng(t,m)
    local l = rawget(t,leng)
    l = l + m
    rawset(t,leng,l)
end
local function nmnext(t,cur)
    local k,v = next(t,cur and p..cur)
    return tonumber(string.sub(k,l)),v
end
local nmMT = {
    __index=function(t,k)
        return rawget(t,p..k)
    end,
    __newindex=function(t,k,v)
        local ke = p..k
        -- change length accordingly
        local ld = 0
        if rawget(t,ke) == nil then
            ld = 1
        end
        if v == nil then
            ld = ld - 1
        end
        if ld ~= 0 then
            updateLeng(t,ld)
        end
        rawset(t,ke,v)
    end,
    __len=function(t)
        return rawget(t,leng)
    end,
    __pairs=function(t)
        return nmnext, t, nil 
    end
}
NumMap = {}
setmetatable(NumMap, {
    __call=function()
        local out = {}
        out.terra_length = 0
        setmetatable(out,nmMT)
        return out
    end
})
function NumMap.insert(t,v)
    -- pretty much just insertion, adds at first available index
    local i = 1
    while true do
        if t[i] == nil then
            t[i] = v
            return t
        end
        i = i + 1
    end
end
