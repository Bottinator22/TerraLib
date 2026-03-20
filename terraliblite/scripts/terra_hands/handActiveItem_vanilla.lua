require "/scripts/util.lua"
require "/scripts/terra_vec2ref.lua"
require "/scripts/terra_polyref.lua"
require "/scripts/status.lua"
require "/scripts/terra_proxy.lua"
require "/scripts/terra_scriptLoader.lua"

ownerId = nil
rootOwnerId = nil
local dieTimer = 20
doDie = false
fireMode = "none"
local scriptEnv = {}
scriptTables = {activeItem={},script={},config={},item={},message={}}
aimPosition = {0,0}
local needTables = false
iisHeld = true
itwoHandedGrip = false
irecoil = false
ioutsideHand = false
local workVec21 = {0,0}
local workVec22 = {0,0}
local toTrack = {
  "init",
  "update",
  "activate",
  "uninit"
}
itemScript = nil
local itemConfig = {}
local moves = {}
deleteVal = {}
damageSources = {}
itemDamageSources = {}
forceRegions = {}
itemForceRegions = {}
itemScriptDelta = 1
local itemScriptTimer = 0
local facing = 1
local armLength = 0
armPosition = nil
otherHand = nil
canControlFacing = false
whichHand = "primary"
local backArmOffsets = {
    ["rotation"]={0,-0.125},
    ["duck.1"]={-0.625,-1.125},
    ["duckMelee"]={-0.75,-1.375},
    ["idleMelee"]={-1,-0.875},
    ["fall.1"]={-0.25,-0.25},
    ["fall.2"]={-0.375,0.875},
    ["fall.3"]={-0.625,1.125},
    ["fall.4"]={-0.625,1.25},
    ["jump.1"]={-0.875,-0.75},
    ["jump.2"]={-0.625,-0.125},
    ["jump.3"]={-0.5,0.125},
    ["jump.4"]={-0.5,0.25},
    ["idle.1"]={-1,-1},
    ["idle.2"]={-1,-0.75},
    ["idle.3"]={-0.875,-0.625},
    ["idle.4"]={-0.875,-0.75},
    ["idle.5"]={-0.75,-0.75},
    ["run.1"]={0,-0.125},
    ["run.2"]={0,-0.125},
    ["run.3"]={-0.75,-0.875},
    ["run.4"]={-0.625,-0.125},
    ["run.5"]={-0.375,0.25},
    ["walk.1"]={0,-0.125},
    ["walk.2"]={0,-0.125},
    ["walk.3"]={0,-0.125},
    ["walk.4"]={-1,-1},
    ["walk.5"]={-0.875,-0.875},
    ["swimIdle.1"]={-0.5,0},
    ["swimIdle.2"]={-0.5,-0.25},
    ["swim.1"]={-0.625,0.125},
    ["swim.2"]={-0.75,-0.125},
    ["swim.3"]={-0.125,0.375},
    ["swim.4"]={-0.375,0.25},
    ["swim.5"]={-0.5,0.25}
}
local frontArmOffsets = {
    ["rotation"]={0,0},
    ["duck.1"]={-2.25,-1.125},
    ["duckMelee"]={-1.75,-1.25},
    ["idleMelee"]={-1.5,-1},
    ["fall.1"]={-2.25,0},
    ["fall.2"]={-2.25,1.125},
    ["fall.3"]={-1.875,1.5},
    ["fall.4"]={-1.75,1.625},
    ["jump.1"]={-1,-0.375},
    ["jump.2"]={-1.625,-0.625},
    ["jump.3"]={-1.75,-0.375},
    ["jump.4"]={-1.75,-0.25},
    ["idle.1"]={-1.5,-0.875},
    ["idle.2"]={-1.375,-0.625},
    ["idle.3"]={-1.875,-0.5},
    ["idle.4"]={-1.75,-0.75},
    ["idle.5"]={-2,-0.625},
    ["run.1"]={-0.375,0.375},
    ["run.2"]={-0.5,0.125},
    ["run.3"]={-0.875,-0.625},
    ["run.4"]={-1.5,-0.75},
    ["run.5"]={-1.625,-0.25},
    ["walk.1"]={-0.625,-0.75},
    ["walk.2"]={-0.875,-0.875},
    ["walk.3"]={-1.25,-0.875},
    ["walk.4"]={-1.5,-0.875},
    ["walk.5"]={-1.75,-0.875},
    ["swimIdle.1"]={-1,0.125},
    ["swimIdle.2"]={-1.125,-0.125},
    ["swim.1"]={-1.375,0.25},
    ["swim.2"]={-0.625,0.25},
    ["swim.3"]={0,0.5},
    ["swim.4"]={-0.5,0.375},
    ["swim.5"]={-0.875,0.375}
}
ibackArmFrame = "rotation"
ifrontArmFrame = "rotation"
function anyHandNotDefault()
  return not not (frontArmOffsets[ifrontArmFrame] or backArmOffsets[ibackArmFrame])
