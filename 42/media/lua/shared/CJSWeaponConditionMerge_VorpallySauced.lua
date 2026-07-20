require "CJSWeaponConditionMerge"

local MOD_ID = "cjsWeaponConditionMerge"
local VORPALLY_KEY = "VorpallySauced"
local VORPALLY_BASE_CONDITION_MAX_KEY = "cjsWcmVorpallyBaseConditionMax"

local M = CJSWeaponConditionMerge
if not M then
    return
end

local appliedSignatures = {}
local reapplyStates = {}

local function log(message)
    if print then
        print("[" .. MOD_ID .. "] " .. tostring(message))
    end
end

local function weaponKey(weapon)
    if weapon and weapon.getID then
        return tostring(weapon:getID())
    end

    return tostring(weapon)
end

local function cjsModData(weapon)
    if not weapon or not weapon.getModData then return nil end
    return weapon:getModData()
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

local function rawVorpallyData(weapon)
    if not weapon or not weapon.getModData then return nil end

    local data = weapon:getModData()
    return data and data[VORPALLY_KEY] or nil
end

local function vorpallyWeaponData()
    return VorpallySauced and VorpallySauced.WeaponData or nil
end

local function vorpallyData(weapon)
    local weaponData = vorpallyWeaponData()
    if weaponData and weaponData.getModData then
        local ok, data = pcall(weaponData.getModData, weapon)
        if ok and data then
            return data
        end
    end

    return rawVorpallyData(weapon)
end

local function hasVorpallyData(weapon)
    local data = vorpallyData(weapon)
    return type(data) == "table"
end

local function persistVorpallyCondition(weapon)
    local data = vorpallyData(weapon)
    if type(data) ~= "table" or not weapon then
        return false
    end

    data.savedCondition = weapon.getCondition and weapon:getCondition() or data.savedCondition

    if weapon:hasHeadCondition() then
        data.savedHeadCondition = weapon:getHeadCondition()
    end

    return true
end

local function compatibilitySignature(weapon, data)
    data = data or vorpallyData(weapon)

    local itemData = cjsModData(weapon) or {}
    local vorpally = type(data) == "table" and data or {}

    return table.concat({
        tostring(itemData.cjsWcmStacks or ""),
        tostring(itemData.cjsWcmConditionMax or ""),
        tostring(itemData.cjsWcmCondition or ""),
        tostring(itemData.cjsWcmHeadConditionMax or ""),
        tostring(itemData.cjsWcmHeadCondition or ""),
        tostring(itemData.cjsWcmBaseMinDamage or ""),
        tostring(itemData.cjsWcmBaseMaxDamage or ""),
        tostring(vorpally.prefixId or ""),
        tostring(vorpally.suffixId or ""),
        tostring(vorpally.bondingId or ""),
        tostring(vorpally.kills or ""),
    }, "|")
end

local function markApplied(weapon, data)
    appliedSignatures[weaponKey(weapon)] = compatibilitySignature(weapon, data)
end

local function clearApplied(weapon)
    appliedSignatures[weaponKey(weapon)] = nil
end

local function isMarkedApplied(weapon)
    local key = weaponKey(weapon)
    local signature = appliedSignatures[key]
    return signature ~= nil and signature == compatibilitySignature(weapon)
end

function M.externalBaseName(item)
    local data = vorpallyData(item)
    if type(data) == "table" and data.originalName and data.originalName ~= "" then
        return data.originalName
    end

    return nil
end

local function stackedVorpallyBaseName(weapon)
    if M.stackedDisplayName then
        return M.stackedDisplayName(weapon)
    end

    return nil
end

