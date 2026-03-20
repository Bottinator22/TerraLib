require "/scripts/terra_mat3.lua"
require "/scripts/terra_vec2ref.lua"
require "/scripts/terra_proxy.lua"
require "/scripts/terra_inversekinematics.lua"

local workVec21 = {0,0}
local armatureConfig
local componentConfig
bones = {}
local rootBones = {}
components = {}
facing = 1

local function transformedCenter(bone)
    return mat3.transform(bone.center,bone.appliedTransform)
end

baseRotation = nil

transformedBoneCenter = transformedCenter

function armature_boneExtraInit(bone,cfg) end
function armature_boneExtraPostInit(bone) end
function armature_boneExtraApply(bone) end

function initArmature()
    armatureConfig = config.getParameter("armature")
    componentConfig = config.getParameter("components",{})
    componentBaseConfig = sb.jsonMerge(root.assetJson("/scripts/terra_armature/component.json"),config.getParameter("componentBaseOverrides",{}))
    componentVehicleBaseConfig = sb.jsonMerge(root.assetJson("/scripts/terra_armature/componentVehicle.json"),config.getParameter("componentVehicleBaseOverrides",{}))
    componentBaseConfig.movementSettings = config.getParameter("movementSettings",componentBaseConfig.movementSettings)
    componentVehicleBaseConfig.movementSettings = componentBaseConfig.movementSettings
    
    if not storage.components then
        storage.components = {}
        for k,v in next, componentConfig do
            local baseCfg = componentBaseConfig
            if v.isVehicle then
                baseCfg = componentVehicleBaseConfig
            end
            if v.baseConfig then
                baseCfg = root.assetJson(v.baseConfig)
            end
            local cfg = sb.jsonMerge(baseCfg,v.config)
            if v.animation then
                if type(v.animation) == "string" then
                    cfg.animationCustom = root.assetJson(v.animation)
                elseif #v.animation > 0 then
                    cfg.animationCustom = {}
                    for _,p in next, v.animation do
                        cfg.animationCustom = sb.jsonMerge(cfg.animationCustom,root.assetJson(p))
                    end
                else
                    cfg.animationCustom = v.animation
                end
            end
            cfg.ownerId = entity.id()
            cfg.playerId = config.getParameter("playerId",config.getParameter("ownerId",entity.id()))
            local e
            if v.isVehicle then
                e = world.spawnVehicle("compositerailplatform",mcontroller.position(),cfg)
            else
                e = world.spawnMonster("mechmultidrone",mcontroller.position(),cfg)
            end
            storage.components[k] = e
        end
    end
    for k,v in next, storage.components do
        local c = {
            entity=v,
            entityud=world.entity(v),
            animator=terra_proxy.setupProxy("animator",v),
            anchorBone=componentConfig[k].anchorBone,
            rotOnBone=componentConfig[k].rotOnBone
        }
        components[k] = c
    end
    for k,v in next, armatureConfig do
        local b = {
            name=k,
            parentName=v.parent,
            baseTransform=mat3.identity(),
            defaultTransform=mat3.identity(),
            transform=mat3.identity(),
            appliedTransform=mat3.identity(),
            center=v.center or {0,0},
            debugColour=v.debugColour or "white",
            transformGroup=v.transformGroup,
            animator=animator,
            ikData=nil,
            ikTarget=nil,
            children={}
        }
        if v.rotation then
            b.baseTransform = mat3.rotate(b.baseTransform,v.rotation*math.pi/180,b.center) -- convert angles from degrees
        end
        if v.scale then
            b.baseTransform = mat3.scale(b.baseTransform,v.scale,b.center)
        end
        if v.position then
            b.baseTransform = mat3.translate(b.baseTransform,v.position)
        end
        if v.component then
            b.animator = components[v.component].animator
        end
        if v.calculateIK then
            b.ikData = {
                useAltSolution=v.useAltIKSolution
            }
        end
        armature_boneExtraInit(b,v)
        bones[k] = b
    end
    for k,v in next, bones do
        if v.parentName then
            local p = bones[v.parentName]
            v.parent = p
            table.insert(p.children,v)
        else
            table.insert(rootBones,v)
        end
        armature_boneExtraPostInit(v)
    end
    applyArmature()
    for k,v in next, bones do
        if v.ikData then
            local ikData = v.ikData
            local mid = v.parent
            local base = mid.parent
            ikData.mid = mid
            ikData.base = base
            
            local midPos = transformedCenter(mid)
            local basePos = transformedCenter(base)
            local endPos = transformedCenter(v)
            local baseToMidDis = vec2.sub(midPos,basePos)
            local midToEndDis = vec2.sub(endPos,midPos)
            
            ikData.firstLength = vec2.mag(baseToMidDis)
            ikData.firstAngleOffset = vec2.angle(baseToMidDis)
            
            ikData.secondLength = vec2.mag(midToEndDis)
            ikData.secondAngleOffset = vec2.angle(midToEndDis)-ikData.firstAngleOffset
        end
    end
