require "/scripts/vec2.lua"

structureRenderer = {}
local partsRendered = 0
function structureRenderer.prepareStructure(structure)
    local parts = {}
    partsRendered = 0
    function safeAccess(t,y,x)
        if t[y] then
            return t[y][x]
        end
        return nil
    end
    for y,row in next, structure.background do
        for x,block in next, row do
            if block then
                local neighbors = {
                    {safeAccess(structure.background,y-1,x-1)==block,safeAccess(structure.background,y-1,x)==block,safeAccess(structure.background,y-1,x+1)==block},
                    {row[x - 1] == block, true, row[x + 1] == block},
                    {safeAccess(structure.background,y+1,x-1)==block,safeAccess(structure.background,y+1,x)==block,safeAccess(structure.background,y+1,x+1)==block}
                }
                local pos = {x - #row/2, y-#row/2}
                local renderableBlock = {
                    block=root.materialConfig(block),
                    pos=pos
                }
                local newParts = structureRenderer.prepareBlock(renderableBlock, neighbors)
                for k,v in next, newParts do
                    table.insert(parts, v)
                end
            end
        end
    end
    for y,row in next, structure.foreground do
        for x,block in next, row do
            if block then
                local neighbors = {
                    {safeAccess(structure.foreground,y-1,x-1)==block,safeAccess(structure.foreground,y-1,x)==block,safeAccess(structure.foreground,y-1,x+1)==block},
                    {row[x - 1] == block, true, row[x + 1] == block},
                    {safeAccess(structure.foreground,y+1,x-1)==block,safeAccess(structure.foreground,y+1,x)==block,safeAccess(structure.foreground,y+1,x+1)==block}
                }
                if structure.background then
                    local shadows = {
                        {safeAccess(structure.background,y-1,x-1)==block,safeAccess(structure.background,y-1,x)==block,safeAccess(structure.background,y+1,x+1)==block},
                        {safeAccess(structure.background,y  ,x-1)==block,safeAccess(structure.background,y  ,x)==block,safeAccess(structure.background,y  ,x+1)==block},
                        {safeAccess(structure.background,y+1,x-1)==block,safeAccess(structure.background,y+1,x)==block,safeAccess(structure.background,y-1,x+1)==block}
                    }
                else
                    shadows = {}
                end
                local pos = {x - #row/2, y-#row/2}
                local renderableBlock = {
                    block=root.materialConfig(block),
                    pos=pos
                }
                local newParts = structureRenderer.prepareBlock(renderableBlock, neighbors, shadows)
                for k,v in next, newParts do
                    table.insert(parts, v)
                end
            end
        end
    end
    structure.parts = parts
    return structure
end
function structureRenderer.prepareStructureTemplate(structure, templates)
    -- the blocks in the structure are meant to be keys from a table provided later
    local templateT = {}
    partsRendered = 0
    function safeAccess(t,y,x)
        if t[y] then
            return t[y][x]
        end
        return nil
    end
    for y,row in next, structure.background do
        for x,block in next, row do
            if block then
                local neighbors = {
                    {safeAccess(structure.background,y-1,x-1)==block,safeAccess(structure.background,y-1,x)==block,safeAccess(structure.background,y-1,x+1)==block},
                    {row[x - 1] == block, true, row[x + 1] == block},
                    {safeAccess(structure.background,y+1,x-1)==block,safeAccess(structure.background,y+1,x)==block,safeAccess(structure.background,y+1,x+1)==block}
                }
                local pos = {x - #row/2, y-#row/2}
                local renderableBlock = {
                    templates=templates,
                    key=block,
                    pos=pos
                }
                local o = {}
                o[template] = structureRenderer.prepareBlockTemplate(renderableBlock, neighbors)
                table.insert(templateT, o)
            end
        end
    end
    for y,row in next, structure.foreground do
        for x,block in next, row do
            if block then
                local neighbors = {
                    {safeAccess(structure.foreground,y-1,x-1)==block,safeAccess(structure.foreground,y-1,x)==block,safeAccess(structure.foreground,y-1,x+1)==block},
                    {row[x - 1] == block, true, row[x + 1] == block},
                    {safeAccess(structure.foreground,y+1,x-1)==block,safeAccess(structure.foreground,y+1,x)==block,safeAccess(structure.foreground,y+1,x+1)==block}
                }
                local shadows = {
                    {safeAccess(structure.background,y-1,x-1)==block,safeAccess(structure.background,y-1,x)==block,safeAccess(structure.background,y+1,x+1)==block},
                    {safeAccess(structure.background,y  ,x-1)==block,safeAccess(structure.background,y  ,x)==block,safeAccess(structure.background,y  ,x+1)==block},
                    {safeAccess(structure.background,y+1,x-1)==block,safeAccess(structure.background,y+1,x)==block,safeAccess(structure.background,y-1,x+1)==block}
                }
                local pos = {x - #row/2, y-#row/2}
                local renderableBlock = {
                    templates=templates,
                    key=block,
                    pos=pos
                }
                table.insert(templateT, structureRenderer.prepareBlockTemplate(renderableBlock, neighbors, shadows))
            end
        end
    end
    return {template=templateT,source=structure}
end
function structureRenderer.prepareStructureFromTemplate(blocks, tmpl, bConfigs)
    local output = {}
    if not bConfigs then
        bConfigs = {}
        for k,v in next, blocks do
            table.insert(bConfigs, root.materialConfig(v))
        end
    end
    for k,v in next, tmpl.template do
        local drawables = structureRenderer.prepareBlockFromTemplate(bConfigs[v.key],v)
    end
    return output
end
function structureRenderer.getTemplate(mat)
    local templateFile = root.materialConfig(block).config.renderTemplate
    return templateFile
end
function structureRenderer.prepareBlock(block, neighbors, shadows)
    local template = root.assetJson(block.block.config.renderTemplate)
    local params = block.block.config.renderParameters
    local rules = template.rules
    local parts = {}
    local partOffsets = {}
    function processMatch(m)
        if m.matchAllPoints then
            for k,v in next, m.matchAllPoints do
                local rule = template.rules[v[2]]
                for k,e in next, rule.entries do
                    local matchTable = neighbors
                    local matchNot = false
                    if e.type == "Shadows" then
                        matchTable = shadows
                    end
                    if e.inverse then
                        matchNot = true
                    end
                    if not matchTable then
                        return
                    end
                    if not ((not matchNot and matchTable[v[1][2] + 2][v[1][1] + 2]) or (matchNot and not matchTable[v[1][2] + 2][v[1][1] + 2])) then
                        return
                    end
                end
            end
        end
        if m.pieces then
            for k,v in next, m.pieces do
                table.insert(parts, template.pieces[v[1]])
                table.insert(partOffsets, v[2])
            end
        end
        if m.subMatches then
            for k,v in next, m.subMatches do
                processMatch(v)
            end
        end
    end
    for k,v in next, template.matches do
        for k,m in next, v[2] do
            processMatch(m)
        end
    end
    local output = {}
    for k,v in next, parts do
        local newPart = {}
        newPart.pos = vec2.add(vec2.add(vec2.div(partOffsets[k], 8), block.pos), {-1,-1})
        local texturePos = v.texturePosition
        if params.variants then
            local variant = math.random(0,params.variants-1)
            texturePos = vec2.add(texturePos, vec2.mul(v.variantStride, variant))
        end
        local texture = (v.texture or block.block.path:match("(.*/)")..params.texture)
        local imageSize = root.imageSize(texture)
        newPart.image = texture..string.format("?crop=%s;%s;%s;%s", texturePos[1],imageSize[2]-(texturePos[2]+v.textureSize[2]),texturePos[1]+v.textureSize[1],imageSize[2]-texturePos[2])
        local zLevel = params.zLevel
        if not shadows then
            zLevel = params.zLevel - 32767
            newPart.image = newPart.image.."?multiply=7F7F7FFF"
        end
        local layer = "Vehicle+"..zLevel
        if zLevel < 0 then
            layer="Vehicle-"..math.abs(zLevel)
        end
        newPart.layer = layer
        table.insert(output, newPart)
    end
    return output
end
function structureRenderer.prepareBlockTemplate(block, neighbors, shadows)
    local output = {isBackground=not shadows,pos=block.pos,key=block.key}
    for k,v in next, block.templates do
        local template = root.assetJson(v)
        local rules = template.rules
        local parts = {}
        local partOffsets = {}
        function processMatch(m)
            if m.matchAllPoints then
                for k,v in next, m.matchAllPoints do
                    local rule = template.rules[v[2]]
                    for k,e in next, rule.entries do
                        local matchTable = neighbors
                        local matchNot = false
                        if e.type == "Shadows" then
                            matchTable = shadows
                        end
                        if e.inverse then
                            matchNot = true
                        end
                        if not matchTable then
                            return
                        end
                        if not ((not matchNot and matchTable[v[1][2] + 2][v[1][1] + 2]) or (matchNot and not matchTable[v[1][2] + 2][v[1][1] + 2])) then
                            return
                        end
                    end
                end
            end
            if m.pieces then
                for k,v in next, m.pieces do
                    table.insert(parts, template.pieces[v[1]])
                    table.insert(partOffsets, v[2])
                end
            end
            if m.subMatches then
                for k,v in next, m.subMatches do
                    local halt = processMatch(v)
                    if m.haltOnSubMatch and (halt or k==#m.subMatches) then
                        return true
                    end
                    if halt then
                        break
                    end
                end
            end
            if m.haltOnMatch then
                return true
            end
        end
        for k,v in next, template.matches do
            for k,m in next, v[2] do
                local halt = processMatch(m)
                if halt then
                    break
                end
            end
        end
        output[v] = parts
    end
    return output
end
function structureRenderer.prepareBlockFromTemplate(mConfig, tmpl)
    local params = mConfig.config.renderParameters
    local output = {}
    for k,v in next, tmpl[mConfig.config.renderTemplate] do
        local newPart = {}
        newPart.pos = vec2.add(vec2.add(vec2.div(partOffsets[k], 8), tmpl.pos), {-1,-1})
        local texturePos = v.texturePosition
        if params.variants then
            local variant = math.random(0,params.variants-1)
            texturePos = vec2.add(texturePos, vec2.mul(v.variantStride, variant))
        end
        local texture = (v.texture or mConfig.path:match("(.*/)")..params.texture)
        local imageSize = root.imageSize(texture)
        newPart.image = texture..string.format("?crop=%s;%s;%s;%s", texturePos[1],imageSize[2]-(texturePos[2]+v.textureSize[2]),texturePos[1]+v.textureSize[1],imageSize[2]-texturePos[2])
        local zLevel = params.zLevel
        if tmpl.isBackground then
            zLevel = params.zLevel - 32767
            newPart.image = newPart.image.."?multiply=7F7F7FFF"
        end
        local layer = "Vehicle+"..zLevel
        if zLevel < 0 then
            layer="Vehicle-"..math.abs(zLevel)
        end
        newPart.layer = layer
        table.insert(output, newPart)
    end
    return output
end
-- to be run every frame. supports moving structures. prepareStructure must be called again if the structure changes.
function structureRenderer.renderStructure(structure)
    if not structure.parts then
        structureRenderer.prepareStructure(structure)
    end
    local centerPos = structure.pos
    local rot = structure.rot
    for k,v in next, structure.parts do
        local pos = vec2.add(vec2.rotate(v.pos, rot), centerPos)
        local drawable = {image=string.format("%s%s",v.image,structure.directives), position=pos, rotation=rot, centered=false}
        localAnimator.addDrawable(drawable, v.layer)
    end
end

-- must be run before renderStructureStatic if the structure moves or its directives change
function structureRenderer.prepareStructureStatic(structure)
    if not structure.parts then
        structureRenderer.prepareStructure(structure)
    end
    structure.drawables = {}
    local centerPos = structure.pos
    local rot = structure.rot
    for k,v in next, structure.parts do
        local pos = vec2.add(vec2.rotate(v.pos, rot), centerPos)
        local drawable = {image=string.format("%s%s",v.image,structure.directives), position=pos, rotation=rot, centered=false, layer=v.layer}
        table.insert(structure.drawables,drawable)
    end
end
-- can be run every frame, should be faster than renderStructure especially for non-moving stuff
function structureRenderer.renderStructureStatic(structure)
    if not structure.drawables then
        structureRenderer.prepareStructureStatic(structure)
    end
    for k,v in next, structure.drawables do
        localAnimator.addDrawable(v, v.layer)
    end
end