end
function getHandOffset(isPrimary, default)
  if isPrimary then
    return (frontArmOffsets[ifrontArmFrame] and transformOffset(frontArmOffsets[ifrontArmFrame])) or default or {0,0}
  else
    return (backArmOffsets[ibackArmFrame] and transformOffset(backArmOffsets[ibackArmFrame])) or default or {0,0}
  end
end
function getPrimaryHandOffset()
  return getHandOffset(true)
end
function getAltHandOffset()
  return vec2.add(getHandOffset(false), {0.5*scriptTables.mcontroller.facingDirection(), 0.125})
end
local autoDestroy = true
local captureAnimationParameters = false
local animationScriptMode = nil
local animParams = {}
local isShiftHeld = false
function equals(o1, o2, ignore_mt)
    if o1 == o2 then return true end
    local o1Type = type(o1)
    local o2Type = type(o2)
    if o1Type ~= o2Type then return false end
    if o1Type ~= 'table' then return false end
    if not ignore_mt then
        local mt1 = getmetatable(o1)
        if mt1 and mt1.__eq then
            --compare using built in method
            return o1 == o2
        end
    end
    local keySet = {}
    for key1, value1 in pairs(o1) do
        local value2 = o2[key1]
        if value2 == nil or equals(value1, value2, ignore_mt) == false then
            return false
        end
        keySet[key1] = true
    end
    for key2, _ in pairs(o2) do
        if not keySet[key2] then return false end
    end
    return true
end
local defaults
local rotGroups = {}
handlers = {}
itemParameters = {}
function handleMessage(n,...)
  if handlers[n] then
    return handlers[n](n,...)
  end
end
function setHandHandler(n,i)
  world.sendEntityMessage(ownerId,"terra_setHandHandler",n,i)