local function patchForeignStats()
    local foreignStats = VorpallySauced
        and VorpallySauced.StatModifiers
        and VorpallySauced.StatModifiers.ForeignStats

    if not foreignStats or not foreignStats.replay or foreignStats.cjsWcmReplayPatched then
        return false
    end

    local originalReplay = foreignStats.replay
    foreignStats.cjsWcmReplayPatched = true
    foreignStats.cjsWcmOriginalReplay = originalReplay

    function foreignStats.replay(weapon)
        local preservedState = reapplyStates[weaponKey(weapon)]
        local sourceCondition = preservedState and preservedState.condition or nil
        local sourceConditionMax = preservedState and preservedState.conditionMax or nil
        local sourceHeadCondition = preservedState and preservedState.headCondition or nil
        local sourceHeadConditionMax = preservedState and preservedState.headConditionMax or nil
        if weapon and not preservedState then
            sourceCondition = weapon:getCondition()
            sourceConditionMax = weapon:getConditionMax()
            if weapon:hasHeadCondition() then
                sourceHeadCondition = weapon:getHeadCondition()
                sourceHeadConditionMax = weapon:getHeadConditionMax()
            end
        end

        local result = originalReplay(weapon)

        if M.isStackedWeapon and M.isStackedWeapon(weapon) and M.refreshItemState then
            M._cjsWcmVorpallyReplayDepth = (M._cjsWcmVorpallyReplayDepth or 0) + 1
            local ok, err = pcall(M.refreshItemState, nil, weapon, sourceCondition, sourceConditionMax, sourceHeadCondition, sourceHeadConditionMax)
            M._cjsWcmVorpallyReplayDepth = M._cjsWcmVorpallyReplayDepth - 1

            if not ok then
                log("Weapon Mastery foreign-stat refresh failed: " .. tostring(err))
            end
        end

        return result
    end

    return true
end

local function patchReapply()
    local reapply = VorpallySauced
        and VorpallySauced.StatModifiers
        and VorpallySauced.StatModifiers.Reapply
    if not reapply or not reapply.reapplyUpgrades or reapply.cjsWcmReapplyPatched then
        return false
    end

    local originalReapply = reapply.reapplyUpgrades
    reapply.cjsWcmReapplyPatched = true
    reapply.cjsWcmOriginalReapply = originalReapply

    function reapply.reapplyUpgrades(weapon)
        if not M.isStackedWeapon or not M.isStackedWeapon(weapon) then
            return originalReapply(weapon)
        end

        local key = weaponKey(weapon)
        reapplyStates[key] = {
            condition = weapon:getCondition(),
            conditionMax = weapon:getConditionMax(),
            headCondition = weapon:hasHeadCondition() and weapon:getHeadCondition() or nil,
            headConditionMax = weapon:hasHeadCondition() and weapon:getHeadConditionMax() or nil,
        }

        local results = { pcall(originalReapply, weapon) }
        reapplyStates[key] = nil

        if not results[1] then
            error(results[2])
        end

        M.persistItemState(weapon)
        return results[2], results[3], results[4]
    end

    return true
end

local function patchNameHelpers()
    local helpers = VorpallySauced
        and VorpallySauced.StatModifiers
        and VorpallySauced.StatModifiers.Helpers

    if not helpers then
        return false
    end

    local patched = false

    if helpers.getCleanBaseName and not helpers.cjsWcmGetCleanBaseNamePatched then
        local originalGetCleanBaseName = helpers.getCleanBaseName
        helpers.cjsWcmGetCleanBaseNamePatched = true
        helpers.cjsWcmOriginalGetCleanBaseName = originalGetCleanBaseName

        function helpers.getCleanBaseName(weapon, data)
            if M.isStackedWeapon and M.isStackedWeapon(weapon) then
                local name = stackedVorpallyBaseName(weapon)
                if name and name ~= "" then
                    return name
                end
            end

            return originalGetCleanBaseName(weapon, data)
        end

        patched = true
    end

    if helpers.rebuildWeaponName and not helpers.cjsWcmRebuildWeaponNamePatched then
        local originalRebuildWeaponName = helpers.rebuildWeaponName
        helpers.cjsWcmRebuildWeaponNamePatched = true
        helpers.cjsWcmOriginalRebuildWeaponName = originalRebuildWeaponName

        function helpers.rebuildWeaponName(weapon, data)
            if data and M.isStackedWeapon and M.isStackedWeapon(weapon) then
                local name = stackedVorpallyBaseName(weapon)
                if name and name ~= "" then
                    data.originalName = name
                end
            end

            return originalRebuildWeaponName(weapon, data)
        end

        patched = true
    end

    return patched
