local MOD_ID = "cjsWeaponConditionMerge"

local DATA_KEYS = {
    stacks = "cjsWcmStacks",
    baseName = "cjsWcmBaseName",
    baseMinDamage = "cjsWcmBaseMinDamage",
    baseMaxDamage = "cjsWcmBaseMaxDamage",
    condition = "cjsWcmCondition",
    conditionMax = "cjsWcmConditionMax",
    headCondition = "cjsWcmHeadCondition",
    headConditionMax = "cjsWcmHeadConditionMax",
}

local DEFAULTS = {
    ConditionMultiplier = 1.0,
    DamagePercentPerStack = 1.0,
    MergeDuration = 60,
}

local FIREARM_PART_TYPES = {
    "Scope",
    "Canon",
    "Sling",
    "Stock",
    "Recoilpad",
    "RecoilPad",
    "Clip",
}

local CROSS_TYPE_DONORS = {
    ["LTW.LegendaryTacticalSword"] = {
        ["Base.Sword"] = true,
    },
    ["LTW.LegendaryTacticalTomahawk"] = {
        ["Base.HandAxe"] = true,
    },
    ["LTW.LegendaryTacticalAxe"] = {
        ["Base.Axe"] = true,
    },
    ["LTW.LegendaryTacticalCrowbar"] = {
        ["Base.Crowbar"] = true,
    },
    ["LTW.LegendaryTacticalBat"] = {
        ["Base.BaseballBat_Metal"] = true,
    },
    ["LTW.LegendaryTacticalHammer"] = {
        ["Base.BallPeenHammer"] = true,
    },
    ["LTW.LegendaryTacticalKnife"] = {
        ["Base.FightingKnife"] = true,
    },
    ["LTW.LegendaryTacticalSledgehammer"] = {
        ["Base.Sledgehammer"] = true,
    },
    ["LTW.LegendaryTacticalSpear"] = {
        ["Base.SpearLargeKnife"] = true,
    },
    ["MoreTraits.AntiqueAxe"] = {
        ["Base.AxeStone"] = true,
    },
    ["MoreTraits.Thumper"] = {
        ["Base.StoneMaul"] = true,
    },
    ["MoreTraits.ObsidianBlade"] = {
        ["Base.StoneKnifeLong"] = true,
        ["Base.FlintKnife"] = true,
    },
    ["MoreTraits.BloodyCrowbar"] = {
        ["Base.Crowbar"] = true,
        ["Base.CrowbarForged"] = true,
    },
    ["MoreTraits.Slugger"] = {
        ["Base.BaseballBat_Metal"] = true,
    },
    ["MoreTraits.AntiqueSpear"] = {
        ["Base.SpearCrafted"] = true,
        ["Base.SpearCraftedFireHardened"] = true,
    },
    ["MoreTraits.AntiqueHammer"] = {
        ["Base.ClubHammer"] = true,
        ["Base.ClubHammerForged"] = true,
        ["Base.SmithingHammer"] = true,
    },
    ["MoreTraits.AntiqueKatana"] = {
        ["Base.Katana"] = true,
    },
}

local M = {}
local loggedWarnings = {}

local function warnOnce(message)
    if loggedWarnings[message] then
        return
    end

    loggedWarnings[message] = true
    if print then
        print("[" .. MOD_ID .. "] " .. tostring(message))
    end
end

local function sandboxOption(key)
    local vars = SandboxVars and SandboxVars.CJSWeaponConditionMerge
    if vars and vars[key] ~= nil then
        return vars[key]
    end

    return DEFAULTS[key]
end

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function round(value)
    return math.floor(value + 0.5)
end

local function nearlyEqual(left, right)
    return math.abs((left or 0) - (right or 0)) < 0.0001
end

local function parseStackedName(name)
    if not name then return nil, nil end

    local baseName, stackText = tostring(name):match("^(.-)%s+(%d+)x$")
    if not baseName or baseName == "" then
        return tostring(name), nil
    end

    local stacks = tonumber(stackText)
    if not stacks or stacks < 1 then
        return tostring(name), nil
    end

    return baseName, math.floor(stacks)
end

local function displayName(item)
    if item and item.getDisplayName then
        return item:getDisplayName()
    end

    return "Weapon"
end

local function modData(item)
    if not item or not item.getModData then return nil end
    return item:getModData()
end