end
local mcontrollerName
-- Engine callback - called on initialization of entity
function init()
    self.shouldDie = true
    defaults = root.assetJson("/items/defaultParameters.config")
    ownerId = config.getParameter("ownerId")
    rootOwnerId = config.getParameter("rootOwnerId", ownerId)
    autoDestroy = config.getParameter("autoDestroy", true) -- if true, destroys the monster if item count is below 0 at end of tick
    whichHand = config.getParameter("whichHand","primary")
    armLength = config.getParameter("armLength",0)
    canControlFacing = config.getParameter("canControlFacing", false)
    mcontrollerName = config.getParameter("mcontrollerName","mcontroller")
    armPosition = mcontroller.position()
    animationScriptMode = config.getParameter("animationScriptMode")
    if animationScriptMode ~= nil then
      captureAnimationParameters = true
    end
    storage.item = storage.item or config.getParameter("item")
    storage.itemStorage = storage.itemStorage or itemParameters.scriptStorage or {}
    itemScriptDelta = itemParameters.scriptDelta or 1
    scriptTables.storage = storage.itemStorage
    scriptTables.self = {} -- I don't use self table, so the item script having the original shouldn't be problematic
    scriptTables.monsterstorage = storage
    if type(storage.item) == "string" then
        storage.item = {name=storage.item,count=1,parameters={}}
    end
    if not storage.item.parameters then
        storage.item.parameters = {}
        storage.item.count = 1
    end        
    itemConfig = root.itemConfig(storage.item)
    itemParameters = sb.jsonMerge(itemConfig.config, storage.item.parameters)
    itwoHandedGrip = twoHanded()
  monster.setAggressive(false)
  monster.setDamageOnTouch(false)

  self.collisionPoly = mcontroller.collisionPoly()
  
  script.setUpdateDelta(1)
  
  mcontroller.setAutoClearControls(false)

  animator.setGlobalTag("flipX", "")
  
  mcontroller.controlFace(1)
  monster.setName("Hand")
  scriptTables.status = terra_proxy.setupProxy("status",ownerId)
  if not scriptTables.status then
    needTables = true
  else
    scriptTables.mcontroller = terra_proxy.setupProxy(mcontrollerName,ownerId)
    scriptTables.player = terra_proxy.setupProxy("player",ownerId)
    scriptTables.entity = terra_proxy.setupProxy("entity",ownerId)
  end
  
  for k,v in next, itemParameters.animationParts or {} do
    if string.sub(v,1,1) ~= "/" and string.len(v) > 0 then
        v = (itemConfig.directory)..v
    end
    animator.setPartTag(k,"partImage",v)
  end
  function scriptTables.config.getParameter(p,d)
    local out
    if p == "" then
      out = sb.jsonMerge({}, sd_originalEnv().itemParameters)
    else
      out = sd_originalEnv().itemParameters[p] or d
      if type(out) == "table" then
        return sb.jsonMerge({}, out)
      end
    end
    return out
  end
  function scriptTables.message.setHandler(n,f)
    if f then
      handlers[n] = sd_originalEnv().itemScript.sd_wrap(f)
      setHandHandler(n,entity.id())
    else
      handlers[n] = nil
    end
  end
  -- recreate script table
  function scriptTables.script.setUpdateDelta(d)
    sd_originalEnv().itemScriptDelta = d
  end
  function scriptTables.script.updateDt()
    return sd_originalEnv().script.updateDt()
  end
  -- recreate activeItem table
  function scriptTables.activeItem.ownerEntityId()
    return sd_originalEnv().rootOwnerId
  end
  function scriptTables.activeItem.ownerDamageTeam()
    return sd_originalEnv().world.entityDamageTeam(sd_originalEnv().rootOwnerId)
  end
  function scriptTables.activeItem.ownerAimPosition()
    return sd_originalEnv().aimPosition
  end
  function scriptTables.activeItem.fireMode()
    return sd_originalEnv().fireMode
  end
  function scriptTables.activeItem.hand()
    return sd_originalEnv().whichHand
  end
  function scriptTables.activeItem.handPosition(off)
    local vec2 = sd_originalEnv().vec2
    local world = sd_originalEnv().world
    if off then
        return world.distance(vec2.add(vec2.mulToRef(vec2.rotateToRef(off, sd_originalEnv().mcontroller.rotation(), workVec21), {sd_originalEnv().scriptTables.mcontroller.facingDirection(), 1}, workVec22), sd_originalEnv().mcontroller.position()),sd_originalEnv().scriptTables.mcontroller.position())
    else
        return world.distance(sd_originalEnv().mcontroller.position(),sd_originalEnv().scriptTables.mcontroller.position())
    end
  end
  function scriptTables.activeItem.aimAngleAndDirection(aimVertOffset, target)
    local vec2 = sd_originalEnv().vec2
    local world = sd_originalEnv().world
    local d = world.distance(target, sd_originalEnv().armPosition)
    local facing = sd_originalEnv().canControlFacing and (d[1] > 0 and 1 or -1) or sd_originalEnv().scriptTables.mcontroller.facingDirection()
    d[1] = d[1] * facing
    return vec2.angle(d), facing
  end
  function scriptTables.activeItem.aimAngle(aimVertOffset, target)
    local vec2 = sd_originalEnv().vec2
    local world = sd_originalEnv().world
    local facing = sd_originalEnv().scriptTables.mcontroller.facingDirection()
    local d = world.distance(target, sd_originalEnv().armPosition)
    --d[1] = d[1] * facing
    return vec2.angle(d)
  end
  function scriptTables.activeItem.setHoldingItem(h)
    sd_originalEnv().iisHeld = h
  end
  function scriptTables.activeItem.setBackArmFrame(f)
    if f and string.find(f,"?") then
      f = string.sub(f,0,string.find(f,"?")-1)
    end
    sd_originalEnv().ibackArmFrame = f or "rotation"
  end
  function scriptTables.activeItem.setFrontArmFrame(f)
    if f and string.find(f,"?") then
      f = string.sub(f,0,string.find(f,"?")-1)
    end
    sd_originalEnv().ifrontArmFrame = f or "rotation"
  end
  function scriptTables.activeItem.setTwoHandedGrip(t)
    sd_originalEnv().itwoHandedGrip = t
  end
  function scriptTables.activeItem.setRecoil(b)
    sd_originalEnv().irecoil = b
  end
  function scriptTables.activeItem.setOutsideOfHand(b)
    sd_originalEnv().ioutsideHand = b
  end
  function scriptTables.activeItem.setArmAngle(a)
    sd_originalEnv().mcontroller.setRotation(a)
  end
  function scriptTables.activeItem.setFacingDirection(f)
    local world = sd_originalEnv().world
    --mcontroller.controlFace(f)
    if world.entityType(sd_originalEnv().ownerId) == "monster" then
      world.callScriptedEntity(sd_originalEnv().ownerId, "setFacing", f)
    end
  end
  function scriptTables.activeItem.setDamageSources(d)
    sd_originalEnv().damageSources = d or {}
  end
  function scriptTables.activeItem.setItemDamageSources(d)
    sd_originalEnv().itemDamageSources = d or {}
  end
  function scriptTables.activeItem.setShieldPolys(p)
    -- not possible currently
  end
  function scriptTables.activeItem.setItemShieldPolys(p)
    -- not possible currently
  end
  function scriptTables.activeItem.setForceRegions(f)
    sd_originalEnv().forceRegions = f or {}
  end
  function scriptTables.activeItem.setItemForceRegions(f)
    sd_originalEnv().itemForceRegions = f or {}
  end
  function scriptTables.activeItem.setCursor(c)
    -- not possible currently
  end
  function scriptTables.activeItem.setScriptedAnimationParameter(p,v)
    if captureAnimationParameters then
      if v == nil then
        animParams[p] = sd_originalEnv().deleteVal
      else
        animParams[p] = v
      end
    else
      monster.setAnimationParameter(p,v)
    end
  end
  function scriptTables.activeItem.setInventoryIcon(i)
    monsterstorage.item.parameters.inventoryIcon = i
    sd_originalEnv().itemParameters = sb.jsonMerge(itemConfig.config, monsterstorage.item.parameters)
  end
  function scriptTables.activeItem.setInstanceValue(p,v)
    monsterstorage.item.parameters[p] = v
    sd_originalEnv().itemParameters = sb.jsonMerge(itemConfig.config, monsterstorage.item.parameters)
  end
  function scriptTables.activeItem.callOtherHandScript(func,...)
    local world = sd_originalEnv().world
    if otherHand and world.entityExists(otherHand) then
        return world.callScriptedEntity(otherHand, "callItemScript", func, ...)
    end
  end
  function scriptTables.activeItem.interact(t,c,id)
    if scriptTables.player then
        return scriptTables.player.interact(t,c,id)
    end
  end
  function scriptTables.activeItem.emote(e)
    if scriptTables.player and scriptTables.player.emote then
        scriptTables.player.emote(e)
    end
  end
  function scriptTables.activeItem.setCameraFocusEntity(id)
    if scriptTables.player and scriptTables.player.setCameraFocusEntity then
        scriptTables.player.setCameraFocusEntity(id)
    end
  end
  function scriptTables.activeItem.ownerPowerMultiplier()
    return scriptTables.status.stat("powerMultiplier")
  end
  function scriptTables.activeItem.ownerTeam()
    local world = sd_originalEnv().world
    return world.entityDamageTeam(rootOwnerId)
  end
  function scriptTables.item.name()
    return monsterstorage.item.name
  end
  function scriptTables.item.count()
    return monsterstorage.item.count or 1
  end
  function scriptTables.item.setCount(c)
    monsterstorage.item.count = c
  end
  function scriptTables.item.maxStack()
    return scriptTables.config.getParameter("maxStack",defaults.defaultMaxStack)
  end
  --item.is and item.matchingDescriptor don't even exist in the source code?
  -- wiki outdated again... I just keep using it out of convenience, but it's very outdated
  function scriptTables.item.matches(other, exact)
    if monsterstorage.item.name == (other.name or other) then
      if exact then
        if not other.name then
          for k,v in next, monsterstorage.item.parameters do
            return false
          end
          return true
        end
        return equals(monsterstorage.item.parameters, other.parameters)
      else
        return true
      end
    end
  end
  function scriptTables.item.consume(c)
    monsterstorage.item.count = monsterstorage.item.count - (c or 1)
    return monsterstorage.item.count >= 0
  end
  function scriptTables.item.empty()
    return monsterstorage.item.count == 0
  end
  function scriptTables.item.descriptor()
    return monsterstorage.item
  end
  function scriptTables.item.description()
    return scriptTables.config.getParameter("description")
  end
  function scriptTables.item.friendlyName()
    return scriptTables.config.getParameter("shortdescription")
  end
  local rarities = {
    common=0,
    uncommon=1,
    rare=2,
    legendary=3,
    essential=4
  }
  function scriptTables.item.rarity()
    return rarities[string.lower(scriptTables.config.getParameter("rarity","Common"))]
  end
  function scriptTables.item.rarityString()
    return scriptTables.config.getParameter("rarity","Common")
  end
  function scriptTables.item.price()
    return scriptTables.config.getParameter("price",defaults.defaultPrice)
  end
  function scriptTables.item.fuelAmount()
    return scriptTables.config.getParameter("fuelAmount",0)
  end
  function scriptTables.item.iconDrawables()
    -- nothing for now
    return {}
  end
  function scriptTables.item.dropDrawables()
    -- nothing for now
    return {}
  end
  function scriptTables.item.largeImage()
    return scriptTables.config.getParameter("largeImage")
  end
  function scriptTables.item.tooltipKind()
    return scriptTables.config.getParameter("tooltipKind")
  end
  function scriptTables.item.category()
    return scriptTables.config.getParameter("category")
  end
  function scriptTables.item.pickupSound()
    return scriptTables.config.getParameter("pickupSound")
  end
  function scriptTables.item.twoHanded()
    return scriptTables.config.getParameter("twoHanded",false)
  end
  function scriptTables.item.timeToLive()
    return scriptTables.config.getParameter("timeToLive",defaults.defaultTimeToLive)
  end
  function scriptTables.item.learnBlueprintsOnPickup()
    return {}
  end
  function scriptTables.item.hasItemTag(tag)
    local tags = scriptTables.config.getParameter("itemTags",{})
    for k,v in next, tags do
      if v == tag then
        return true
      end
    end
    return false
  end
  function scriptTables.item.pickupQuestTemplates()
    return scriptTables.config.getParameter("pickupQuestTemplates")
  end
  if not needTables then
    local scripts = {}
    for k,v in next, itemParameters.scripts or {} do
      if string.sub(v,1,1) ~= "/" then
        v = itemConfig.directory..v
      end
      table.insert(scripts, v)
    end
    itemScript = scriptLoader.loadMultiple(scripts, scriptTables, scriptEnv, toTrack)
    if itemScript.init then
      itemScript.init()
    end
  end
