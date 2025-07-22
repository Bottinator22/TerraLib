require "/scripts/vec2.lua"
require "/scripts/terra_proxy.lua"
require "/scripts/terra_subMcontroller.lua"

-- TODO: handle rest of item types
local supportedAnimationScripts
local function ensureConfigs()
    supportedAnimationScripts = supportedAnimationScripts or root.assetJson("/scripts/terra_hands/hands.config").supportedAnimationScripts
end
local function nullfunc() end
local handMcontrollerId = 0
function createActiveItemHand(item, params, extraparams)
    local mcontrollerToUse = params.mcontroller or mcontroller
    if params.mcontroller then
        params.mcontroller = nil
    end
    local hand = {}
    local itemConfig = root.itemConfig(item)
    local mergedConfig = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
    local animationScript = (mergedConfig.animationScripts or {})[1] -- most if not all vanilla items only have one defined
    local animationFileLoc = mergedConfig.animation
    local animationConfig
    if animationFileLoc then
        if type(animationFileLoc) == "table" then
            animationConfig = animationFileLoc
        else
            if string.sub(animationFileLoc,1,1) ~= "/" then
                animationFileLoc = (itemConfig.directory)..animationFileLoc
            end
            animationConfig = root.assetJson(animationFileLoc)
        end
        local animationCustom = mergedConfig.animationCustom or {}
        animationConfig = sb.jsonMerge(animationConfig, animationCustom)
        if animationConfig.animatedParts then
            for k,v in next, animationConfig.animatedParts.parts do
                if v.properties then
                    if not v.properties.anchorPart then
                        if not v.properties.transformationGroups then
                            v.properties.transformationGroups = {}
                        end
                        table.insert(v.properties.transformationGroups, "arm_weapon")
                    end
                    if v.properties.image and string.len(v.properties.image) > 0 and string.sub(v.properties.image,1,1) ~= "/" and string.sub(v.properties.image,1,1) ~= "<" then
                        v.properties.image = (itemConfig.directory)..v.properties.image
                    end
                end
                if v.partStates then
                    for k2,v2 in next, v.partStates do
                        for k3,v3 in next, v2 do
                            if v3.properties then
                                if v3.properties.image and string.len(v3.properties.image) > 0 and string.sub(v3.properties.image,1,1) ~= "/" and string.sub(v3.properties.image,1,1) ~= "<" then
                                    v3.properties.image = (itemConfig.directory)..v3.properties.image
                                end
                                if v3.properties.transformationGroups then
                                    table.insert(v3.properties.transformationGroups, "arm_weapon")
                                end
                            end
                        end
                    end
                end
            end
        end
        if animationConfig.lights then
            for k,v in next, animationConfig.lights do
                if not v.transformationGroups then
                    v.transformationGroups = {}
                end
                table.insert(v.transformationGroups, "arm_weapon")
            end
        end
        if animationConfig.particleEmitters then
            for k,v in next, animationConfig.particleEmitters do
                if not v.transformationGroups then
                    v.transformationGroups = {}
                end
                table.insert(v.transformationGroups, "arm_weapon")
            end
        end
    else
        animationConfig = {}
    end
    local mParams = root.assetJson("/scripts/terra_hands/handBasicParams.json")
    mParams.animationCustom = sb.jsonMerge(mParams.animationCustom, animationConfig)
    local mode = animationScript and supportedAnimationScripts[animationScript]
    if mode then
        if mode ~= "default" then
            if animationScript == "/items/active/effects/chain.lua" then
                mode = "chain"
            else
                mode = "lightning"
            end
        else
            mode = nil
        end
        mParams.animationScriptMode = mode
        mParams.animationScripts = mergedConfig.animationScripts
    end
    mParams = sb.jsonMerge(mParams, sb.jsonMerge({ownerId=entity.id(), item = item, scripts={"/scripts/terra_hands/handActiveItem.lua"}}, params or {}))
    mParams = sb.jsonMerge(mParams, extraparams)
    if extraparams.oneHandedRenderLayer and not mergedConfig.twoHanded then
        mParams.renderLayer = extraparams.oneHandedRenderLayer
    end
    handMcontrollerId = handMcontrollerId + 1
    local myMcontroller = buildSubMcontroller(mcontrollerToUse)
    local mcname = string.format("mcontroller_%d",handMcontrollerId)
    local cleanup = terra_proxy.setupReceiveMessages(mcname, myMcontroller.table)
    mParams.mcontrollerName = mcname
    hand.eid = world.spawnMonster("mechmultidrone", mcontroller.position(), mParams)
    function hand:getMcontroller(m)
        return myMcontroller.table
    end
    function hand:setPosition(pos, upd)
        world.callScriptedEntity(hand.eid, "setPosition",pos, upd)
    end
    function hand:setFire(mode, shiftHeld)
        world.callScriptedEntity(hand.eid, "setFire", mode, shiftHeld)
    end
    function hand:alive()
        return world.entityExists(hand.eid)
    end
    function hand:twoHanded()
        return world.callScriptedEntity(hand.eid, "twoHanded")
    end
    function hand:twoHandedGrip()
        return world.callScriptedEntity(hand.eid, "twoHandedGrip")
    end
    function hand:getItemType()
        return "activeitem"
    end
    function hand:getCompleteItemParameters()
        return mergedConfig
    end
    function hand:setOther(e)
        world.callScriptedEntity(hand.eid, "setOtherHandId",e)
    end
    function hand:setDirectives(d)
        world.callScriptedEntity(hand.eid, "status.setPrimaryDirectives", d)
    end
    function hand:update(aim, moves)
        world.callScriptedEntity(hand.eid, "keepAlive")
        world.callScriptedEntity(hand.eid, "updateMoves", moves)
        world.callScriptedEntity(hand.eid, "setAimPosition", aim)
        myMcontroller.update()
        if not hand:alive() then
            cleanup()
        end
    end
    function hand:getItem()
        return world.callScriptedEntity(hand.eid, "getItem")
    end
    function hand:destroy()
        cleanup(true)
        return world.callScriptedEntity(hand.eid, "destroy")
    end
    return hand