local function currentStacks(item)
    local data = modData(item)
    local storedStacks = data and tonumber(data[DATA_KEYS.stacks])
    if storedStacks and storedStacks >= 1 then
        return math.floor(storedStacks)
    end

    local _, parsedStacks = parseStackedName(displayName(item))
    return parsedStacks or 1
end

local function baseName(item)
    local data = modData(item)
    if data and data[DATA_KEYS.baseName] and data[DATA_KEYS.baseName] ~= "" then
        return data[DATA_KEYS.baseName]
    end

    local externalName = M.externalBaseName and M.externalBaseName(item) or nil
    local parsedName = parseStackedName(externalName or displayName(item))
    local name = parsedName or externalName or displayName(item)

    if data then
        data[DATA_KEYS.baseName] = name
    end

    return name
end

local function baseMinDamage(item)
    local data = modData(item)
    if data and tonumber(data[DATA_KEYS.baseMinDamage]) then
        return tonumber(data[DATA_KEYS.baseMinDamage])
    end

    local value = item:getMinDamage()
    if data then
        data[DATA_KEYS.baseMinDamage] = value
    end

    return value
end

local function baseMaxDamage(item)
    local data = modData(item)
    if data and tonumber(data[DATA_KEYS.baseMaxDamage]) then
        return tonumber(data[DATA_KEYS.baseMaxDamage])
    end

    local value = item:getMaxDamage()
    if data then
        data[DATA_KEYS.baseMaxDamage] = value
    end

    return value
end

local function scriptConditionMax(item)
    local scriptItem = item and item.getScriptItem and item:getScriptItem()
    if scriptItem and scriptItem.getConditionMax then
        local ok, value = pcall(function()
            return scriptItem:getConditionMax()
        end)

        if ok and tonumber(value) then
            return tonumber(value)
        end
    end

    return item and item.getConditionMax and item:getConditionMax() or 0
end

local function safeMethodValue(item, methodName, ...)
    if not item or not item[methodName] then
        return nil
    end

    local ok, value = pcall(item[methodName], item, ...)
    if ok then
        return value
    end

    return nil
end

local function hasHeadCondition(item)
    return item and item:hasHeadCondition() == true
end

local function headCondition(item)
    if not hasHeadCondition(item) then
        return 0
    end

    return item:getHeadCondition()
end

local function headConditionMax(item)
    if not hasHeadCondition(item) then
        return 0
    end

    return item:getHeadConditionMax()
end

local function setHeadConditionMax(item, conditionMax)
    if not hasHeadCondition(item) then
        return false
    end

    conditionMax = round(conditionMax)
    if conditionMax < 1 then
        conditionMax = 1
    end

    if headConditionMax(item) == conditionMax then
        return false
    end

    if not Attribute or not Attribute.HeadConditionMax then
        warnOnce("Unable to update HeadConditionMax; merged head condition may clamp to the old maximum")
        return false
    end

    local attributes = item:getAttributes()
    if not attributes then
        warnOnce("Unable to update HeadConditionMax; item has no attribute container")
        return false
    end

    local ok, result = pcall(function()
        return attributes:putFromScript(Attribute.HeadConditionMax, tostring(conditionMax))
    end)
    if not ok then
        warnOnce("Unable to update HeadConditionMax: " .. tostring(result))
        return false
    end

    if result == false then
        warnOnce("Unable to update HeadConditionMax; attribute rejected value " .. tostring(conditionMax))
        return false
    end

    return true
end

local function setHeadCondition(item, condition)
    if not hasHeadCondition(item) then
        return false
    end

    condition = round(condition)
    if condition < 0 then
        condition = 0
    end

    if headCondition(item) == condition then
        return false
    end

    local ok, err = pcall(function()
        item:setHeadCondition(condition)
    end)
    if not ok then
        warnOnce("Unable to update HeadCondition: " .. tostring(err))
        return false
    end

    return true
end

local function hasAmmoCapacity(item)
    local maxAmmo = tonumber(safeMethodValue(item, "getMaxAmmo"))
    if maxAmmo and maxAmmo > 0 then
        return true
    end

    return safeMethodValue(item, "getAmmoType") ~= nil
        or safeMethodValue(item, "getMagazineType") ~= nil
end

local function hasLoadedAmmo(item)
    local ammoCount = tonumber(safeMethodValue(item, "getCurrentAmmoCount")) or 0
    if ammoCount > 0 then
        return true
    end

    return safeMethodValue(item, "isRoundChambered") == true
        or safeMethodValue(item, "isContainsClip") == true