end
function setPosition(p, upd)
    armPosition = p
    if upd then
      local facing = scriptTables.mcontroller.facingDirection()
      mcontroller.setPosition(vec2.add(armPosition, vec2.addToRef(vec2.mulToRef(vec2.withAngle(mcontroller.rotation(),armLength), {facing, 1}, workVec21), {irecoil and (facing*-0.125) or 0, 0}, workVec21)))
    end
end
function setOtherHandId(i)
    otherHand = i
end
function callItemScript(func, ...)
    if needTables then
        return
    end
    if itemScript[func] then
      return itemScript[func](...)
    end
end
function isHeld()
  return iisHeld
end
function twoHanded()
  return itemParameters.twoHanded
end
function twoHandedGrip()
  return itwoHandedGrip
end
function noHeal()
  return true
end
function setTables()
    -- tables should have been provided beforehand through terra_proxy relays
    scriptTables.status = terra_proxy.setupProxy("status",ownerId)
    scriptTables.mcontroller = terra_proxy.setupProxy(mcontrollerName,ownerId)
    scriptTables.player = terra_proxy.setupProxy("player",ownerId)
    scriptTables.entity = terra_proxy.setupProxy("entity",ownerId)
    needTables = false
    local scripts = {}
    for k,v in next, itemParameters.scripts or {} do
      if string.sub(v,1,1) ~= "/" then
        v = itemConfig.directory..v
      end
      table.insert(scripts, v)
    end
    itemScript = scriptLoader.loadMultiple(scripts, scriptTables, scriptEnv, toTrack)
    if itemScript.init then
      itemScript.init()
    end
