-- Utility script to allow running clientside-only localanimation contexts. 
-- Useful for porting cases where local animation scripts give important information.
-- Other players cannot see what this renders. It is client master only.

require "/scripts/terra_scriptLoader.lua"
require "/scripts/terra_proxy.lua" -- since this is TerraLib's deployment script, also expose localAnimator

local oldInit = init
local oldUpdate = update
local offscreenSpace = 10
local generics = {}
local nonentities = {}
local bsmt = getmetatable''
local function entityKey(e)
    return string.format("entity_%d",e)
end
function table.clear(t)
    local l = #t
    for i=1,l do rawset(t,i,nil) end
end
local function doGenericContext(ent)
    local key = entityKey(ent)
    if generics[key] then
        return
    end
    if world.callScriptedEntity(ent, "config.getParameter", "ownerAnimationScripts") then
        world.callScriptedEntity(ent, "require", "/scripts/player/terra_clientmasterrenderer_hook.lua")
        local tables = world.callScriptedEntity(ent, "terra_generic_hook",key)
        -- todo: particles
        local env={}
        local drawables = {}
        local lights = {}
        tables.self = {}
        tables.localAnimator = {
            playAudio=localAnimator.playAudio,
            spawnParticle=localAnimator.spawnParticle,
            addDrawable=function(d,layer)
                table.insert(drawables, {drawable=d,layer=layer})
            end,
            clearDrawables=function()
                table.clear(drawables)
            end,
            addLightSource=function(l)
                table.insert(lights, {light=l})
            end,
            clearLightSources=function()
                table.clear(lights)
            end
        }
        local context=scriptLoader.loadMultiple(
            world.callScriptedEntity(ent, "config.getParameter", "ownerAnimationScripts"),
            tables,
            env,
            {"init","update","uninit"}
        )
        if context.init then
            context.init()
        end
        local m = {
            entity=ent,
            tables=tables,
            env=env,
            context=context,
            drawables=drawables,
            lights=lights
        }
        generics[key] = m
    end
end
function bsmt.terra_rendererGenericUninit(key)
    if generics[key].context.uninit then
        generics[key].context.uninit()
    end
end
function bsmt.terra_rendererNonEntityUninit(key)
    if nonentities[key].context.uninit then
        nonentities[key].context.uninit()
    end
    nonentities[key].dead = true
end
function bsmt.terra_rendererBuildItem(id,ent,oas,tables)
    -- todo: particles
    local env={}
    local drawables = {}
    local lights = {}
    tables.self = {}
    tables.localAnimator = {
        playAudio=localAnimator.playAudio,
        spawnParticle=localAnimator.spawnParticle,
        addDrawable=function(d,layer)
            table.insert(drawables, {drawable=d,layer=layer})
        end,
        clearDrawables=function()
            table.clear(drawables)
        end,
        addLightSource=function(l)
            table.insert(lights, {light=l})
        end,
        clearLightSources=function()
            table.clear(lights)
        end
    }
    local context=scriptLoader.loadMultiple(
        oas,
        tables,
        env,
        {"init","update","uninit"}
    )
    if context.init then
        context.init()
    end
    local m = {
        entity=ent,
        tables=tables,
        env=env,
        context=context,
        drawables=drawables,
        lights=lights,
        dead=false
    }
    nonentities[id] = m
end
function init()
    terra_proxy.setupReceiveMessages("localAnimator",localAnimator)
    oldInit()
end
local function worldToLocal(pos)
    return world.distance(pos, entity.position())
end
function updateContext(v)
    if v.context.update then
        v.context.update(dt)
    end
    for k,v in next, v.drawables do
        local drawable = sb.jsonMerge(v.drawable)
        if v.drawable.position then
            drawable.position = worldToLocal(v.drawable.position)
        elseif v.drawable.line then
            drawable.line[1] = worldToLocal(v.drawable.line[1])
            drawable.line[2] = worldToLocal(v.drawable.line[2])
        end
        localAnimator.addDrawable(drawable,v.layer)
    end
    for k,v in next, v.lights do
        local light = sb.jsonMerge(v.light)
        light.position = worldToLocal(v.light.position)
        localAnimator.addLightSource(light)
    end
end
function update(dt)
    localAnimator.clearDrawables()
    localAnimator.clearLightSources()
    oldUpdate(dt)
    local screenRect = world.clientWindow()
    local queryRect = {
        {screenRect[1] - offscreenSpace,screenRect[2] - offscreenSpace},
        {screenRect[3] + offscreenSpace,screenRect[4] + offscreenSpace}}
    for k,v in next, world.entityQuery(queryRect[1],queryRect[2],{includedTypes={"monster","vehicle"},callScript="type",callScriptArgs={"h"},callScriptResult="string"}) do
        doGenericContext(v)
    end
    local newgenerics = {}
    for k,v in next, generics do
        if world.entityExists(v.entity) then
            newgenerics[k] = v
            updateContext(v)
        end
    end
    generics = newgenerics
    local newnes = {}
    for k,v in next, nonentities do
        if not v.dead then
            newnes[k] = v
            updateContext(v)
        end
    end
    nonentities = newnes
end