end

local function getVorpallyAffix(affixType, affixId, isFirearm)
    if not affixId or not VorpallySauced then
        return nil
    end

    if affixType == "prefix" then
        local getter = isFirearm and VorpallySauced.getFirearmPrefix or VorpallySauced.getPrefix
        return getter and getter(affixId) or nil
    elseif affixType == "suffix" then
        local getter = isFirearm and VorpallySauced.getFirearmSuffix or VorpallySauced.getSuffix
        return getter and getter(affixId) or nil
    elseif affixType == "bonding" then
        local getter = isFirearm and VorpallySauced.getFirearmBonding or VorpallySauced.getBonding
        return getter and getter(affixId) or nil
    end

    return nil
end

local function affixConditionMaxMultiplier(affixType, affixId, isFirearm)
    local affix = getVorpallyAffix(affixType, affixId, isFirearm)
    if not affix then
        return nil
    end

    local value = nil
    if affix.stat == "conditionMax" then
        value = affix.value
    elseif affix.stats then
        value = affix.stats.conditionMax
    end

    value = tonumber(value)
    return value and value > 0 and value or nil
end

local function effectiveConditionMaxMultiplier(data, isFirearm)
    if type(data) ~= "table" then
        return 1.0
    end

    local multiplier = 1.0
    local orderedAffixes = {
        { "prefix", data.prefixId },
        { "suffix", data.suffixId },
        { "bonding", data.bondingId },
    }

    for _, entry in ipairs(orderedAffixes) do
        local value = affixConditionMaxMultiplier(entry[1], entry[2], isFirearm)
        if value then
            multiplier = value
        end
    end

    return multiplier
end

local function rememberVorpallyBaseConditionMax(weapon, effectiveMultiplier)
    local itemData = cjsModData(weapon)
    local currentMax = weapon and tonumber(weapon:getConditionMax()) or nil
    effectiveMultiplier = tonumber(effectiveMultiplier) or 1.0
    if not itemData or not currentMax or currentMax < 1 or effectiveMultiplier <= 0 then
        return nil
    end

    local baseMax = currentMax / effectiveMultiplier
    itemData[VORPALLY_BASE_CONDITION_MAX_KEY] = baseMax
    return baseMax
end

local function patchCoreStats()
    local coreStats = VorpallySauced
        and VorpallySauced.StatModifiers
        and VorpallySauced.StatModifiers.Core
    if not coreStats or not coreStats.applyStat or coreStats.cjsWcmApplyStatPatched then
        return false
    end

    local originalApplyStat = coreStats.applyStat
    coreStats.cjsWcmApplyStatPatched = true
    coreStats.cjsWcmOriginalApplyStat = originalApplyStat

    function coreStats.applyStat(weapon, statName, value, originalStats)
        if statName ~= "conditionMax" or not M.isStackedWeapon or not M.isStackedWeapon(weapon) then
            return originalApplyStat(weapon, statName, value, originalStats)
        end

        local multiplier = tonumber(value)
        local itemData = cjsModData(weapon)
        if not multiplier or multiplier <= 0 or not itemData then
            return originalApplyStat(weapon, statName, value, originalStats)
        end

        local baseMax = tonumber(itemData[VORPALLY_BASE_CONDITION_MAX_KEY])
        if not baseMax or baseMax <= 0 then
            local data = vorpallyData(weapon)
            local isFirearm = type(data) == "table" and data.isFirearm == true
            local effectiveMultiplier = effectiveConditionMaxMultiplier(data, isFirearm)
            local storedMax = tonumber(itemData.cjsWcmConditionMax) or weapon:getConditionMax()
            baseMax = storedMax / effectiveMultiplier
            itemData[VORPALLY_BASE_CONDITION_MAX_KEY] = baseMax
        end

        local targetMax = math.max(1, math.floor((baseMax * multiplier) + 0.000001))
        weapon:setConditionMax(targetMax)
    end

    return true
end