end
function keepAlive()
  dieTimer = 20
end
function transformOffset(v)
  return vec2.mul(vec2.rotateToRef(v, mcontroller.rotation(), workVec21), {scriptTables.mcontroller.facingDirection(), 1})
end
function transform(v)
  return vec2.add(vec2.mulToRef(vec2.rotateToRef(v, mcontroller.rotation(), workVec21), {scriptTables.mcontroller.facingDirection(), 1}, workVec22), mcontroller.position())
end
function update(dt)
  mcontroller.setVelocity({0,0})
  dieTimer = dieTimer - 1
  if needTables then
    return 
  end
  if not world.entityExists(ownerId) then
    return
  end
  animator.resetTransformationGroup("arm_weapon")
  local facing = scriptTables.mcontroller.facingDirection()
  itemScriptTimer = itemScriptTimer + 1
  if itemScriptDelta > 0 and itemScriptTimer >= itemScriptDelta then
    itemScriptTimer = 0
    if itemScript.update then
      itemScript.update(dt*itemScriptDelta, fireMode, isShiftHeld, moves)
    end
  end
  mcontroller.setPosition(vec2.add(armPosition, vec2.addToRef(vec2.mulToRef(vec2.withAngle(mcontroller.rotation(),armLength), {facing, 1}, workVec21), {irecoil and (facing*-0.125) or 0, 0}, workVec21)))
  if captureAnimationParameters then
    local newAnimParams = {}
    for k,v in next, animParams do
      if v == deleteVal then
        monster.setAnimationParameter(k,nil)
      else
        if animationScriptMode == "chain" and k == "chains" then
          newAnimParams[k] = v
          for k2,v2 in next, v do
            local v3
            if not v2.sourcePart and not v2.startPosition then
              -- handle case here instead
              v3 = sb.jsonMerge({}, v2)
              if v2.startOffset then
                v3.startPosition = vec2.add(vec2.mulToRef(vec2.rotateToRef(v2.startOffset, mcontroller.rotation(), workVec21), {facing, 1}, workVec22), mcontroller.position())
              else
                v3.startPosition = mcontroller.position()
              end
            end
            if not v2.endPart and not v2.endPosition and not v2.targetEntityId then
              -- handle case here instead
              v3 = v3 or sb.jsonMerge({}, v2)
              if v2.endOffset then
                v3.endPosition = vec2.add(vec2.mulToRef(vec2.rotateToRef(v2.endOffset, mcontroller.rotation(), workVec21), {facing, 1}, workVec22), mcontroller.position())
              else
                v3.endPosition = mcontroller.position()
              end
            end
            v[k2] = v3 or v2
          end
        elseif animationScriptMode == "lightning" and k == "lightning" then
          newAnimParams[k] = v
          for k2,bolt in next, v do
            local bolt2
            if bolt.itemStartPosition then
              bolt2 = sb.jsonMerge({}, bolt)
              bolt2.worldStartPosition = vec2.add(vec2.mulToRef(vec2.rotateToRef(bolt.itemStartPosition, mcontroller.rotation(), workVec21), {facing, 1}, workVec22), mcontroller.position())
            end
            if bolt.itemEndPosition then
              bolt2 = bolt2 or sb.jsonMerge({}, bolt)
              bolt2.worldEndPosition = vec2.add(vec2.mulToRef(vec2.rotateToRef(bolt.itemEndPosition, mcontroller.rotation(), workVec21), {facing, 1}, workVec22), mcontroller.position())
            end
            v[k2] = bolt2 or bolt
          end
        else
          newAnimParams[k] = v
        end
        monster.setAnimationParameter(k,v)
      end
    end
    animParams = newAnimParams
  end
  local ownerPos = scriptTables.mcontroller.position()
  local mePos = mcontroller.position()
  --world.debugText(string.format("%s\n%s",ibackArmFrame,ifrontArmFrame), mcontroller.position(), "green")
  local ds = {}
  for k,v in next, damageSources do
    local p = v.poly or v.line
    if facing == -1 then
        --p = poly.flip(p)
    end
    p = poly.translate(p, vec2.mulToRef(mcontroller.position(), -1, workVec21))
    p = poly.translate(p, ownerPos)
    if v.line then
      v.line = p
    else
      v.poly = p
    end
    table.insert(ds, v)
  end
  for k,v in next, itemDamageSources do
    local p = v.poly or v.line
    p = poly.rotate(p, mcontroller.rotation())
    if facing == -1 then
        p = poly.flip(p)
    end
    if v.line then
      v.line = p
    else
      v.poly = p
    end
    table.insert(ds, v)
  end
  monster.setDamageSources(ds)
  local fr = {}
  for k,v in next, forceRegions do
    local f = {}
    for k2,v2 in next, v do
        if k2 == "rectRegion" then
            f.rectRegion = {v.rectRegion[1]*facing + ownerPos[1],v.rectRegion[2] + ownerPos[2],v.rectRegion[3]*facing + ownerPos[1],v.rectRegion[4] + ownerPos[2]}
            if facing == -1 then
                local p = f.rectRegion[1]
                f.rectRegion[1] = f.rectRegion[3]
                f.rectRegion[3] = p
            end
        elseif k2 == "polyRegion" then
            local p = v.polyRegion
            if facing == -1 then
                p = poly.flip(p)
            end
            f.polyRegion = poly.translate(p, ownerPos)
        elseif k2 == "center" then
            f.center = vec2.add(vec2.mulToRef(v.center, {facing,1}, workVec21), ownerPos)
        else
            f[k2] = v[k2]
        end
    end
    table.insert(fr, f)
  end
  for k,v in next, itemForceRegions do
    local f = {}
    for k2,v2 in next, v do
        if k2 == "rectRegion" then
            f.rectRegion = {v.rectRegion[1]*facing + mePos[1],v.rectRegion[2] + mePos[2],v.rectRegion[3]*facing + mePos[1],v.rectRegion[4] + mePos[2]}
            if facing == -1 then
                local p = f.rectRegion[1]
                f.rectRegion[1] = f.rectRegion[3]
                f.rectRegion[3] = p
            end
        elseif k2 == "polyRegion" then
            local p = v.polyRegion
            if facing == -1 then
                p = poly.flip(p)
            end
            f.polyRegion = poly.translate(p, mePos)
        elseif k2 == "center" then
            f.center = vec2.add(vec2.mulToRef(v.center, {facing,1}, workVec21), mePos)
        else
            f[k2] = v[k2]
        end
    end
    table.insert(fr, f)
  end
  monster.setPhysicsForces(fr)
  animator.rotateTransformationGroup("arm_weapon",mcontroller.rotation())
  animator.scaleTransformationGroup("arm_weapon",{facing,1})
  if storage.item.count <= 0 and autoDestroy then
    destroy()
  end
end
function absoluteHandRotation()
  local facing = scriptTables.mcontroller.facingDirection()
  if facing > 0 then
    return mcontroller.rotation()
  else
    return math.pi-mcontroller.rotation()
  end
end
function setAimPosition(pos)
  aimPosition = pos
end
function updateMoves(m)
  moves = m
end
function setFire(mode, shiftHeld)
    if fireMode ~= mode then
      fireMode = mode
      if mode ~= "none" then
        if itemScript.activate then
          itemScript.activate(fireMode, shiftHeld)
        end
      end
    end
    isShiftHeld = shiftHeld
end

function interact(args)
end
function destroy()
    doDie = true
end

function shouldDie()
    return dieTimer < 0 or doDie or not world.entityExists(ownerId)
end
function uninit()
  if itemScript and itemScript.uninit then
    itemScript.uninit()
  end
end
function die()
end
