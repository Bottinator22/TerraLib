function init()
end

function applyDamageRequest(damageRequest)
  local ownerId = status.statusProperty("ownerId")
  if ownerId then
    world.callScriptedEntity(ownerId,"status.applySelfDamageRequest",damageRequest)
  else
    return {}
  end
  local owner = world.entity(ownerId)
  if world.getProperty("nonCombat") then
    return {}
  end
  if world.getProperty("invinciblePlayers") then
    return {}
  end
  
  if damageRequest.damageType == "Knockback" then
    return {}
  end

  local damage = 0
  if damageRequest.damageType == "Damage" or damageRequest.damageType == "Knockback" then
    damage = damage + damageRequest.damage*(1-owner:stat("protection")/100)
  elseif damageRequest.damageType == "IgnoresDef" then
    damage = damage + damageRequest.damage
  elseif damageRequest.damageType == "Status" then
    return {}
  elseif damageRequest.damageType == "Environment" then
    return {}
  end
  
  damage = math.max(0,damage-owner:stat("earthmoverDamageReduction"))

  local hitType = damageRequest.hitType
  local elementalStat = root.elementalResistance(damageRequest.damageSourceKind)
  local resistance = owner:stat(elementalStat)
  damage = damage - (resistance * damage)
  if resistance ~= 0 and damage > 0 then
    hitType = resistance > 0 and "weakhit" or "stronghit"
  end

  local healthLost = math.min(damage, owner:resource("health"))
  
  return {{
    sourceEntityId = damageRequest.sourceEntityId,
    targetEntityId = entity.id(),
    position = mcontroller.position(),
    damageDealt = damage,
    healthLost = healthLost,
    hitType = hitType,
    kind = "Normal",
    damageSourceKind = damageRequest.damageSourceKind,
    targetMaterialKind = owner:statusProperty("targetMaterialKind")
  }}
end

function notifyResourceConsumed(resourceName, amount)
end

function update(dt)
end
 
