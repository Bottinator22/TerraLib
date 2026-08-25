-- Utility script for dealing with 3d affine transformation matrices.
local identity = {
    1,0,0,
    0,1,0,
    0,0,1
}
local zeroVec = {0,0}
mat3 = {}
function mat3.identity()
    return {
        1,0,0,
        0,1,0,
        0,0,1
    }
end
function mat3.getRotationMatrix(r,p)
    p = p or zeroVec
    local sin = math.sin(r)
    local cos = math.cos(r)
    return {
        cos, -sin,p[1]-p[1]*cos+sin*p[2],
        sin, cos, p[2]-p[1]*sin-cos*p[2],
        0, 0, 1
    }
end
function mat3.getRotationMatrix_dirVec(v,p)
    -- assumes v is a unit vector representing the given direction. saves some trig calculations.
    p = p or zeroVec
    local cos = v[1]
    local sin = v[2]
    return {
        cos, -sin,p[1]-p[1]*cos+sin*p[2],
        sin, cos, p[2]-p[1]*sin-cos*p[2],
        0, 0,     1
    }
end
function mat3.getTranslationMatrix(t)
    return {
        1,0,t[1],
        0,1,t[2],
        0,0,1
    }
end
function mat3.getScalingMatrix(sot,p)
    p = p or zeroVec
    if type(sot) == "number" then
        return {
            sot,0,p[1]-p[1]*sot,
            0,sot,p[2]-p[2]*sot,
            0,0,1
        }
    else
        return {
            sot[1],0,p[1]-p[1]*sot[1],
            0,sot[2],p[2]-p[2]*sot[2],
            0,0,1
        }
    end
end
function mat3.translate(m,t)
    -- faster version that does all calculations at once
    return {
        m[1]+t[1]*m[7],m[2]+t[1]*m[8],m[3]+t[1]*m[9],
        m[4]+t[2]*m[7],m[5]+t[2]*m[8],m[6]+t[2]*m[9],
        m[7],          m[8],          m[9]
    }
end
--[[
function mat3.translate(m,t)
    local n = mat3.getTranslationMatrix(t)
    return mat3.multiply(m,n)
end]]
function mat3.scale(m,sot,p)
    -- faster version that does all calculations at once
    p = p or zeroVec
    if type(sot) == "number" then
        return {
            sot*m[1]+(p[1]-p[1]*sot)*m[7], sot*m[2]+(p[1]-p[1]*sot)*m[8], sot*m[3]+(p[1]-p[1]*sot)*m[9],
            sot*m[4]+(p[2]-p[2]*sot)*m[7], sot*m[5]+(p[2]-p[2]*sot)*m[8], sot*m[6]+(p[2]-p[2]*sot)*m[9],
            m[7], m[8], m[9]
        }
    else
        return {
            sot[1]*m[1]+(p[1]-p[1]*sot[1])*m[7], sot[1]*m[2]+(p[1]-p[1]*sot[1])*m[8], sot[1]*m[3]+(p[1]-p[1]*sot[1])*m[9],
            sot[2]*m[4]+(p[2]-p[2]*sot[2])*m[7], sot[2]*m[5]+(p[2]-p[2]*sot[2])*m[8], sot[2]*m[6]+(p[2]-p[2]*sot[2])*m[9],
            m[7], m[8], m[9]
        }
    end
end
--[[
function mat3.scale(m,sot,p)
    local n = mat3.getScalingMatrix(sot,p)
    return mat3.multiply(m,n)
end
]]
-- TODO: 'fast' versions of these that do all the operations at once
function mat3.rotate(m,r,p)
    p = p or zeroVec
    local sin = math.sin(r)
    local cos = math.cos(r)
    return {
        cos*m[1]-sin*m[4]+(p[1]-p[1]*cos+sin*p[2])*m[7], cos*m[2]-sin*m[5]+(p[1]-p[1]*cos+sin*p[2])*m[8], cos*m[3]-sin*m[6]+(p[1]-p[1]*cos+sin*p[2])*m[9],
        sin*m[1]+cos*m[4]+(p[2]-p[1]*sin-cos*p[2])*m[7], sin*m[2]+cos*m[5]+(p[2]-p[1]*sin-cos*p[2])*m[8], sin*m[3]+cos*m[6]+(p[2]-p[1]*sin-cos*p[2])*m[9],
        m[7], m[8], m[9]
    }
