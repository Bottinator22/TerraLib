require "/scripts/terra_scriptLoader.lua"

inventorySlots = {}
local function equals(o1, o2, ignore_mt)
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
local function tfind(org, findValue)
    for key,value in pairs(org) do
        if value == findValue then
            return key
        end
    end
    return nil
end
function inventorySlots.swapItem(name)
    -- TODO: make this better
    local neededTag = nil
    local neededType = nil
    if widget.getData(name) then
        neededTag = widget.getData(name).needTag
        neededType = widget.getData(name).needType
    end
    local origItem = widget.itemSlotItem(name)
    local swapItem = player.swapSlotItem()
    local finish = not neededTag and not neededType
    if not swapItem then
        finish = true
    elseif neededType then
        if root.itemType(swapItem.name) == neededType then
            finish = true
        end
    elseif neededTag then
        local cfg = root.itemConfig(swapItem.name).config
        local tags = cfg.itemTags
        if tags then
            for k,v in next, tags do
                if v == neededTag then
                    finish = true
                end
            end
        end
    end
    if not finish then
        return
    end
    
    if origItem and swapItem then
        local limit = root.itemConfig(swapItem.name).config.maxStack or 1000
        if equals(swapItem.parameters, origItem.parameters) and swapItem.count + origItem.count <= limit and origItem.name == swapItem.name then
            swapItem.count = swapItem.count + origItem.count
            origItem = nil
        end
    end
    player.setSwapSlotItem(origItem)
    widget.setItemSlotItem(name, swapItem)
    if itemUpdate then itemUpdate() end
end
function inventorySlots.swapItemRight(name) 
    local origItem = widget.itemSlotItem(name)
    local swapItem = player.swapSlotItem()
    if swapItem then -- check if this is an augment
        local swapConfig = root.itemConfig(swapItem)
        if not swapItem.name then
            swapItem = {name=swapItem,count=1,parameters={}}
        end
        local scripts = swapConfig.config.scripts
        if scripts then
            -- define config for the augment
            local itemConfig = {}
            function itemConfig.getParameter(param, default)
                local val = swapConfig.parameters[param] or swapConfig.config[param]
                return val or default
            end
            
            -- define item for the augment
            -- why would you want to use all of these in an augment?
            -- TODO: switch to better sandbox on oSB
            local itemTable = {}
            function itemTable.name()
                return swapItem.name
            end
            function itemTable.count()
                return swapItem.count or 1
            end
            function itemTable.setCount(n)
                swapItem.count = n
            end
            function itemTable.maxStack()
                return itemConfig.getParameter("maxStack",1000)
            end
            function itemTable.matches(other)
                if other.name then
                    return swapItem.name == other.name and equals(swapItem.parameters, other.parameters)
                else
                    for k,v in next, swapItem.parameters do
                        return false
                    end
                    return swapItem.name == other
                end
            end
            function itemTable.consume(n)
                swapItem.count = swapItem.count - n
            end
            function itemTable.empty()
                return swapItem.count <= 0
            end
            function itemTable.descriptor()
                return swapItem
            end
            function itemTable.description()
                return itemConfig.getParameter("description","")
            end
            function itemTable.friendlyName()
                return itemConfig.getParameter("shortdescription","")
            end
            function itemTable.rarity()
                return tfind({"common","uncommon","rare","legendary","essential"},itemConfig.getParameter("rarity","common"))-1
            end
            function itemTable.rarityString()
                return itemConfig.getParameter("rarity","common")
            end
            function itemTable.price()
                return itemConfig.getParameter("price",0)
            end
            function itemTable.fuelAmount()
                return itemConfig.getParameter("fuelAmount",0)
            end
            function itemTable.iconDrawables()
                return {}
            end
            function itemTable.dropDrawables()
                return {}
            end
            function itemTable.largeImage()
                return itemConfig.getParameter("largeImage",nil)
            end
            function itemTable.tooltipKind()
                return itemConfig.getParameter("tooltipKind","baseaugment")
            end
            function itemTable.category()
                return itemConfig.getParameter("category","generic")
            end
            function itemTable.pickupSound()
                return itemConfig.getParameter("pickupSound","/sfx/interface/item_pickup.ogg")
            end
            function itemTable.twoHanded()
                return itemConfig.getParameter("twoHanded",false)
            end
            function itemTable.timeToLive()
                return itemConfig.getParameter("timeToLive",300.0)
            end
            function itemTable.hasItemTag(tag)
                return tfind(itemConfig.getParameter("tags",{}), tag) ~= nil
            end
            function itemTable.pickupQuestTemplates()
                return {}
            end
            
            local funcs = scriptLoader.loadMultiple(scripts, {config=itemConfig,item=itemTable}, {}, {"apply"})
            if funcs.apply then
                local output, i = funcs.apply(origItem)
                if i == nil then
                    i = 1
                end
                if output then
                    widget.setItemSlotItem(name, output)
                    if swapItem.count and swapItem.count > i then
                        swapItem.count = swapItem.count - i
                        player.setSwapSlotItem(swapItem)
                    else
                        player.setSwapSlotItem(nil)
                    end
                    origItem = nil
                    if itemUpdate then itemUpdate() end
                end
            end
        end
    end
    if not origItem then
        return
    end
    if swapItem then
        local limit = root.itemConfig(swapItem.name).config.maxStack or 1000
         if swapItem.count >= limit then
            return
         end
    end
    if not swapItem or swapItem.name == origItem.name and equals(swapItem.parameters, origItem.parameters) then
        if swapItem then
            swapItem.count = swapItem.count + 1
            player.setSwapSlotItem(swapItem)
        else
            player.setSwapSlotItem({name=origItem.name, count=1, parameters=origItem.parameters})
        end
        origItem.count = origItem.count - 1
        if origItem.count == 0 then
            origItem = nil
        end
        widget.setItemSlotItem(name, origItem)
        if itemUpdate then itemUpdate() end
    end
end
