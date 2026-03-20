require "/scripts/poly.lua"
require "/scripts/vec2.lua"

local function linePointBefore(p,a,b)
  -- is a before b on the line?
  -- expects both points to be on the same line and for them both to be ON THE LINE
  local i = 1
  if a[1] == p[1] then
    i = 2
  end
  if a[i] > p[i] then
    return a[i] < b[i]
  else
    return a[i] > b[i]
  end
end
local function inPhysCategory(c)
  local cat = "player"
  if c.categoryWhitelist then
    for k,v in next, c.categoryWhitelist do
      return true
    end
    return false
  elseif c.categoryBlacklist then
    for k,v in next, c.categoryBlacklist do
      if v == cat then
        return false
      end
    end
    return true
  end
end
local kindsWhitelist = {
  Slippery=true,
  Platform=true,
  Dynamic=true,
  Block=true
}
function refVelocity(a,b)
  local p = world.lineCollision(a,b,{"Slippery","Platform","Dynamic","Block"})
  local pent = nil
  if not world.entity then
    return {0,0}
  end
  -- for 'poly within' check, doesn't actually matter where this is
  local po = {0,-1000}
  local kinds2 = kindsWhitelist
  local es = world.entityLineQuery(a,b,{includedTypes={"projectile","object","vehicle"},boundMode="metaboundbox"})
  for _,id in next, es do
    local e = world.entity(id)
    for i=e:movingCollisionCount()-1,0,-1 do
      local c = e:movingCollision(i)
      if c and kinds2[c.collisionKind] then
        if inPhysCategory(c.categoryFilter) then
          local withinI = 0
          local cpol = poly.translate(c.collision,c.position)
          world.debugPoly(cpol,"red")
          for i=1,#cpol do
            local ca = cpol[i]
            local cb = cpol[i+1] or cpol[1]
            local inters = vec2.intersect(a,b,ca,cb)
            if inters and (not p or linePointBefore(a,inters,p)) then
              p = inters
              pent = e
            end
            if vec2.intersect(a,po,ca,cb) then
              withinI = withinI + 1
            end
          end
          if withinI & 1 > 0 then -- line from a to po, if it crossed an odd number of lines this means a is within this poly
            return e:velocity() or {0,0}
          end
        end
      end
    end
  end
  if pent then
    return pent:velocity() or {0,0}
  else
    return {0,0}
  end
end 