end
function createGenericHandWithScript(item, params, extraparams, script)
    -- uses item inventory icon for appearance
    local hand = {}
    local itemConfig = root.itemConfig(item)
    local mergedConfig = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
    local colourDirectives = ""
    if mergedConfig.colorIndex then
        for k,v in next, mergedConfig.colorOptions[mergedConfig.colorIndex+1] do
            colourDirectives=colourDirectives..string.format("?replace;%s=%s",k,v)
        end
    end
    local mParams = root.assetJson("/scripts/terra_hands/handBasicParams.json")
    if type(mergedConfig.inventoryIcon) == "string" then
        local img = mergedConfig.inventoryIcon..colourDirectives..(mergedConfig.directives or "")
        if string.sub(img,1,1) ~= "/" then
            img = (itemConfig.directory)..img
        end
        mParams.animationCustom = sb.jsonMerge(mParams.animationCustom, {
            animatedParts={
                parts={
                    item={
                        properties={
                            image=img,
                            transformationGroups={"arm_weapon"}
                        }
                    }
                }
        }})
    else
        local parts = {}
        for k,v in next, mergedConfig.inventoryIcon do
            local img = v.image..colourDirectives..(mergedConfig.directives or "")
            if string.sub(img,1,1) ~= "/" then
                img = (itemConfig.directory)..img
            end
            parts["item"..k] = {
                properties={
                    zLevel=k,
                    image=img,
                    offset=vec2.div(v.position or {0,0},8),
                    transformationGroups={"arm_weapon"}
                }
            }
        end
        mParams.animationCustom = sb.jsonMerge(mParams.animationCustom, {
            animatedParts={
                parts=parts
        }})
    end
    mParams = sb.jsonMerge(mParams, sb.jsonMerge({ownerId=entity.id(), item = item, scripts={script}}, params or {}))
    mParams = sb.jsonMerge(mParams, extraparams)
    if extraparams.oneHandedRenderLayer and not mergedConfig.twoHanded then
        mParams.renderLayer = extraparams.oneHandedRenderLayer
    end
    hand.eid = world.spawnMonster("mechmultidrone", mcontroller.position(), mParams)
    
    function hand:getMcontroller(m)
        return m
    end
    function hand:setPosition(pos, upd)
        world.callScriptedEntity(hand.eid, "setPosition",pos, upd)
    end
    function hand:setFire(mode, shiftHeld)
        world.callScriptedEntity(hand.eid, "setFire", mode, shiftHeld)
    end
    function hand:alive()
        return world.entityExists(hand.eid)
    end
    function hand:twoHanded()
        return world.callScriptedEntity(hand.eid, "twoHanded")
    end
    function hand:twoHandedGrip()
        return world.callScriptedEntity(hand.eid, "twoHandedGrip")
    end
    function hand:getItemType()
        return root.itemType(item.name or item)
    end
    function hand:getCompleteItemParameters()
        return mergedConfig
    end
    function hand:setOther(e)
        world.callScriptedEntity(hand.eid, "setOtherHandId",e)
    end
    function hand:setDirectives(d)
        world.callScriptedEntity(hand.eid, "status.setPrimaryDirectives", d)
    end
    function hand:update(aim)
        world.callScriptedEntity(hand.eid, "keepAlive")
        world.callScriptedEntity(hand.eid, "setAimPosition", aim)
    end
    function hand:getItem()
        return world.callScriptedEntity(hand.eid, "getItem")
    end
    function hand:destroy()
        return world.callScriptedEntity(hand.eid, "destroy")
    end
    return hand