end

local function hasAttachedWeaponParts(item)
    if not item then
        return false
    end

    if item.getWeaponPart then
        for _, partType in ipairs(FIREARM_PART_TYPES) do
            if safeMethodValue(item, "getWeaponPart", partType) ~= nil then
                return true
            end
        end
    end

    return safeMethodValue(item, "getScope") ~= nil
        or safeMethodValue(item, "getCanon") ~= nil
        or safeMethodValue(item, "getSling") ~= nil
        or safeMethodValue(item, "getStock") ~= nil
        or safeMethodValue(item, "getRecoilpad") ~= nil
        or safeMethodValue(item, "getClip") ~= nil
end

local function syncWeapon(character, weapon)
    if character and syncHandWeaponFields then
        syncHandWeaponFields(character, weapon)
    end

    if character and syncItemFields then
        syncItemFields(character, weapon)
    elseif weapon and weapon.syncItemFields then
        weapon:syncItemFields()
    end
end

local function persistConditionState(item, conditionMax, condition, conditionHeadMax, conditionHead)
    local data = modData(item)
    if not data then return end

    data[DATA_KEYS.conditionMax] = conditionMax or item:getConditionMax()
    data[DATA_KEYS.condition] = condition or item:getCondition()

    if hasHeadCondition(item) then
        data[DATA_KEYS.headConditionMax] = conditionHeadMax or headConditionMax(item)
        data[DATA_KEYS.headCondition] = conditionHead or headCondition(item)
    else
        data[DATA_KEYS.headConditionMax] = nil
        data[DATA_KEYS.headCondition] = nil
    end
end

local function storedConditionMax(item, data, stacks)
    local storedMax = tonumber(data[DATA_KEYS.conditionMax])
    if storedMax and storedMax >= 1 then
        return round(storedMax)
    end

    local baseMax = scriptConditionMax(item)
    if stacks > 1 and baseMax > 0 then
        return round(baseMax * stacks)
    end

    return nil
end

local function storedCondition(item, data, targetMax)
    local currentMax = item:getConditionMax()
    local currentCondition = clamp(item:getCondition(), 0, targetMax)

    if currentMax == targetMax then
        return currentCondition
    end

    local storedValue = tonumber(data[DATA_KEYS.condition])
    if storedValue and storedValue >= 0 then
        return clamp(round(storedValue), 0, targetMax)
    end

    if currentMax > 0 and targetMax > currentMax then
        return clamp(round((currentCondition / currentMax) * targetMax), 0, targetMax)
    end

    return currentCondition
end

local function liveCondition(sourceCondition, sourceConditionMax, targetMax)
    local currentMax = tonumber(sourceConditionMax) or targetMax
    local currentCondition = tonumber(sourceCondition) or 0

    if currentMax > 0 then
        currentCondition = clamp(currentCondition, 0, currentMax)

        if currentMax ~= targetMax then
            return clamp(round((currentCondition / currentMax) * targetMax), 0, targetMax)
        end
    end

    return clamp(round(currentCondition), 0, targetMax)
end

local function storedHeadConditionMax(item, data)
    if not hasHeadCondition(item) then
        return nil
    end

    local storedMax = tonumber(data[DATA_KEYS.headConditionMax])
    if storedMax and storedMax >= 1 then
        return round(storedMax)
    end

    return nil
end

local function storedHeadCondition(item, data, targetMax)
    if not targetMax then
        return nil
    end

    local currentMax = headConditionMax(item)
    local currentCondition = clamp(headCondition(item), 0, targetMax)

    if currentMax == targetMax then
        return currentCondition
    end

    local storedValue = tonumber(data[DATA_KEYS.headCondition])
    if storedValue and storedValue >= 0 then
        return clamp(round(storedValue), 0, targetMax)
    end

    if currentMax > 0 and targetMax > currentMax then
        return clamp(round((currentCondition / currentMax) * targetMax), 0, targetMax)
    end

    return currentCondition
end

local function applyHeadConditionState(item, targetHeadMax, targetHeadCondition)
    if not targetHeadMax or not targetHeadCondition or not hasHeadCondition(item) then
        return false
    end

    targetHeadMax = round(targetHeadMax)
    if targetHeadMax < 1 then
        targetHeadMax = 1
    end

    targetHeadCondition = clamp(round(targetHeadCondition), 0, targetHeadMax)
    local changed = false

    if setHeadConditionMax(item, targetHeadMax) then
        changed = true
    end

    if setHeadCondition(item, targetHeadCondition) then
        changed = true
    end

    return changed
