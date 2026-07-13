# CJS Weapon Condition Merge

Lightweight Project Zomboid B42 mod for merging matching weapons, including firearms and selected cross-type donors.

Right-click the weapon you want to keep, choose **Merge Weapon Condition**, then choose a compatible donor weapon. The donor is consumed.

Behavior:

- Weapons with the same `FullType` can merge.
- More Traits Antique Collector weapons can consume the directional vanilla donors listed below.
- Firearm donors must be unloaded, with no inserted magazine, chambered round, or attached weapon parts.
- Broken or zero-condition weapons can be merged.
- Favorited or equipped donor weapons are ignored.
- Stack counts add together: `1x + 1x = 2x`, `2x + 1x = 3x`, `2x + 2x = 4x`.
- The kept weapon is renamed to `Base Name Nx`.
- The donor weapon's current handle condition is multiplied by the sandbox condition multiplier, then added to the kept weapon.
- The merged weapon's max handle condition becomes the new current handle condition, so `10/10 + 5/10 = 15/15`.
- Weapons with separate B42 head condition merge head condition the same way, so `2/5 + 5/5 = 7/7`.
- When only the donor has separate head condition, its head condition is not transferred.
- Damage is recalculated from the kept weapon's original min/max damage.
- Stacked handle and head condition are persisted from live weapons during play and restored only when the save is loaded.
- Storage moves persist the current item state without restoring an older condition value.
- Weapon Mastery System compatibility: merged condition/damage replay as the weapon's base stats before mastery affixes are reapplied.
- Weapon Mastery System compatibility: stacked names are preserved inside mastery affix names, and mastery's upgrade repair is disabled for merged weapons.

More Traits Antique Collector donors:

- Antique Axe: Stone Axe.
- Maul: Stone Maul.
- Obsidian Blade: Long Stone Knife or Flint Knife.
- Bloody Crowbar: Crowbar or Forged Crowbar.
- Slugger: Metal Baseball Bat.
- Antique Spear: Wooden Spear or Fire-Hardened Wooden Spear.
- Antique Forge Hammer: Club Hammer, Forged Club Hammer, or Smithing Hammer. Only handle condition transfers because the antique weapon has no separate head condition.
- Antique Katana: Katana only.

These mappings are directional: the antique weapon must be the retained target, and the vanilla weapon is consumed as the donor. More Traits is optional and is not required to use normal same-type merging.

Sandbox defaults:

- Condition Multiplier: `1.0`
- Damage Percent Per Stack: `1.0`
- Merge Duration: `60`
