require "CJSWeaponConditionMerge"
require "TimedActions/ISInventoryTransferAction"
require "TimedActions/ISDropWorldItemAction"

if ISInventoryTransferAction and ISInventoryTransferAction.transferItem and
        not ISInventoryTransferAction.cjsWeaponConditionMergePatched then
    local originalTransferItem = ISInventoryTransferAction.transferItem

    function ISInventoryTransferAction:transferItem(item)
        local merge = CJSWeaponConditionMerge
        if merge and item then
            merge.persistItemTreeState(item)
        end

        local result = originalTransferItem(self, item)

        if merge and item then
            merge.persistItemTreeState(item)
        end

        return result
    end

    ISInventoryTransferAction.cjsWeaponConditionMergePatched = true
end

if ISDropWorldItemAction and ISDropWorldItemAction.complete and
        not ISDropWorldItemAction.cjsWeaponConditionMergePatched then
    local originalDropComplete = ISDropWorldItemAction.complete

    function ISDropWorldItemAction:complete()
        if CJSWeaponConditionMerge and self.item then
            CJSWeaponConditionMerge.persistItemTreeState(self.item)
        end

        local result = originalDropComplete(self)

        if CJSWeaponConditionMerge and self.item then
            CJSWeaponConditionMerge.persistItemTreeState(self.item)
        end

        return result
    end

    ISDropWorldItemAction.cjsWeaponConditionMergePatched = true
end
