require "CJSWeaponConditionMerge"
require "TimedActions/CJSWeaponConditionMergeAction"
require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISInventoryTransferAction"

local function selectedInventoryItem(value)
    if instanceof(value, "InventoryItem") then
        return value
    end

    if type(value) == "table" and value.items and value.items[1] then
        return value.items[1]
    end

    return nil
end

local function selectedMergeTarget(playerObj, items)
    for _, value in ipairs(items) do
        local item = selectedInventoryItem(value)
        if CJSWeaponConditionMerge.isMergeableWeapon(item) then
            return item
        end
    end

    return nil
end

local function donorLabel(donor)
    return string.format(
        "%s (%d/%d, %s)",
        donor:getDisplayName(),
        donor:getCondition(),
        donor:getConditionMax(),
        CJSWeaponConditionMerge.stackLabel(donor)
    )
end

local function transferIfNeeded(playerObj, item)
    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.transferIfNeeded then
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
        return
    end

    if luautils and luautils.haveToBeTransfered and luautils.haveToBeTransfered(playerObj, item) then
        ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, item, item:getContainer(), playerObj:getInventory()))
    end
end

local function queueMerge(playerObj, target, donor)
    transferIfNeeded(playerObj, target)
    transferIfNeeded(playerObj, donor)
    ISTimedActionQueue.add(CJSWeaponConditionMergeAction:new(playerObj, target, donor))
end

local function isUsableDonor(playerObj, target, donor)
    if not CJSWeaponConditionMerge.canMerge(target, donor) then
        return false
    end

    if donor:isFavorite() then
        return false
    end

    return not playerObj:isEquipped(donor)
end

local function matchingDonors(playerObj, target)
    local donors = {}
    local inventory = playerObj:getInventory()
    local items = inventory:getAllEvalRecurse(function(item)
        return isUsableDonor(playerObj, target, item)
    end, ArrayList.new())

    for index = 0, items:size() - 1 do
        table.insert(donors, items:get(index))
    end

    table.sort(donors, function(left, right)
        if left:getFullType() ~= right:getFullType() then
            return left:getFullType() < right:getFullType()
        end

        if left:getConditionMax() ~= right:getConditionMax() then
            return left:getConditionMax() > right:getConditionMax()
        end

        return left:getCondition() > right:getCondition()
    end)

    return donors
end

local function onFillInventoryObjectContextMenu(playerIndex, context, items)
    local playerObj = getSpecificPlayer(playerIndex)
    if not playerObj then return end

    local target = selectedMergeTarget(playerObj, items)
    if not target then return end

    local donors = matchingDonors(playerObj, target)
    if #donors == 0 then return end

    local rootOption = context:addOption("Merge Weapon Condition")
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(rootOption, subMenu)

    for _, donor in ipairs(donors) do
        subMenu:addOption(donorLabel(donor), playerObj, queueMerge, target, donor)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
