local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local charForth = {}
local charBack = {}
local i = 0
for v in string.gmatch(chars,".") do
    charBack[v] = i
    table.insert(charForth,v)
    i = i + 1
end
charBack["="] = nil
function octetsToBase64(t)
    local str = ""
    local i = 1
    while i <= #t do
        -- convert 3 octets of data
        local b1 = t[i] -- should never be nil
        local b2 = t[i+1] -- should always be defined if b3 is defined
        local b3 = t[i+2]
        local v1 = (b1 & 0xfc) >> 2
        local v2 = (b1 & 0x03) << 4
        local v3 = nil
        local v4 = nil
        if b2 then
            v2 = v2 | ((b2 & 0xf0) >> 4)
            v3 = (b2 & 0x0f) << 2
        end
        if b3 then
            v3 = v3 | ((b3 & 0xc0) >> 6)
            v4 = b3 & 0x3f
        end
        str = str..string.format("%s%s%s%s",
            charForth[v1+1],
            charForth[v2+1],
            v3 and charForth[v3+1] or "=",
            v4 and charForth[v4+1] or "="
        )
        i = i + 3
    end
    return str
end
function base64ToOctets(t)
    local out = {}
    for i=1,#t,4 do
        local c1 = string.sub(t,i,i)
        local c2 = string.sub(t,i+1,i+1)
        local c3 = string.sub(t,i+2,i+2)
        local c4 = string.sub(t,i+3,i+3)
        local v1 = charBack[c1]
        local v2 = charBack[c2]
        local v3 = charBack[c3]
        local v4 = charBack[c4]
        table.insert(out,(v1 << 2) | ((v2 & 0x30) >> 4))
        if v3 then
            table.insert(out,
                ((v2 & 0x0f) << 4) 
                | ((v3 & 0x3c) >> 2))
        end
        if v4 then
            table.insert(out,
                ((v3 & 0x03) << 6) 
                | v4)
        end
    end
    return out
end