end
function createGenericHand(item, params, extraparams)
    return createGenericHandWithScript(item, params, extraparams, "/scripts/terra_hands/handGenericItem.lua")
end
function createConsumableHand(item, params, extraparams)
    return createGenericHandWithScript(item, params, extraparams, "/scripts/terra_hands/handConsumableItem.lua")
end
function createThrownItemHand(item, params, extraparams)
    return createGenericHandWithScript(item, params, extraparams, "/scripts/terra_hands/handThrownItem.lua")
end
function createNullHand(item, params, extraparams)
    -- just returns a hand object that simply stores an item and does nothing
    local hand = {}
    hand.item = item
    local completeParams
    function hand:getMcontroller(m)
        return m
    end
    function hand:setPosition(pos)
    end
    function hand:setFire(mode, shiftHeld)
    end
    function hand:setDirectives()
    end
    function hand:alive()
        return true
    end
    function hand:twoHanded()
        return false
    end
    function hand:twoHandedGrip()
        return false
    end
    function hand:setOther(e)
    end
    function hand:getItemType()
        return root.itemType(item.name or item)
    end
    function hand:getCompleteItemParameters()
        if not completeParams then
            local itemConfig = root.itemConfig(item)
            completeParams = sb.jsonMerge(itemConfig.config, itemConfig.parameters)
        end
        return completeParams
    end
    function hand:update()
    end
    function hand:getItem()
        return hand.item
    end
    function hand:destroy()
        return hand.item
    end
    return hand
end
local handTypes = {
    activeitem=createActiveItemHand,
    backarmor=createGenericHand,
    headarmor=createGenericHand,
    chestarmor=createGenericHand,
    legsarmor=createGenericHand,
    consumable=createConsumableHand,
    thrownitem=createThrownItemHand
}
function createHand(item, params, extraparams)
    ensureConfigs()
    return (handTypes[root.itemType(item.name or item)] or createNullHand)(item, params, extraparams or {})
end
function handSupported(item)
    return not not handTypes[root.itemType(item.name or item)]
end
