require "/scripts/terra_structureRenderer.lua"

local allTemplates = {}
function init()
    local last = getmetatable''.terra_structures or {}
    local c = root.assetJson("/terra_structures.config")
    allTemplates = c.allBlockTemplates
    -- both of these loading methods only support 1 block type; to add more, I'll need to improve the way this is handled to include colours
    -- or just allow direct block loading
    local structures = {}
    for k,v in next, c.structures do
        if last[k] and not v.reloadAnyway then
            goto continue
        end
        v.structures = loadImageToStructure(v.structures, v.image, v.frames, v.block)
        structures[k]=v.structures
        ::continue::
    end
    getmetatable''.terra_structures = structures
    local templates = {}
    for k,v in next, c.templates do
        if last[k] and not v.reloadAnyway then
            goto continue
        end
        v.templates = loadImageToTemplate(v.templates, v.image, v.frames)
        templates[k]=v.templates
        ::continue::
    end
    getmetatable''.terra_templates = templates
end
function update()
    if getmetatable''.terra_reloadStructures then
        getmetatable''.terra_structures = nil
        getmetatable''.terra_templates = nil
        init()
        getmetatable''.terra_reloadStructures = false
    end
end
function loadImageToStructure(structures, image, frames, block)
    local size = {0,0}
    if not frames then
        frames = {"main"}
        size = root.imageSize(image)
    else
        size = root.imageSize(image..":"..frames[1])
    end
    for k,v in next, frames do
        local frame = image..":"..v
        if v == "main" then
            frame = image
        end
        local t = {}
        for x=1,size[1] do
            local t2 = {}
            for y=1,size[2] do
                local pixel = frame..string.format("?crop=%s;%s;%s;%s",x-1,y-1,x,y)
                local region = root.nonEmptyRegion(pixel)
                table.insert(t2, not not region)
            end
            table.insert(t, t2)
        end
        structures[v] = t
    end
    for k,t in next, structures do
        for k,t2 in next, t do
            for k,v in next, t2 do
                if v then
                    t2[k] = block
                end
            end
        end
    end
    for k,t in next, structures do
        if k ~= "background" then
            local structure = {
                foreground=t,
                background=structures.background or {}
            }
            structures[k]=structureRenderer.prepareStructure(structure)
        end
    end
    if structures["main"] then
        structures = structures["main"]
    end
    return structures
end
function loadImageToTemplate(templates, image, frames)
    local size = {0,0}
    if not frames then
        frames = {"main"}
        size = root.imageSize(image)
    else
        size = root.imageSize(image..":"..frames[1])
    end
    for k,v in next, frames do
        local frame = image..":"..v
        if v == "main" then
            frame = image
        end
        local t = {}
        for x=1,size[1] do
            local t2 = {}
            for y=1,size[2] do
                local pixel = frame..string.format("?crop=%s;%s;%s;%s",x-1,y-1,x,y)
                local region = root.nonEmptyRegion(pixel)
                table.insert(t2, not not region)
            end
            table.insert(t, t2)
        end
        templates[v] = t
    end
    for k,t in next, templates do
        for k,t2 in next, t do
            for k,v in next, t2 do
                if v then
                    t2[k] = 1
                end
            end
        end
    end
    for k,t in next, templates do
        if k ~= "background" then
            local template = {
                foreground=t,
                background=templates.background or {}
            }
            templates[k]=structureRenderer.prepareStructureTemplate(template, allTemplates)
        end
    end
    if templates["main"] then
        templates = templates["main"]
    end
    return templates
end
