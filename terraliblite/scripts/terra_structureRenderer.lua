require "/scripts/vec2.lua"

structureRenderer = {}
local structureObj = {}
local configCache = {}
local function cachedAssetJson(p)
    if not configCache[p] then
        configCache[p] = root.assetJson(p)
    end
    return configCache[p]
end
local sizeCache = {}
local function cachedImageSize(p)
    if not sizeCache[p] then
        sizeCache[p] = root.imageSize(p)
    end
    return sizeCache[p]
end
local matConfigCache = {}
local nullMatConfig = {}
local nullMatTemplate = {}
local function cachedMatConfig(t)
    if not t then
        return nullMatConfig
    elseif not matConfigCache[t] then
        matConfigCache[t] = root.materialConfig(t)
    end
    return matConfigCache[t]
end
local matIdCache = {}
local function cachedMatId(t)
    -- doesn't work with metamaterials
    if not t then
        return 65535
    elseif not matIdCache[t] then
        local cfg = cachedMatConfig(t)
        if not cfg then
            -- this is a metamaterial
            -- just give it the boundary id for now
            -- make a proper metamaterial id list later
            matIdCache[t] = 65526
        else
            matIdCache[t] = cfg.materialId
        end
    end
    return matIdCache[t]
end
local partsRendered = 0
local function blockKey(x,y)
    return string.format("x%dy%d",x,y)
end
structureRenderer.blockKey = blockKey
-- block data structure:
--[[
    {
        block: what block this is. this is also used to 
        pos: where this block is
        hueshift: block hueshift
        color: block paint colour index (TODO: implement)
    }
]]
local structureMT = {__index=structureObj}
function structureRenderer.createStructure(params)
    local obj = {
        foreground={},
        directives=params.baseDirectives or "",
        pos=params.pos or {0,0},
        linkToWorld=params.connectToWorld,
        seed=params.seed or 45289375,
        
        lastDirectives=nil,
        dirtyTiles=true,
        lastPosition={0,0}
    }
    if params.includeBackground then
        obj.background = {}
    end
    setmetatable(obj,structureMT)
end
-- sets the metatable and returns
-- if existing structure provided, uses its checksum
-- this is probably unreliable, but it's way faster than checking everything constantly.
-- also links to the existing instance
function structureRenderer.fromStored(obj,existing)
    if not existing then
        setmetatable(obj,structureMT)
        return obj
    else
        if not existing.checksum then
            existing:generateChecksum()
        end
        if existing.checksum ~= obj.checksum then
            setmetatable(obj,structureMT)
            return obj
        end
    end
    return existing
end
local checksumMax = 2^32
local function checksumStr(str)
    local h = 0
    for c in string.gmatch(str,".") do
        h = (h + string.byte(c)) % checksumMax
    end
    return h
end
function structureObj.generateChecksum(structure)
    local checksum = structure.seed
    if structure.background then
        checksum = checksum * 2
    end
    if structure.linkToWorld then
        checksum = checksum * 3
    end
    checksum = (checksum + structure.pos[1])
    checksum = (checksum + structure.pos[2]) % checksumMax
    checksum = (checksum + checksumStr(structure.directives)) % checksumMax
    if structure.background then
        for k,v in next, structure.background do
            checksum = ((checksum * cachedMatId(v.block)) % checksumMax + v.pos[1] + v.pos[2]) % checksumMax -- position values are expected to be integers!
        end
    end
    for k,v in next, structure.foreground do
        checksum = ((checksum * cachedMatId(v.block)) % checksumMax + v.pos[1] + v.pos[2]) % checksumMax -- position values are expected to be integers!
    end
    structure.checksum = checksum
    return checksum
end
-- pos should not be used after this
function structureObj.setTile(structure,pos,layer,block,hueshift)
    local tm = structure.foreground
    if layer == "background" then
        tm = structure.background
        if not tm then
            -- this structure doesn't have a background!
            return
        end
    end
    structure.dirtyTiles = true
    if block then
        tm[blockKey(pos[1],pos[2])] = {
            pos=pos,
            block=block,
            hueshift=hueshift
        }
    else
        tm[blockKey(pos[1],pos[2])] = nil
    end
