
-- This function allows building mcontroller contexts that have their own controls without having to worry about messing with the original controls,
-- or worrying about using controls outside the parent's tick.
local function nullFunc() end
function buildSubMcontroller(mcontroller,pControlFuncs, pExcludedFuncs)
    local out = {}
    out.controls = {}
    out.autoClearControls = true
    local controlFuncs = pControlFuncs or {
        "controlRotation",
        "controlAcceleration",
        "controlForce",
        "controlApproachVelocity",
        "controlApproachVelocityAlongAngle",
        "controlApproachXVelocity",
        "controlApproachYVelocity",
        "controlParameters",
        "controlModifiers",
        "controlMove",
        "controlDown",
        "controlJump",
        "controlHoldJump",
        "controlFly",
        "controlFace"
    }
    local excludedFuncs = pExcludedFuncs or {}
    -- builds an mcontroller table that properly handles controls
    local outT = {}
    setmetatable(outT, {__index=mcontroller})
    function outT.clearControls()
        out.controls = {}
    end
    function outT.autoClearControls()
        return out.autoClearControls
    end
    function outT.setAutoClearControls(e)
        out.autoClearControls = e
    end
    for _,v in next, controlFuncs do
        outT[v] = function(...)
            table.insert(out.controls, {func=mcontroller[v],args={...}})
        end
    end
    for _,v in next, excludedFuncs do
        outT[v] = nullfunc
    end
    out.table = outT
    out.clearOnUpdate = true
    function out.update()
        if mcontroller.autoClearControls() then
            for k,v in next, out.controls do
                v.func(table.unpack(v.args))
            end
            if out.autoClearControls and out.clearOnUpdate then
                out.controls = {}
            end
        else
            -- this functionality requires autoClearControls to be true on the owner
            out.controls = {}
        end
    end
    function out.autoclear()
        if out.autoClearControls then
            out.controls = {}
        end
    end
    return out
end