end

function resetArmature()
    for k,v in next, bones do
        v.transform = v.defaultTransform
    end
end

local function absolute(pos)
    return vec2.add(vec2.mul(pos,{facing,1}), mcontroller.position())
end
local function relative(pos)
    return vec2.mul(world.distance(pos,mcontroller.position()),{facing,1})
end

absolutePos = absolute
relativePos = relative

local rootTransform
function applyBone(bone)
    if bone.parent then
        bone.appliedTransform = mat3.multiply(mat3.multiply(bone.transform,bone.baseTransform),bone.parent.appliedTransform)
        world.debugLine(absolute(transformedCenter(bone)),absolute(transformedCenter(bone.parent)),bone.debugColour)
    else
        bone.appliedTransform = mat3.multiply(mat3.multiply(bone.transform,bone.baseTransform),rootTransform)
        world.debugLine(absolute(transformedCenter(bone)),mcontroller.position(),bone.debugColour)
    end
    world.debugPoint(absolute(transformedCenter(bone)),bone.debugColour)
    world.debugLine(absolute(transformedCenter(bone)),absolute(mat3.transform(vec2.addToRef(bone.center,{0.25,0},workVec21),bone.appliedTransform)),bone.debugColour)
    if bone.transformGroup then
        bone.animator.resetTransformationGroup(bone.transformGroup)
        bone.animator.transformTransformationGroup(bone.transformGroup,mat3.export(bone.appliedTransform))
        if bone.component and bone.component.anchorBone then
            local comp = bone.component
            local anchor = bones[comp.anchorBone]
            bone.animator.translateTransformationGroup(bone.transformGroup,vec2.mulToRef(mat3.translation(anchor.appliedTransform),-1,workVec21))
        end
        if bone.alsoTransformOn then
            for k,v in next, bone.alsoTransformOn do
                v.animator.resetTransformationGroup(bone.transformGroup)
                v.animator.transformTransformationGroup(bone.transformGroup,mat3.export(bone.appliedTransform))
            end
        end
    end
    armature_boneExtraApply(bone)
    for k,v in next, bone.children do
        applyBone(v)
    end
end

function applyArmature()
    animator.resetTransformationGroup("flip")
    animator.scaleTransformationGroup("flip",{facing,1})
    for k,v in next, components do
        v.animator.resetTransformationGroup("flip")
        v.animator.scaleTransformationGroup("flip",{facing,1})
    end
    rootTransform = mat3.getRotationMatrix(baseRotation or mcontroller.rotation())
    for k,v in next, rootBones do
        applyBone(v)
    end
end

local veryBig = 2^1023
local function isNaN(n)
    return (not (n < 0) and not (n > 0) and not (n == 0)) or math.abs(n) > veryBig
end

function boneBasePos(bone)
    local appliedTransform = mat3.multiply(bone.baseTransform,bone.parent.appliedTransform)
    
    return mat3.transform(bone.center,appliedTransform),appliedTransform
end

-- 2^53 is the limit before adding/subbing from 1 makes it equal to 1
-- make this fraction a bit larger than that to account for other imprecisions in the math of IK
local verySmall = 1/(2^10)
local greaterThanOne = 1 + verySmall
local lessThanOne = 1 - verySmall