end

local function applyDamage(item, stacks)
    local damageFactor = 1.0 + ((stacks - 1) * (M.damagePercentPerStack() / 100.0))
    local newMinDamage = baseMinDamage(item) * damageFactor
    local newMaxDamage = baseMaxDamage(item) * damageFactor
    local changed = false

    if not nearlyEqual(item:getMinDamage(), newMinDamage) then
        item:setMinDamage(newMinDamage)
        changed = true
    end

    if not nearlyEqual(item:getMaxDamage(), newMaxDamage) then
        item:setMaxDamage(newMaxDamage)
        changed = true
    end

    return changed
end

local function applyItemState(character, item, data, stacks, targetMax, targetCondition, targetHeadMax, targetHeadCondition)
    local changed = false

    if targetHeadCondition and targetHeadCondition <= 0 then
        targetCondition = 0
    end

    if item:getConditionMax() ~= targetMax then
        item:setConditionMax(targetMax)
        changed = true
    end

    if item:getCondition() ~= targetCondition then
        item:setConditionNoSound(targetCondition)
        changed = true
    end

    if targetCondition > 0 and item.setBroken and item:isBroken() then
        item:setBroken(false)
        changed = true
    end

    if applyHeadConditionState(item, targetHeadMax, targetHeadCondition) then
        changed = true
    end

    if data[DATA_KEYS.stacks] ~= stacks then
        data[DATA_KEYS.stacks] = stacks
    end

    data[DATA_KEYS.baseName] = baseName(item)

    local expectedName = M.stackedDisplayName(item)
    if displayName(item) ~= expectedName then
        item:setName(expectedName)
        changed = true
    end

    if applyDamage(item, stacks) then
        changed = true
    end

    persistConditionState(item, targetMax, targetCondition, targetHeadMax, targetHeadCondition)

    if changed then
        syncWeapon(character, item)
    end

    return changed
end

function M.conditionMultiplier()
    return clamp(tonumber(sandboxOption("ConditionMultiplier")) or DEFAULTS.ConditionMultiplier, 0.1, 100.0)
end

function M.damagePercentPerStack()
    return clamp(tonumber(sandboxOption("DamagePercentPerStack")) or DEFAULTS.DamagePercentPerStack, 0.0, 100.0)
end

function M.mergeDuration()
    local value = tonumber(sandboxOption("MergeDuration")) or DEFAULTS.MergeDuration
    return clamp(math.floor(value), 1, 600)
end

function M.stackCount(item)
    return currentStacks(item)
end

function M.stackLabel(item)
    return tostring(currentStacks(item)) .. "x"
end

function M.stackedDisplayName(item)
    return baseName(item) .. " " .. M.stackLabel(item)
end

function M.isFirearm(item)
    if not item or not instanceof or not instanceof(item, "HandWeapon") then
        return false
    end

    if safeMethodValue(item, "isRanged") == true then
        return true
    end

    return hasAmmoCapacity(item)
end

function M.isMergeableWeapon(item)
    if not item or not instanceof or not instanceof(item, "HandWeapon") then
        return false
    end

    return item:getConditionMax() > 0
end

function M.isSafeMergeDonor(item)
    if not M.isMergeableWeapon(item) then
        return false
    end

    if not M.isFirearm(item) then
        return true
    end

    return not hasLoadedAmmo(item) and not hasAttachedWeaponParts(item)
end

function M.areMergeTypesCompatible(targetFullType, donorFullType)
    if targetFullType == donorFullType then
        return true
    end

    local allowedDonors = CROSS_TYPE_DONORS[targetFullType]
    return allowedDonors ~= nil and allowedDonors[donorFullType] == true
end

function M.canMerge(target, donor)
    if not M.isMergeableWeapon(target) or not M.isMergeableWeapon(donor) then
        return false
    end

    if target == donor or target:getID() == donor:getID() then
        return false
    end

    return M.areMergeTypesCompatible(target:getFullType(), donor:getFullType())
        and M.isSafeMergeDonor(donor)
end

function M.isStackedWeapon(item)
    return M.isMergeableWeapon(item) and currentStacks(item) > 1
end

function M.persistItemState(item)
    if not M.isStackedWeapon(item) then
        return
    end

    if M.beforePersistItemState and M.beforePersistItemState(item) then
        return
    end

    persistConditionState(item)

    if M.afterPersistItemState then
        M.afterPersistItemState(item)
    end
