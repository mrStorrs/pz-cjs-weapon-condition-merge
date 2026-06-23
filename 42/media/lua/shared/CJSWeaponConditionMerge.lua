local MOD_ID = "cjsWeaponConditionMerge"

local DATA_KEYS = {
    stacks = "cjsWcmStacks",
    baseName = "cjsWcmBaseName",
    baseMinDamage = "cjsWcmBaseMinDamage",
    baseMaxDamage = "cjsWcmBaseMaxDamage",
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

function M.merge(character, target, donor)
    if not M.canMerge(target, donor) then
        return false
    end

    local targetStacks = currentStacks(target)
    local donorStacks = currentStacks(donor)
    local newStacks = targetStacks + donorStacks
    local conditionMultiplier = M.conditionMultiplier()

    local newMaxCondition = round((target:getConditionMax() * conditionMultiplier) + (donor:getConditionMax() * conditionMultiplier))
    local newCondition = round((target:getCondition() * conditionMultiplier) + (donor:getCondition() * conditionMultiplier))

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

    local damageFactor = 1.0 + ((newStacks - 1) * (M.damagePercentPerStack() / 100.0))
    target:setMinDamage(baseMinDamage(target) * damageFactor)
    target:setMaxDamage(baseMaxDamage(target) * damageFactor)

    local data = modData(target)
    if data then
        data[DATA_KEYS.stacks] = newStacks
        data[DATA_KEYS.baseName] = baseName(target)
    end

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