function performIK(bone,targetPos)
    -- IK relies on the 2 bones directly before the IKed bone
    local ikData = bone.ikData
    
    local base = ikData.base
    
    -- calculate IK
    
    -- appliedTransfrom still has the existing base bone transformation, calculate a version without
    -- NOTE: assumes base has a parent
    local appliedTransform = mat3.multiply(base.baseTransform,base.parent.appliedTransform)
    
    local basePos = mat3.transform(base.center,appliedTransform)
    world.debugLine(absolute(basePos),absolute(targetPos),bone.debugColour)
    
    local inv = mat3.invert(appliedTransform)
    local relTargetPos = mat3.transform(targetPos,inv)
    
    -- clamp the bone so it doesn't break
    -- unfortunately it seems to be broken if length >= maxLength, so we have to add a miniscule offset
    -- this is... annoyingly weird, need to figure out what the actual limit is
    local diff = vec2.sub(relTargetPos,base.center)
    local maxLength = ikData.firstLength+ikData.secondLength
    local minLength = math.abs(ikData.firstLength-ikData.secondLength)
    if vec2.mag(diff) >= maxLength then
        relTargetPos = vec2.add(base.center,vec2.mul(vec2.norm(diff),maxLength*lessThanOne))
    elseif vec2.mag(diff) <= minLength then
        relTargetPos = vec2.add(base.center,vec2.mul(vec2.norm(diff),minLength*greaterThanOne))
    end
    
    local Aa,Ba = inversekinematics.solveAngles(relTargetPos,base.center,ikData.firstLength,ikData.secondLength,ikData.useAltSolution)
    
    if isNaN(Aa) or isNaN(Ba) then
        -- revert and do nothing
        base.transform = lastBaseTransform
    else
        -- reset the other bones so they can be retransformed
        base.transform = base.defaultTransform
        ikData.mid.transform = ikData.mid.defaultTransform
        bone.transform = bone.defaultTransform
        
        base.transform = mat3.rotate(base.transform, Aa-ikData.firstAngleOffset,base.center)
        ikData.mid.transform = mat3.rotate(ikData.mid.transform, -Ba-ikData.secondAngleOffset,ikData.mid.center)
        
        applyBone(base)
    end
end

function updateComponentsPos(r)
    -- should be done after bone application
    -- can be done later in case this entity is moved by another
    for k,v in next, components do
        if v.anchorBone then
            local anchor = bones[v.anchorBone]
            --bone.animator.translateTransformationGroup(bone.transformGroup,vec2.mulToRef(mat3.translation(anchor.appliedTransform),-1,workVec21))
            world.callScriptedEntity(v.entity,"component_setPosition",vec2.addToRef(mcontroller.position(),mat3.translation(anchor.appliedTransform),workVec21))
            if v.rotOnBone then
                world.callScriptedEntity(v.entity,"component_setRotation",mat3.angle(anchor.appliedTransform),workVec21)
            else
                world.callScriptedEntity(v.entity,"component_setRotation",r or mcontroller.rotation())
            end
        else
            world.callScriptedEntity(v.entity,"component_setPosition",mcontroller.position())
            world.callScriptedEntity(v.entity,"component_setRotation",r or mcontroller.rotation())
        end
    end
end

function updateComponentsPos_withVel(r)
    -- should be done after bone application
    -- can be done later in case this entity is moved by another
    local mpos = vec2.add(mcontroller.position(),vec2.mul(mcontroller.velocity(),script.updateDt()))
    for k,v in next, components do
        if v.anchorBone then
            local anchor = bones[v.anchorBone]
            --bone.animator.translateTransformationGroup(bone.transformGroup,vec2.mulToRef(mat3.translation(anchor.appliedTransform),-1,workVec21))
            world.callScriptedEntity(v.entity,"component_setPosition",vec2.addToRef(mpos,mat3.translation(anchor.appliedTransform),workVec21))
            if v.rotOnBone then
                world.callScriptedEntity(v.entity,"component_setRotation",mat3.angle(anchor.appliedTransform),workVec21)
            else
                world.callScriptedEntity(v.entity,"component_setRotation",r or mcontroller.rotation())
            end
        else
            world.callScriptedEntity(v.entity,"component_setPosition",mpos)
            world.callScriptedEntity(v.entity,"component_setRotation",r or mcontroller.rotation())
        end
    end
end
