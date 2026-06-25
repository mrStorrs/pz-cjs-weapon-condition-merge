# CJS Weapon Condition Merge

Lightweight Project Zomboid B42 mod for merging two matching weapons, including firearms.

Right-click the weapon you want to keep, choose **Merge Weapon Condition**, then choose a same-type donor weapon. The donor is consumed.

Behavior:

- Same `FullType` weapons only.
- Firearm donors must be unloaded, with no inserted magazine, chambered round, or attached weapon parts.
- Broken or zero-condition weapons can be merged.
- Favorited or equipped donor weapons are ignored.
- Stack counts add together: `1x + 1x = 2x`, `2x + 1x = 3x`, `2x + 2x = 4x`.
- The kept weapon is renamed to `Base Name Nx`.
- The donor weapon's current condition is multiplied by the sandbox condition multiplier, then added to the kept weapon.
- The merged weapon's max condition becomes the new current condition, so `10/10 + 5/10 = 15/15`.
- Damage is recalculated from the kept weapon's original min/max damage.
- Stacked condition is stored in item mod data and restored when the save is loaded.
- Stacked condition is refreshed when moved into storage and restored when taken back out.
- Weapon Mastery System compatibility: merged condition/damage replay as the weapon's base stats before mastery affixes are reapplied.
- Weapon Mastery System compatibility: stacked names are preserved inside mastery affix names, and mastery's upgrade repair is disabled for merged weapons.

Sandbox defaults:

- Condition Multiplier: `1.0`
- Damage Percent Per Stack: `1.0`
- Merge Duration: `60`