--- Add only the condition created by a newly gained maximum-durability modifier.
--- The previous damage deficit is preserved even when the merged maximum is large.
function M.addVorpallyDurabilityGain(weapon, previousMax, previousCondition, previousMultiplier, newMultiplier)
    previousMax = math.floor(tonumber(previousMax) or 0)
    previousCondition = math.floor(tonumber(previousCondition) or 0)
    previousMultiplier = tonumber(previousMultiplier) or 1.0
    newMultiplier = tonumber(newMultiplier)

    if not weapon or previousMax < 1 or previousMultiplier <= 0 or not newMultiplier or newMultiplier <= 0 then
        return false, 0
    end

    previousCondition = math.max(0, math.min(previousCondition, previousMax))

    -- VPS conditionMax modifiers replace earlier conditionMax multipliers in
    -- prefix -> suffix -> bonding order. Apply the ratio to the merged maximum
    -- so a 1.5x -> 3x transition doubles it instead of tripling it again.
    local itemData = cjsModData(weapon)
    local baseMax = itemData and tonumber(itemData[VORPALLY_BASE_CONDITION_MAX_KEY]) or nil
    if not baseMax or baseMax <= 0 then
        baseMax = previousMax / previousMultiplier
    end
    local scaledMax = math.floor((baseMax * newMultiplier) + 0.000001)
    local targetMax = math.max(previousMax, scaledMax)
    local addedCondition = targetMax - previousMax
    local targetCondition = math.min(targetMax, previousCondition + addedCondition)

    weapon:setConditionMax(targetMax)
    weapon:setConditionNoSound(targetCondition)
    if targetCondition > 0 and weapon:isBroken() then
        weapon:setBroken(false)
    end

    if itemData then
        itemData[VORPALLY_BASE_CONDITION_MAX_KEY] = baseMax
        itemData.cjsWcmConditionMax = targetMax
        itemData.cjsWcmCondition = targetCondition
    end
    persistVorpallyCondition(weapon)

    return addedCondition > 0, addedCondition
end

local function patchUpgradeManager()
    local upgradeManager = VorpallySauced and VorpallySauced.UpgradeManager or nil
    if not upgradeManager or not upgradeManager.applyUpgrade or upgradeManager.cjsWcmApplyUpgradePatched then
        return false
    end

    local originalApplyUpgrade = upgradeManager.applyUpgrade
    upgradeManager.cjsWcmApplyUpgradePatched = true
    upgradeManager.cjsWcmOriginalApplyUpgrade = originalApplyUpgrade

    function upgradeManager.applyUpgrade(weapon, affixType, affixId, isFirearm)
        if not M.isStackedWeapon or not M.isStackedWeapon(weapon) then
            return originalApplyUpgrade(weapon, affixType, affixId, isFirearm)
        end

        clearApplied(weapon)

        local previousMax = weapon:getConditionMax()
        local previousCondition = weapon:getCondition()
        local previousMultiplier = effectiveConditionMaxMultiplier(vorpallyData(weapon), isFirearm)
        local newMultiplier = affixConditionMaxMultiplier(affixType, affixId, isFirearm)

        local createdVars = false
        local vars = SandboxVars and SandboxVars[VORPALLY_KEY] or nil
        if SandboxVars and not vars then
            SandboxVars[VORPALLY_KEY] = {}
            vars = SandboxVars[VORPALLY_KEY]
            createdVars = true
        end

        local previousAutoRepair = vars and vars.AutoRepairOnUpgrade or nil
        if vars then
            vars.AutoRepairOnUpgrade = false
        end

        local results = { pcall(originalApplyUpgrade, weapon, affixType, affixId, isFirearm) }

        if createdVars then
            SandboxVars[VORPALLY_KEY] = nil
        elseif vars then
            vars.AutoRepairOnUpgrade = previousAutoRepair
        end

        if not results[1] then
            error(results[2])
        end

        if newMultiplier then
            M.addVorpallyDurabilityGain(
                weapon,
                previousMax,
                previousCondition,
                previousMultiplier,
                newMultiplier
            )
        end

        markApplied(weapon)

        return results[2], results[3], results[4]
    end

    return true