end
--[[
function mat3.rotate(m,r,p)
    local n = mat3.getRotationMatrix(r,p)
    return mat3.multiply(m,n)
end]]
function mat3.rotate_dirVec(m,v,p)
    -- assumes v is a unit vector representing the given direction. saves some trig calculations.
    p = p or zeroVec
    local cos = v[1]
    local sin = v[2]
    return {
        cos*m[1]-sin*m[4]+(p[1]-p[1]*cos+sin*p[2])*m[7], cos*m[2]-sin*m[5]+(p[1]-p[1]*cos+sin*p[2])*m[8], cos*m[3]-sin*m[6]+(p[1]-p[1]*cos+sin*p[2])*m[9],
        sin*m[1]+cos*m[4]+(p[2]-p[1]*sin-cos*p[2])*m[7], sin*m[2]+cos*m[5]+(p[2]-p[1]*sin-cos*p[2])*m[8], sin*m[3]+cos*m[6]+(p[2]-p[1]*sin-cos*p[2])*m[9],
        m[7], m[8], m[9]
    }
end
--[[
function mat3.rotate_dirVec(m,v,p)
    -- assumes v is a unit vector representing the given direction. saves some trig calculations.
    local n = mat3.getRotationMatrix_dirVec(v,p)
    return mat3.multiply(m,n)
end]]
function mat3.multiply(a,b)
    return {
        b[1]*a[1]+b[2]*a[4]+b[3]*a[7], b[1]*a[2]+b[2]*a[5]+b[3]*a[8], b[1]*a[3]+b[2]*a[6]+b[3]*a[9],
        b[4]*a[1]+b[5]*a[4]+b[6]*a[7], b[4]*a[2]+b[5]*a[5]+b[6]*a[8], b[4]*a[3]+b[5]*a[6]+b[6]*a[9],
        b[7]*a[1]+b[8]*a[4]+b[9]*a[7], b[7]*a[2]+b[8]*a[5]+b[9]*a[8], b[7]*a[3]+b[8]*a[6]+b[9]*a[9]
    }
end
function mat3.transform(p,m)
    return {
        p[1]*m[1]+p[2]*m[2]+m[3],
        p[1]*m[4]+p[2]*m[5]+m[6]
    }
end
function mat3.transformPoly(p,m)
    local o = {}
    for k,v in next, p do
        o[k] = mat3.transform(v,m)
    end
    return o
end
-- equivalent to mat3.transform with an input of {0,0}
function mat3.translation(m)
    return {
        m[3],
        m[6]
    }
end
function mat3.scaling(m)
    return {
        m[1],
        m[5]
    }
end

-- extracts scale component 
function mat3.baseScaling(m)
    return {
        math.sqrt(m[1]*m[1]+m[4]*m[4]),
        math.sqrt(m[5]*m[5]+m[2]*m[2])
    }
end
-- note: not a true matrix inversion
-- https://nigeltao.github.io/blog/2021/inverting-3x2-affine-transformation-matrix.html
function mat3.invert(m)
    local fdelta = m[1]*m[5] - m[2]*m[4]
    return {
         m[5]/fdelta,-m[2]/fdelta,((m[2]*m[6])-(m[5]*m[3]))/fdelta,
        -m[4]/fdelta, m[1]/fdelta,((m[4]*m[3])-(m[1]*m[6]))/fdelta,
        0,0,1
    }
end
-- perfectly functional as long as there is no skew
function mat3.angle(m)
    return math.atan(m[4],m[1])
end
function mat3.angleMatrix(m)
    local mag = math.sqrt(m[1]*m[1]+m[4]*m[4])
    local cos = m[1]/mag
    local sin = m[4]/mag
    return {
        cos,-sin,0,
        sin,cos, 0,
        0, 0,     1
    }
end

-- exports a mat3 to something for animator.transformTransformationGroup
function mat3.export(i)
    return i[1],i[2],i[4],i[5],i[3],i[6]
end
-- exports a mat3 to something for drawable transformation
function mat3.exportJson(i)
    return {
        {i[1],i[2],i[3]},
        {i[4],i[5],i[6]},
        {i[7],i[8],i[9]}
    }
end
