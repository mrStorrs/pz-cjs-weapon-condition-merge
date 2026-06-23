local MOD_ID = "cjsWeaponConditionMerge"

local DATA_KEYS = {
    stacks = "cjsWcmStacks",
    baseName = "cjsWcmBaseName",
    baseMinDamage = "cjsWcmBaseMinDamage",
    baseMaxDamage = "cjsWcmBaseMaxDamage",
    condition = "cjsWcmCondition",
    conditionMax = "cjsWcmConditionMax",
}

local DEFAULTS = {
    ConditionMultiplier = 1.0,
    DamagePercentPerStack = 1.0,
    MergeDuration = 60,
}

local M = {}

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

    local parsedName = parseStackedName(displayName(item))
    local name = parsedName or displayName(item)

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

local function syncWeapon(character, weapon)
    if syncHandWeaponFields then
        syncHandWeaponFields(character, weapon)
    end

    if syncItemFields then
        syncItemFields(character, weapon)
    elseif weapon and weapon.syncItemFields then
        weapon:syncItemFields()
    end
end

local function persistConditionState(item, conditionMax, condition)
    local data = modData(item)
    if not data then return end

    data[DATA_KEYS.conditionMax] = conditionMax or item:getConditionMax()
    data[DATA_KEYS.condition] = condition or item:getCondition()
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
    local storedValue = tonumber(data[DATA_KEYS.condition])
    if storedValue and storedValue >= 0 then
        return clamp(round(storedValue), 0, targetMax)
    end

    local currentMax = item:getConditionMax()
    if currentMax > 0 and targetMax > currentMax then
        return clamp(round((item:getCondition() / currentMax) * targetMax), 0, targetMax)
    end

    return clamp(item:getCondition(), 0, targetMax)
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

function M.isMergeableWeapon(item)
    if not item or not instanceof or not instanceof(item, "HandWeapon") then
        return false
    end

    if item.getMaxAmmo and item:getMaxAmmo() > 0 then
        return false
    end

    return item:getConditionMax() > 0
end

function M.canMerge(target, donor)
    if not M.isMergeableWeapon(target) or not M.isMergeableWeapon(donor) then
        return false
    end

    if target == donor or target:getID() == donor:getID() then
        return false
    end

    return target:getFullType() == donor:getFullType()
end

function M.isStackedWeapon(item)
    return M.isMergeableWeapon(item) and currentStacks(item) > 1
end

function M.persistItemState(item)
    if not M.isStackedWeapon(item) then
        return
    end

    persistConditionState(item)
end

function M.restoreItemState(character, item)
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

    local targetCondition = storedCondition(item, data, targetMax)
    local changed = false

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

    if data[DATA_KEYS.stacks] ~= stacks then
        data[DATA_KEYS.stacks] = stacks
    end

    data[DATA_KEYS.baseName] = baseName(item)

    local expectedName = baseName(item) .. " " .. tostring(stacks) .. "x"
    if displayName(item) ~= expectedName then
        item:setName(expectedName)
        changed = true
    end

    if applyDamage(item, stacks) then
        changed = true
    end

    persistConditionState(item, targetMax, targetCondition)

    if changed then
        syncWeapon(character, item)
    end

    return changed
end

function M.eachStackedInventoryItem(player, callback)
    if not player or not player.getInventory or not ArrayList then return end

    local inventory = player:getInventory()
    if not inventory or not inventory.getAllEvalRecurse then return end

    local items = inventory:getAllEvalRecurse(function(item)
        return M.isStackedWeapon(item)
    end, ArrayList.new())

    for index = 0, items:size() - 1 do
        callback(items:get(index))
    end
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

function M.merge(character, target, donor)
    if not M.canMerge(target, donor) then
        return false
    end

    local targetStacks = currentStacks(target)
    local donorStacks = currentStacks(donor)
    local newStacks = targetStacks + donorStacks
    local conditionMultiplier = M.conditionMultiplier()

    local newMaxCondition = round(target:getConditionMax() + (donor:getConditionMax() * conditionMultiplier))
    local newCondition = round(target:getCondition() + (donor:getCondition() * conditionMultiplier))

    if newMaxCondition < 1 then
        newMaxCondition = 1
    end

    if newCondition > newMaxCondition then
        newCondition = newMaxCondition
    end

    target:setConditionMax(newMaxCondition)
    target:setConditionNoSound(newCondition)

    if newCondition > 0 and target.setBroken then
        target:setBroken(false)
    end

    applyDamage(target, newStacks)

    local data = modData(target)
    if data then
        data[DATA_KEYS.stacks] = newStacks
        data[DATA_KEYS.baseName] = baseName(target)
    end

    persistConditionState(target, newMaxCondition, newCondition)

    target:setName(baseName(target) .. " " .. tostring(newStacks) .. "x")
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

local startupScansRemaining = 120

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

local function onPlayerUpdate(player)
    if startupScansRemaining <= 0 then
        Events.OnPlayerUpdate.Remove(onPlayerUpdate)
        return
    end

    startupScansRemaining = startupScansRemaining - 1
    M.restoreInventory(player)
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(restoreAllPlayers)
end

if Events and Events.OnCreatePlayer then
    Events.OnCreatePlayer.Add(onCreatePlayer)
end

if Events and Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(onPlayerUpdate)
end

if Events and Events.OnSave then
    Events.OnSave.Add(persistAllPlayers)
end
