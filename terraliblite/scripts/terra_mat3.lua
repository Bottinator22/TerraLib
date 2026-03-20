-- Utility script for dealing with 3d affine transformation matrices.
local identity = {
    1,0,0,
    0,1,0,
    0,0,1
}
local zeroVec = {0,0}
local function dot3(a,b,c,d,e,f)
    return a*b+c*d+e*f
end
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
    local n = mat3.getTranslationMatrix(t)
    return mat3.multiply(m,n)
end
function mat3.scale(m,sot,p)
    local n = mat3.getScalingMatrix(sot,p)
    return mat3.multiply(m,n)
end
function mat3.rotate(m,r,p)
    local n = mat3.getRotationMatrix(r,p)
    return mat3.multiply(m,n)
end
function mat3.multiply(b,a)
    return {
        dot3(a[1],b[1],a[2],b[4],a[3],b[7]),dot3(a[1],b[2],a[2],b[5],a[3],b[8]),dot3(a[1],b[3],a[2],b[6],a[3],b[9]),
        dot3(a[4],b[1],a[5],b[4],a[6],b[7]),dot3(a[4],b[2],a[5],b[5],a[6],b[8]),dot3(a[4],b[3],a[5],b[6],a[6],b[9]),
        dot3(a[7],b[1],a[8],b[4],a[9],b[7]),dot3(a[7],b[2],a[8],b[5],a[9],b[8]),dot3(a[7],b[3],a[8],b[6],a[9],b[9])
    }
end
function mat3.transform(p,m)
    return {
        p[1]*m[1]+p[2]*m[2]+m[3],
        p[1]*m[4]+p[2]*m[5]+m[6]
    }
end
-- equivalent to mat3.transform with an input of {0,0}
function mat3.translation(m)
    return {
        m[3],
        m[6]
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
-- exports a mat3 to something for animator.transformTransformationGroup
function mat3.export(i)
    return i[1],i[2],i[4],i[5],i[3],i[6]
end