end

function M.restoreItemState(character, item)
    if not M.isStackedWeapon(item) then
        return false
    end

    if M.beforeRestoreItemState and M.beforeRestoreItemState(character, item) then
        return true
    end

    local data = modData(item)
    if not data then
        return false
    end

    local stacks = currentStacks(item)
    local targetMax = storedConditionMax(item, data, stacks)
    if not targetMax then
        return false
    end

    local targetCondition = storedCondition(item, data, targetMax)
    local targetHeadMax = storedHeadConditionMax(item, data)
    local targetHeadCondition = storedHeadCondition(item, data, targetHeadMax)
    local changed = applyItemState(character, item, data, stacks, targetMax, targetCondition, targetHeadMax, targetHeadCondition)

    if M.afterRestoreItemState then
        M.afterRestoreItemState(character, item, changed)
    end

    return changed
end

function M.refreshItemState(character, item, sourceCondition, sourceConditionMax, sourceHeadCondition, sourceHeadConditionMax)
    if not M.isStackedWeapon(item) then
        return false
    end

    local data = modData(item)
    if not data then
        return false
    end

    local stacks = currentStacks(item)
    local targetMax = storedConditionMax(item, data, stacks)
    if not targetMax then
        return false
    end

    local currentCondition = sourceCondition or item:getCondition()
    local currentMax = sourceConditionMax or item:getConditionMax()
    local targetCondition = liveCondition(currentCondition, currentMax, targetMax)
    local targetHeadMax = storedHeadConditionMax(item, data)
    local targetHeadCondition = storedHeadCondition(item, data, targetHeadMax)

    if targetHeadMax then
        local currentHeadCondition = sourceHeadCondition or headCondition(item)
        local currentHeadMax = sourceHeadConditionMax or headConditionMax(item)
        targetHeadCondition = liveCondition(currentHeadCondition, currentHeadMax, targetHeadMax)
    end

    return applyItemState(character, item, data, stacks, targetMax, targetCondition, targetHeadMax, targetHeadCondition)
end

function M.eachStackedContainerItem(container, callback)
    if not container or not container.getAllEvalRecurse or not ArrayList then return end

    local items = container:getAllEvalRecurse(function(item)
        return M.isStackedWeapon(item)
    end, ArrayList.new())

    for index = 0, items:size() - 1 do
        callback(items:get(index))
    end
end

function M.eachStackedItemTree(item, callback)
    if not item then return end

    if M.isStackedWeapon(item) then
        callback(item)
    end

    local inventory = item.getInventory and item:getInventory()
    if inventory then
        M.eachStackedContainerItem(inventory, callback)
    end
end

function M.eachStackedInventoryItem(player, callback)
    if not player or not player.getInventory then return end

    M.eachStackedContainerItem(player:getInventory(), callback)
end

function M.restoreInventory(player)
    M.eachStackedInventoryItem(player, function(item)
        M.restoreItemState(player, item)
    end)
end

function M.persistInventory(player)
    M.eachStackedInventoryItem(player, function(item)
        M.persistItemState(item)
    end)
end

function M.restoreItemTreeState(character, item)
    M.eachStackedItemTree(item, function(stackedItem)
        M.restoreItemState(character, stackedItem)
    end)
end

function M.persistItemTreeState(item)
    M.eachStackedItemTree(item, function(stackedItem)
        M.persistItemState(stackedItem)
    end)
end

