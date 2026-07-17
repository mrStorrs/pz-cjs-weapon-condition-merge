local function equal(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected=" .. tostring(expected) .. " actual=" .. tostring(actual), 2)
    end
end

Events = nil
dofile("42/media/lua/shared/CJSWeaponConditionMerge.lua")

local mappings = {
    ["LTW.LegendaryTacticalSword"] = "Base.Sword",
    ["LTW.LegendaryTacticalTomahawk"] = "Base.HandAxe",
    ["LTW.LegendaryTacticalAxe"] = "Base.Axe",
    ["LTW.LegendaryTacticalCrowbar"] = "Base.Crowbar",
    ["LTW.LegendaryTacticalBat"] = "Base.BaseballBat_Metal",
    ["LTW.LegendaryTacticalHammer"] = "Base.BallPeenHammer",
    ["LTW.LegendaryTacticalKnife"] = "Base.FightingKnife",
    ["LTW.LegendaryTacticalSledgehammer"] = "Base.Sledgehammer",
    ["LTW.LegendaryTacticalSpear"] = "Base.SpearLargeKnife",
}

for targetType, donorType in pairs(mappings) do
    equal(CJSWeaponConditionMerge.areMergeTypesCompatible(targetType, donorType), true, targetType .. " donor")
    equal(CJSWeaponConditionMerge.areMergeTypesCompatible(donorType, targetType), false, targetType .. " direction")
end

equal(
    CJSWeaponConditionMerge.areMergeTypesCompatible("MoreTraits.AntiqueAxe", "Base.AxeStone"),
    true,
    "legacy antique compatibility"
)
equal(
    CJSWeaponConditionMerge.areMergeTypesCompatible("LTW.LegendaryTacticalAxe", "Base.AxeStone"),
    false,
    "wrong Legendary donor"
)
equal(
    CJSWeaponConditionMerge.areMergeTypesCompatible("Base.Axe", "Base.Axe"),
    true,
    "same-type compatibility"
)

print("test_legendary_antique_compatibility.lua: ok")
