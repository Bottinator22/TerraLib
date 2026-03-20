require "/scripts/terra_vec2ref.lua"
require "/scripts/poly.lua"
require "/scripts/rect.lua"

local collisionScanCategory
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
    local cat = collisionScanCategory
    if c.categoryWhitelist then
        for k,v in next, c.categoryWhitelist do
            if v == cat then
                return true
            end
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
local function entityKey(e)
    return string.format("e_%d",e)
end

local collisionScanClass = {}
local collisionScanClassMT = {__index=collisionScanClass}

local defaultKindsWhitelist = {
  Null=true,
  Slippery=true,
  Dynamic=true,
  Block=true
}
function setCollisionScanCategory(cat)
    collisionScanCategory = cat
end
function collisionScan(a,b,kinds)
    if not collisionScanCategory then
        setCollisionScanCategory(entity.entityType())
    end
    -- allows for several line collisions in the space between a and b
    -- far more efficient than just doing repeated line collision checks of the same nature
    local kindsWhitelist = defaultKindsWhitelist
    if kinds then
        if #kinds == 0 then
            kindsWhitelist = kinds
        else
            kindsWhitelist = {}
            for k,v in next, kinds do
                kindsWhitelist[v] = true
            end
        end
    end
    local scan
    if world.entity then
        local queryConfig = {
                includedTypes={"object","projectile","vehicle"},
                boundMode="metaboundbox"
            }
        local wwidth = world.size()[1]
        scan = {
            entities={},
            collisions={},
            refPos=a, -- TODO: maybe find the center or something?
            kinds=kinds
        }
        if a[1] < 0 or b[1] > wwidth then
            local ents = {}
            --[[
            local a1 = world.xwrap(a)
            local b1 = {wwidth,b[2]}
            local a2 = {0,a[2]}
            local b2 = world.xwrap(b)
            world.debugPoly({a1,{a1[1],b1[2]},b1,{b1[1],a1[2]}},"cyan")
            world.debugPoly({a2,{a2[1],b2[2]},b2,{b2[1],a2[2]}},"cyan")
            ]]
            for _,v in next, world.entityQuery(world.xwrap(a),{wwidth,b[2]},queryConfig) do
                ents[entityKey(v)] = v
            end
            for _,v in next, world.entityQuery({0,a[2]},world.xwrap(b),queryConfig) do
                ents[entityKey(v)] = v
            end
            for k,v in next, ents do
                table.insert(scan.entities,v)
            end
        else
            scan.entities = world.entityQuery(a,b,queryConfig)
        end
        if kindsWhitelist == kinds then
            scan.kinds = {}
            for k,v in next, kindsWhitelist do
                if v then
                    table.insert(scan.kinds,k)
                end
            end
        end
        for _,e in next,scan.entities do
            local ed = world.entity(e)
            for i=ed:movingCollisionCount()-1,0,-1 do
                local coll = ed:movingCollision(i)
                if coll and kindsWhitelist[coll.collisionKind] then
                    if inPhysCategory(coll.categoryFilter) then
                        coll.translatedCollision = poly.translate(coll.collision,coll.position)
                        coll.translatedCollisionRelative = poly.translate(coll.collision,world.distance(coll.position,scan.refPos))
                        coll.boundBox = poly.boundBox(coll.translatedCollision)
                        coll.boundBoxRelative = poly.boundBox(coll.translatedCollisionRelative)
                        coll.entity = ed
                        coll.index = i
                        table.insert(scan.collisions,coll)
                    end
                end
            end
        end
    else
        scan = {}
    end
    setmetatable(scan,collisionScanClassMT)
    return scan
end
function collisionScanClass.lineCollisionInfo(self,a,b)
    -- TODO: this seems to be rarely failing with a few polies, and ignoring the first line
    --world.debugLine(a,b,"green")
    local p = world.lineCollision(a,b,self.kinds)
    if not world.entity then
        if p then
            return "world",p
        else
            return nil
        end
    end
    local rp = p and world.distance(p,self.refPos)
    local ra = world.distance(a,self.refPos)
    local rb = world.distance(b,self.refPos)
    local minx = math.min(ra[1],rb[1])
    local maxx = math.max(ra[1],rb[1])
    local miny = math.min(ra[2],rb[2])
    local maxy = math.max(ra[2],rb[2])
    local lineRect = {minx,miny,maxx,maxy}
    local closestCollision = nil
    -- for 'poly within' check, doesn't actually matter where this is as long as it's far away
    local po = world.distance({0,-1000},self.refPos)
    for _,c in next, self.collisions do
        local withinI = 0
        local bb = c.boundBoxRelative
        if rect.intersects(bb,lineRect) then
            local cpol = c.translatedCollisionRelative
            --world.debugPoly(cpol,"red")
            for i=1,#cpol do
                local ca = cpol[i]
                local cb = cpol[i+1] or cpol[1]
                local inters = vec2.intersect(ra,rb,ca,cb)
                if inters and (not p or linePointBefore(ra,inters,rp)) then
                    rp = inters
                    p = vec2.add(inters,self.refPos)
                    closestCollision = c
                end
                if vec2.intersect(ra,po,ca,cb) then
                    withinI = withinI + 1
                end
            end
            if withinI & 1 > 0 then -- line from a to po, if it crossed an odd number of lines this means a is within this poly
                return "entity",a,c
            end
        end
    end
    if closestCollision then
        return "entity",p,closestCollision
    elseif p then
        return "world",p
    else
        return nil
    end
end 