function M.merge(character, target, donor)
    if not M.canMerge(target, donor) then
        return false
    end

    local targetStacks = currentStacks(target)
    local donorStacks = currentStacks(donor)
    local newStacks = targetStacks + donorStacks
    local conditionMultiplier = M.conditionMultiplier()

    local newCondition = round(target:getCondition() + (donor:getCondition() * conditionMultiplier))
    local newMaxCondition = newCondition
    local newHeadCondition = nil
    local newMaxHeadCondition = nil

    if hasHeadCondition(target) and hasHeadCondition(donor) then
        newHeadCondition = round(headCondition(target) + (headCondition(donor) * conditionMultiplier))
        newMaxHeadCondition = newHeadCondition

        if newHeadCondition <= 0 then
            newCondition = 0
            newMaxCondition = 1
        end

        if newMaxHeadCondition < 1 then
            newMaxHeadCondition = 1
        end
    end

    if newMaxCondition < 1 then
        newMaxCondition = 1
    end

    target:setConditionMax(newMaxCondition)
    target:setConditionNoSound(newCondition)

    if newCondition > 0 and target.setBroken then
        target:setBroken(false)
    end

    applyHeadConditionState(target, newMaxHeadCondition, newHeadCondition)

    applyDamage(target, newStacks)

    local data = modData(target)
    if data then
        data[DATA_KEYS.stacks] = newStacks
        data[DATA_KEYS.baseName] = baseName(target)
    end

    persistConditionState(target, newMaxCondition, newCondition, newMaxHeadCondition, newHeadCondition)

    target:setName(M.stackedDisplayName(target))

    if M.afterMerge then
        M.afterMerge(character, target, donor)
    end

    target:applyMaxSharpness()

    syncWeapon(character, target)

    local donorContainer = donor:getContainer()
    if donorContainer then
        donorContainer:DoRemoveItem(donor)
        donorContainer:setDrawDirty(true)
    end

    return true
end

function M.describeMerge(target, donor)
    local stacks = currentStacks(target) + currentStacks(donor)
    return displayName(donor) .. " -> " .. tostring(stacks) .. "x"
end

function M.debugName()
    return MOD_ID
end

CJSWeaponConditionMerge = M

local function forEachPlayer(callback)
    if not getSpecificPlayer then return end

    if getNumActivePlayers then
        for playerIndex = 0, getNumActivePlayers() - 1 do
            callback(getSpecificPlayer(playerIndex))
        end
        return
    end

    callback(getSpecificPlayer(0))
end

local loadRestoreScansRemaining = 120

local function restoreAllPlayers()
    forEachPlayer(function(player)
        M.restoreInventory(player)
    end)
end

local function persistAllPlayers()
    forEachPlayer(function(player)
        M.persistInventory(player)
    end)
end

local function onCreatePlayer(playerIndex, player)
    M.restoreInventory(player or (getSpecificPlayer and getSpecificPlayer(playerIndex or 0)))
end

local function onLoadRestorePlayerUpdate(player)
    if loadRestoreScansRemaining <= 0 then
        Events.OnPlayerUpdate.Remove(onLoadRestorePlayerUpdate)
        return
    end

    loadRestoreScansRemaining = loadRestoreScansRemaining - 1
    M.restoreInventory(player)
end

local function persistEquippedWeapon(weapon, seen)
    if not M.isStackedWeapon(weapon) then
        return
    end

    local key = tostring(weapon:getID())
    if seen[key] then
        return
    end

    seen[key] = true
    M.persistItemState(weapon)
end

local function persistEquippedWeapons(player)
    if not player then
        return
    end

    local seen = {}

    persistEquippedWeapon(player:getPrimaryHandItem(), seen)
    persistEquippedWeapon(player:getSecondaryHandItem(), seen)
end

local function onPlayerUpdate(player)
    persistEquippedWeapons(player)
end

local function persistWeapon(weapon)
    M.persistItemState(weapon)
end

local function onHitZombie(_zombie, _wielder, _bodyPart, weapon)
    persistWeapon(weapon)
end

local function onWeaponHitCharacter(_wielder, _target, weapon, _damage)
    persistWeapon(weapon)
end

local function onWeaponHitThumpable(_character, weapon, _object)
    persistWeapon(weapon)
end

local function onWeaponHitTree(_owner, weapon)
    persistWeapon(weapon)
end

local function onPlayerAttackFinished(_player, weapon)
    persistWeapon(weapon)
end

local function addEvent(event, handler)
    if event and event.Add then
        event.Add(handler)
    end
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(restoreAllPlayers)
end

if Events and Events.OnCreatePlayer then
    Events.OnCreatePlayer.Add(onCreatePlayer)
end

if Events and Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(onLoadRestorePlayerUpdate)
    Events.OnPlayerUpdate.Add(onPlayerUpdate)
end

if Events and Events.OnSave then
    Events.OnSave.Add(persistAllPlayers)
end

if Events then
    addEvent(Events.OnHitZombie, onHitZombie)
    addEvent(Events.OnWeaponHitCharacter, onWeaponHitCharacter)
    addEvent(Events.OnWeaponHitThumpable, onWeaponHitThumpable)
    addEvent(Events.OnWeaponHitTree, onWeaponHitTree)
    addEvent(Events.OnPlayerAttackFinished, onPlayerAttackFinished)
end
