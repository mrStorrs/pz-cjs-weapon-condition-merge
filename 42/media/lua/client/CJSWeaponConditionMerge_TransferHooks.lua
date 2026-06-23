require "CJSWeaponConditionMerge"
require "TimedActions/ISInventoryTransferAction"
require "TimedActions/ISDropItemAction"

local function isCharacterInventoryContainer(container, character)
    if not container or not character or not container.isInCharacterInventory then
        return false
    end

    return container:isInCharacterInventory(character)
end

if ISInventoryTransferAction and ISInventoryTransferAction.transferItem and
        not ISInventoryTransferAction.cjsWeaponConditionMergePatched then
    local originalTransferItem = ISInventoryTransferAction.transferItem

    function ISInventoryTransferAction:transferItem(item)
        local merge = CJSWeaponConditionMerge
        if merge and item then
            if isCharacterInventoryContainer(self.srcContainer, self.character) then
                merge.persistItemTreeState(item)
            else
                merge.restoreItemTreeState(self.character, item)
            end
        end

        local result = originalTransferItem(self, item)

        if merge and item then
            if isCharacterInventoryContainer(self.destContainer, self.character) then
                merge.restoreItemTreeState(self.character, item)
            else
                merge.persistItemTreeState(item)
            end
        end

        return result
    end

    ISInventoryTransferAction.cjsWeaponConditionMergePatched = true
end

if ISDropItemAction and ISDropItemAction.perform and not ISDropItemAction.cjsWeaponConditionMergePatched then
    local originalDropPerform = ISDropItemAction.perform

    function ISDropItemAction:perform()
        if CJSWeaponConditionMerge and self.item then
            CJSWeaponConditionMerge.persistItemTreeState(self.item)
        end

        return originalDropPerform(self)
    end

    ISDropItemAction.cjsWeaponConditionMergePatched = true
end
