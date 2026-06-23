require "TimedActions/ISBaseTimedAction"
require "CJSWeaponConditionMerge"

CJSWeaponConditionMergeAction = ISBaseTimedAction:derive("CJSWeaponConditionMergeAction")

function CJSWeaponConditionMergeAction:isValid()
    if not self.targetID or not self.donorID or self.targetID == self.donorID then
        return false
    end

    local inventory = self.character:getInventory()
    return inventory:containsID(self.targetID) and inventory:containsID(self.donorID)
end

function CJSWeaponConditionMergeAction:update()
    if self.target then
        self.target:setJobDelta(self:getJobDelta())
    end

    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function CJSWeaponConditionMergeAction:start()
    local inventory = self.character:getInventory()
    self.target = inventory:getItemById(self.targetID) or self.target
    self.donor = inventory:getItemById(self.donorID) or self.donor

    if self.target then
        self.target:setJobType("Merging weapon")
        self.target:setJobDelta(0.0)
    end

    self:setActionAnim("Loot")
    self:setOverrideHandModels(self.target, self.donor)
    self.character:reportEvent("EventLootItem")
end

function CJSWeaponConditionMergeAction:stop()
    if self.target then
        self.target:setJobDelta(0.0)
    end

    ISBaseTimedAction.stop(self)
end

function CJSWeaponConditionMergeAction:complete()
    local inventory = self.character:getInventory()
    self.target = inventory:getItemById(self.targetID) or self.target
    self.donor = inventory:getItemById(self.donorID) or self.donor

    return CJSWeaponConditionMerge.merge(self.character, self.target, self.donor)
end

function CJSWeaponConditionMergeAction:perform()
    if self.target then
        self.target:setJobDelta(0.0)
    end

    ISBaseTimedAction.perform(self)
end

function CJSWeaponConditionMergeAction:new(character, target, donor)
    local o = ISBaseTimedAction.new(self, character)
    o.target = target
    o.donor = donor
    o.targetID = target and target:getID()
    o.donorID = donor and donor:getID()
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = CJSWeaponConditionMerge.mergeDuration()

    if character:isTimedActionInstant() then
        o.maxTime = 1
    end

    return o
end