end
function structureObj.anyTiles(structure)
    if structure.background then
        if next(structure.background) then
            return true
        end
    end
    if next(structure.foreground) then
        return true
    end
    return false
end
function structureObj.prepare(structure)
    math.randomseed(structure.seed)
    local parts = {}
    partsRendered = 0
    if structure.background then
        for _,block in next, structure.background do
            local newParts = structure:prepareBlock(block, true, structure.background)
            for k,v in next, newParts do
                table.insert(parts, v)
            end
        end
    end
    for _,block in next, structure.foreground do
        local newParts = structure:prepareBlock(block, false, structure.foreground)
        for k,v in next, newParts do
            table.insert(parts, v)
        end
    end
    structure.parts = parts
    if structure.checksum then
        structure:generateChecksum()
    end
    return structure
end
local function getTemplate(mat)
    if not mat then
        return nullMatTemplate
    end
    local templateFile = cachedMatConfig(mat).config.renderTemplate
    return cachedAssetJson(templateFile)
end
local nonConnectableMaterials = {
    -- world.material returns false on metamaterial:null and metamaterial:empty
    ["metamaterial:boundary"]=true
}
local matchFuncs = {
    Empty = function(entry,block,t,h) -- templates can't actually use this but I'm defining it anyway just in case oSB makes it useable or something
        return not t
    end,
    Connects = function(entry,block,t,h)
        return t and not nonConnectableMaterials[t]
    end,
    Shadows = function(entry,block,t,h)
        if not t then
            return false
        end
        local template = getTemplate(t)
        if template.lightTransparent == nil then
            return not template.foregroundLightTransparent
        else
            return not template.lightTransparent
        end
    end,
    EqualsSelf = function(entry,block,t,h)
        return t == block.block and (not entry.matchHue or (block.hueshift or 0) == h)
    end,
    EqualsId = function(entry,block,t,h)
        return cachedMatId(t) == entry.id
    end,
    PropertyEquals = function(entry,block,t)
        if not t then
            return false
        end
        local tl = getTemplate(t)
        if not tl.ruleProperties then
            return false
        end
        return tl.ruleProperties[entry.propertyName] == entry.propertyValue
    end
}
local matchUseBackground = {
    Shadows=true
}
local nullMap = {}
-- TODO: allow structures to link to others... somehow
function structureObj.prepareBlock(structure, block, background, blocks)
    local blockcfg = cachedMatConfig(block.block)
    local template = cachedAssetJson(blockcfg.config.renderTemplate)
    local params = blockcfg.config.renderParameters
    local rules = template.rules
    local output = {}
    local matchMap = {}
    function processMatch(m)
        if m.matchAllPoints then
            for k,v in next, m.matchAllPoints do
                local rule = rules[v[2]]
                for k,e in next, rule.entries do
                    local matchFrom = blocks
                    local matchNot = false
                    local noMatch = false
                    local matLayer = "foreground"
                    if background then
                        matLayer = "background"
                    end
                    if e.type == "Shadows" then
                        if not background then
                            noMatch = true
                        else
                            matLayer = "foreground"
                        end
                    end
                    if noMatch then -- only present for shadows so
                        if not e.inverse then
                            return
                        end
                    else
                        local tile = matchFrom[blockKey(block.pos[1]+v[1][1],block.pos[2]+v[1][2])]
                        if structure.linkToWorld and not tile then
                            local worldPos = vec2.add(structure.pos,block.pos)
                            if matchFuncs[e.type](e,block,world.material(worldPos,matLayer),world.materialHueShift(worldPos,matLayer)) ~= e.inverse then
                                return
                            end
                        elseif tile then
                            if matchFuncs[e.type](e,block,tile.block,tile.hueshift) ~= e.inverse then
                                return
                            end
                        else
                            if matchFuncs[e.type](e,block,nil,nil) ~= e.inverse then
                                return
                            end
                        end
                    end
                end
            end
        end
        if m.pieces then
            for k,v in next, m.pieces do
                local piece = template.pieces[v[1]]
                local newPart = {}
                newPart.pos = vec2.add(vec2.mul(v[2], 0.125), block.pos)
                local texturePos = piece.texturePosition
                if params.variants then
                    local variant = math.random(0,params.variants-1)
                    texturePos = vec2.add(texturePos, vec2.mul(piece.variantStride, variant))
                end
                local texture = (piece.texture or block.block.path:match("(.*/)")..params.texture)
                local imageSize = cachedImageSize(texture)
                newPart.image = string.format(
                    "%s?crop=%d;%d;%d;%d",
                    texture,
                    texturePos[1],
                    imageSize[2]-(texturePos[2]+piece.textureSize[2]),
                    texturePos[1]+piece.textureSize[1],
                    imageSize[2]-texturePos[2]
                )
                if block.hueshift then
                    newPart.image = string.format("%s%.5f",newPart.image,block.hueshift)
                end
                local zLevel = params.zLevel
                local layer
                if background then
                    newPart.image = newPart.image.."?multiply=7F7F7FFF"
                    if zLevel == 0 then
                        layer="BackgroundTile"
                    elseif zLevel < 0 then
                        layer="BackgroundTile-"..-zLevel
                    else
                        layer="BackgroundTile+"..zLevel
                    end
                else
                    if zLevel == 0 then
                        layer="ForegroundTile"
                    elseif zLevel < 0 then
                        layer="ForegroundTile-"..-zLevel
                    else
                        layer="ForegroundTile+"..zLevel
                    end
                end
                newPart.layer = layer
                table.insert(output, newPart)
            end
        end
        if m.subMatches then
            if type(m.subMatches) == "string" then
                for k,v in next, matchMap[m.subMatches] do
                    processMatch(v)
                end
            else
                for k,v in next, m.subMatches do
                    processMatch(v)
                end
            end
        end
    end
    for _,v in next, template.matches do
        -- it's already json data, why did they make these an array of pairs instead of an object...
        matchMap[v[1]] = v[2]
    end
    for k,m in next, matchMap.main do
        processMatch(m)
    end
    return output