end

function M.installVorpallyCompatibility()
    if not VorpallySauced then
        return false
    end

    local patched = false
    patched = patchForeignStats() or patched
    patched = patchNameHelpers() or patched
    patched = patchCoreStats() or patched
    patched = patchReapply() or patched
    patched = patchUpgradeManager() or patched

    if patched then
        log("Weapon Mastery compatibility hooks installed")
    end

    return patched
end

function M.reapplyVorpally(character, weapon)
    if not M.isStackedWeapon or not M.isStackedWeapon(weapon) then
        return false
    end

    local data = vorpallyData(weapon)
    if type(data) ~= "table" then
        return false
    end

    M.installVorpallyCompatibility()

    local statModifiers = VorpallySauced and VorpallySauced.StatModifiers or nil
    local reapply = statModifiers and statModifiers.reapplyUpgrades or nil
    if not reapply and statModifiers and statModifiers.Reapply then
        reapply = statModifiers.Reapply.reapplyUpgrades
    end

    if not reapply then
        return false
    end

    if (M._cjsWcmVorpallyReapplyDepth or 0) > 0 then
        return false
    end

    if M.persistItemState then
        M.persistItemState(weapon)
    else
        persistVorpallyCondition(weapon)
    end

    M._cjsWcmVorpallyReapplyDepth = (M._cjsWcmVorpallyReapplyDepth or 0) + 1
    local ok, err = pcall(reapply, weapon)
    M._cjsWcmVorpallyReapplyDepth = M._cjsWcmVorpallyReapplyDepth - 1

    if not ok then
        log("Weapon Mastery reapply failed: " .. tostring(err))
        return false
    end

    markApplied(weapon, data)
    syncWeapon(character, weapon)
    return true
end

local function isVorpallyRecalculating()
    return (M._cjsWcmVorpallyReplayDepth or 0) > 0
        or (M._cjsWcmVorpallyReapplyDepth or 0) > 0
end

local previousBeforeRestore = M.beforeRestoreItemState
function M.beforeRestoreItemState(character, weapon)
    if previousBeforeRestore and previousBeforeRestore(character, weapon) then
        return true
    end

    if isVorpallyRecalculating() then
        return false
    end

    if not hasVorpallyData(weapon) then
        return false
    end

    if isMarkedApplied(weapon) then
        return true
    end

    return false
end

local previousAfterRestore = M.afterRestoreItemState
function M.afterRestoreItemState(character, weapon, changed)
    if previousAfterRestore then
        previousAfterRestore(character, weapon, changed)
    end

    if isVorpallyRecalculating() then
        return
    end

    if not M.isStackedWeapon or not M.isStackedWeapon(weapon) then
        return
    end

    if not hasVorpallyData(weapon) or isMarkedApplied(weapon) then
        return
    end

    M.reapplyVorpally(character, weapon)
end

local previousBeforePersist = M.beforePersistItemState
function M.beforePersistItemState(weapon)
    if previousBeforePersist and previousBeforePersist(weapon) then
        return true
    end

    if not M.isStackedWeapon or not M.isStackedWeapon(weapon) then
        return false
    end

    if not hasVorpallyData(weapon) then
        return false
    end

    persistVorpallyCondition(weapon)
    return false
end

local previousAfterMerge = M.afterMerge
function M.afterMerge(character, target, donor)
    if previousAfterMerge then
        previousAfterMerge(character, target, donor)
    end

    local data = vorpallyData(target)
    if type(data) == "table" then
        local isFirearm = data.isFirearm == true
        rememberVorpallyBaseConditionMax(target, effectiveConditionMaxMultiplier(data, isFirearm))
    end

    M.reapplyVorpally(character, target)
end

local function installCompatibility()
    M.installVorpallyCompatibility()
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(installCompatibility)
end

if Events and Events.OnCreatePlayer then
    Events.OnCreatePlayer.Add(installCompatibility)
end

if Events and Events.OnServerStarted then
    Events.OnServerStarted.Add(installCompatibility)
end

installCompatibility()
