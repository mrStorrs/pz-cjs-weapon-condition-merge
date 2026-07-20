local function equal(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected=" .. tostring(expected) .. " actual=" .. tostring(actual), 2)
    end
end

Events = nil
SandboxVars = { VorpallySauced = { AutoRepairOnUpgrade = true } }
instanceof = function() return true end

dofile("42/media/lua/shared/CJSWeaponConditionMerge.lua")
package.loaded.CJSWeaponConditionMerge = CJSWeaponConditionMerge

local prefixes = {
    [1] = { stat = "damage", value = 0.1 },
}
local suffixes = {
    [1] = { stat = "conditionMax", value = 1.5 },
    [2] = { stat = "conditionMax", value = 2.5 },
    [3] = { stat = "conditionMax", value = 1.2 },
}
local bondings = {
    [1] = { stats = { conditionMax = 3.0 } },
}

local function affix(affixType, affixId)
    if affixType == "prefix" then return prefixes[affixId] end
    if affixType == "suffix" then return suffixes[affixId] end
    if affixType == "bonding" then return bondings[affixId] end
    return nil
end

VorpallySauced = {
    getPrefix = function(id) return prefixes[id] end,
    getSuffix = function(id) return suffixes[id] end,
    getBonding = function(id) return bondings[id] end,
    getFirearmPrefix = function(id) return prefixes[id] end,
    getFirearmSuffix = function(id) return suffixes[id] end,
    getFirearmBonding = function(id) return bondings[id] end,
    WeaponData = {
        getModData = function(weapon)
            return weapon:getModData().VorpallySauced
        end,
    },
    StatModifiers = {
        ForeignStats = {
            replay = function() end,
        },
        Core = {
            applyStat = function(weapon, statName, value)
                if statName == "conditionMax" then
                    weapon:setConditionMax(math.floor(weapon.scriptConditionMax * value))
                end
            end,
        },
        Reapply = {},
    },
    UpgradeManager = {},
}

function VorpallySauced.StatModifiers.Reapply.reapplyUpgrades(weapon)
    local savedCondition = weapon:getCondition()
    local data = weapon:getModData().VorpallySauced

    weapon:setConditionMax(weapon.scriptConditionMax)
    weapon:setConditionNoSound(math.min(weapon:getCondition(), weapon:getConditionMax()))
    VorpallySauced.StatModifiers.ForeignStats.replay(weapon)

    if data.suffixId and suffixes[data.suffixId].value then
        VorpallySauced.StatModifiers.Core.applyStat(weapon, "conditionMax", suffixes[data.suffixId].value, {})
    end
    if data.bondingId and bondings[data.bondingId].stats.conditionMax then
        VorpallySauced.StatModifiers.Core.applyStat(weapon, "conditionMax", bondings[data.bondingId].stats.conditionMax, {})
    end

    weapon:setConditionNoSound(math.min(savedCondition, weapon:getConditionMax()))
end

function VorpallySauced.UpgradeManager.applyUpgrade(weapon, affixType, affixId)
    local data = weapon:getModData().VorpallySauced
    local definition = affix(affixType, affixId)

    if affixType == "prefix" then data.prefixId = affixId end
    if affixType == "suffix" then data.suffixId = affixId end
    if affixType == "bonding" then data.bondingId = affixId end

    local multiplier = definition.stat == "conditionMax" and definition.value
        or (definition.stats and definition.stats.conditionMax)
    if multiplier then
        weapon:setConditionMax(math.floor(weapon.scriptConditionMax * multiplier))
    end

    if SandboxVars.VorpallySauced.AutoRepairOnUpgrade ~= false then
        weapon:setConditionNoSound(weapon:getConditionMax())
    end
end

dofile("42/media/lua/shared/CJSWeaponConditionMerge_VorpallySauced.lua")
CJSWeaponConditionMerge.isStackedWeapon = function(weapon) return weapon.stacked ~= false end
CJSWeaponConditionMerge.installVorpallyCompatibility()

local function newWeapon(conditionMax, condition, data)
    local weapon = {
        conditionMax = conditionMax,
        condition = condition,
        broken = condition <= 0,
        scriptConditionMax = 10,
        name = "Test Weapon 2x",
        minDamage = 1.0,
        maxDamage = 2.0,
        modData = {
            cjsWcmStacks = 2,
            cjsWcmConditionMax = conditionMax,
            cjsWcmCondition = condition,
            VorpallySauced = data or {},
        },
    }

    function weapon:getConditionMax() return self.conditionMax end
    function weapon:setConditionMax(value) self.conditionMax = value end
    function weapon:getCondition() return self.condition end
    function weapon:setConditionNoSound(value) self.condition = value end
    function weapon:getModData() return self.modData end
    function weapon:getDisplayName() return self.name end
    function weapon:setName(value) self.name = value end
    function weapon:getMinDamage() return self.minDamage end
    function weapon:setMinDamage(value) self.minDamage = value end
    function weapon:getMaxDamage() return self.maxDamage end
    function weapon:setMaxDamage(value) self.maxDamage = value end
    function weapon:hasHeadCondition() return false end
    function weapon:isBroken() return self.broken end
    function weapon:setBroken(value) self.broken = value end

    return weapon
end

local ordinary = newWeapon(40, 12)
VorpallySauced.UpgradeManager.applyUpgrade(ordinary, "prefix", 1, false)
equal(ordinary:getConditionMax(), 40, "ordinary modifier keeps merged maximum")
equal(ordinary:getCondition(), 12, "ordinary modifier does not repair")
equal(SandboxVars.VorpallySauced.AutoRepairOnUpgrade, true, "sandbox option restored")

local unstacked = newWeapon(40, 12)
unstacked.stacked = false
VorpallySauced.UpgradeManager.applyUpgrade(unstacked, "prefix", 1, false)
equal(unstacked:getCondition(), 40, "unstacked mastery repair remains unchanged")

local fiftyPercent = newWeapon(40, 12)
VorpallySauced.UpgradeManager.applyUpgrade(fiftyPercent, "suffix", 1, false)
equal(fiftyPercent:getConditionMax(), 60, "50 percent modifier scales merged maximum")
equal(fiftyPercent:getCondition(), 32, "50 percent modifier repairs only added capacity")
equal(fiftyPercent:getModData().cjsWcmConditionMax, 60, "merged maximum persisted")
equal(fiftyPercent:getModData().cjsWcmCondition, 32, "merged condition persisted")
equal(fiftyPercent:getModData().VorpallySauced.savedCondition, 32, "mastery condition persisted")
equal(fiftyPercent:getModData().cjsWcmVorpallyBaseConditionMax, 40, "merged base maximum persisted")

fiftyPercent:setConditionMax(10)
VorpallySauced.StatModifiers.Core.applyStat(fiftyPercent, "conditionMax", 1.5, {})
equal(fiftyPercent:getConditionMax(), 60, "mastery reapply uses merged base maximum")

VorpallySauced.StatModifiers.Reapply.reapplyUpgrades(fiftyPercent)
equal(fiftyPercent:getConditionMax(), 60, "reapply preserves gained merged maximum")
equal(fiftyPercent:getCondition(), 32, "reapply preserves partial condition")
equal(fiftyPercent:getModData().cjsWcmCondition, 32, "reapply persists partial condition")

local highCapacity = newWeapon(240, 137)
VorpallySauced.UpgradeManager.applyUpgrade(highCapacity, "suffix", 2, false)
equal(highCapacity:getConditionMax(), 600, "large merged maximum scales safely")
equal(highCapacity:getCondition(), 497, "large maximum preserves wear deficit")

local replacement = newWeapon(60, 31, { suffixId = 1 })
VorpallySauced.UpgradeManager.applyUpgrade(replacement, "bonding", 1, false)
equal(replacement:getConditionMax(), 120, "3x bonding replaces prior 1.5x multiplier")
equal(replacement:getCondition(), 91, "replacement multiplier repairs only max delta")
VorpallySauced.StatModifiers.Reapply.reapplyUpgrades(replacement)
equal(replacement:getConditionMax(), 120, "replacement maximum survives reapply")
equal(replacement:getCondition(), 91, "replacement condition survives reapply")

local roundedReplacement = newWeapon(13, 7, { suffixId = 3 })
roundedReplacement:getModData().cjsWcmVorpallyBaseConditionMax = 11
VorpallySauced.UpgradeManager.applyUpgrade(roundedReplacement, "bonding", 1, false)
equal(roundedReplacement:getConditionMax(), 33, "replacement uses exact stored merged base")
equal(roundedReplacement:getCondition(), 27, "rounded replacement repairs exact max delta")
VorpallySauced.StatModifiers.Reapply.reapplyUpgrades(roundedReplacement)
equal(roundedReplacement:getConditionMax(), 33, "rounded replacement maximum survives reapply")
equal(roundedReplacement:getCondition(), 27, "rounded replacement condition survives reapply")

local broken = newWeapon(40, 0)
VorpallySauced.UpgradeManager.applyUpgrade(broken, "suffix", 1, false)
equal(broken:getConditionMax(), 60, "broken weapon gains maximum")
equal(broken:getCondition(), 20, "broken weapon receives added capacity")
equal(broken:isBroken(), false, "positive gained condition clears broken state")

print("test_vorpally_durability_gain.lua: ok")