end

-- to be run every frame. supports moving structures. prepareStructure must be called again if the structure changes.
-- TODO: implement full transformation
function structureObj.render(structure)
    if structure.dirtyTiles or not structure.parts then
        structure:prepare()
    end
    local basePos = structure.pos
    for k,v in next, structure.parts do
        local pos = vec2.add(v.pos, basePos)
        local drawable = {image=string.format("%s%s",v.image,structure.directives), position=pos, centered=false}
        localAnimator.addDrawable(drawable, v.layer)
    end
end

-- must be run before renderStructureStatic if the structure moves or its directives change
-- does not support rotation. is expected to be grid-aligned, to work with linkToWorld.
function structureObj.prepareStatic(structure)
    if structure.dirtyTiles or not structure.parts then
        structure:prepare()
    elseif structure.checksum then
        structure:generateChecksum()
    end
    structure.lastPosition = {structure.pos[1],structure.pos[2]}
    structure.lastDirectives = structure.directives
    structure.drawables = {}
    local basePos = structure.pos
    for k,v in next, structure.parts do
        local pos = vec2.add(v.pos, basePos)
        local drawable = {image=string.format("%s%s",v.image,structure.directives), position=pos, centered=false, layer=v.layer}
        table.insert(structure.drawables,drawable)
    end
end
-- can be run every frame, should be faster than renderStructure especially for non-moving stuff
function structureObj.renderStatic(structure)
    if not structure.drawables or not vec2.eq(structure.lastPosition, structure.pos) or structure.directives ~= structure.lastDirectives then
        structure:prepareStatic()
    end
    for k,v in next, structure.drawables do
        localAnimator.addDrawable(v, v.layer)
    end
end

-- TODO: function to construct animation config from structure for some other stuff
