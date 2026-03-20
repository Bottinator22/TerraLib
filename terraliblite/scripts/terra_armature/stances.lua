require "/scripts/terra_armature/armature.lua"

local stanceConfig
stances = {}
function initStances()
    stanceConfig = config.getParameter("stances")
    stances = stanceConfig.stances
    for n,s in next, stances do
        for b,t in next, s do
            if t.rotation then
                t.rotation = t.rotation*math.pi/180 -- convert angles from degrees
            end
        end
    end
end
function applyStance(stance)
    -- assumes resetArmature is called by whatever calls this
    for k,v in next, stance do
        local bone = bones[k]
        local mat = bone.transform
        if v.scale then
            mat = mat3.scale(mat,v.scale,bone.center)
        end
        if v.rotation then
            mat = mat3.rotate(mat,v.rotation,bone.center)
        end
        if v.offset then
            mat = mat3.translate(mat,v.offset)
        end
        if v.transform then
            mat = mat3.multiply(mat,v.transform)
        end
        bone.transform = mat
    end
end
function stanceInterpolated(stancea,stanceb,i,ref)
    -- merges two stances, returns the result
    local out = ref or {}
    local ii = 1-i
    for k,v in next, bones do
        local sta = stancea[k] or {}
        local stb = stanceb[k] or {}
        local scalea
        local scaleb
        if not sta.scale then
            scalea = {1,1}
        elseif type(sta.scale) == "table" then
            scalea = sta.scale
        else
            scalea = {sta.scale,sta.scale}
        end
        
        if not stb.scale then
            scaleb = {1,1}
        elseif type(stb.scale) == "table" then
            scaleb = stb.scale
        else
            scaleb = {stb.scale,stb.scale}
        end
        
        local scale = vec2.add(vec2.mul(scalea or {0,0},i),vec2.mul(scaleb or {0,0},ii))
        local rot = (sta.rotation or 0)*i + (stb.rotation or 0)*ii
        local offset = vec2.add(vec2.mul(sta.offset or {0,0},i),vec2.mul(stb.offset or {0,0},ii))
        
        local outB = {}
        local anything = false
        if scale[1] ~= 1 or scale[2] ~= 1 then
            outB.scale = scale
            anything = true
        end
        if rot ~= 0 then
            outB.rotation = rot
            anything = true
        end
        if offset[1] ~= 0 or offset[2] ~= 0 then
            outB.offset = offset
            anything = true
        end
        if anything then
            out[k] = outB
        else
            out[k] = nil
        end
    end
    return out
end
