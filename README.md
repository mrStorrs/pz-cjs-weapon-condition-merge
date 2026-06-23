# CJS Weapon Condition Merge

Lightweight Project Zomboid B42 mod for merging two matching melee weapons.

Right-click the weapon you want to keep, choose **Merge Weapon Condition**, then choose a same-type donor weapon. The donor is consumed.

Behavior:

- Same `FullType` melee weapons only.
- Broken or zero-condition weapons can be merged.
- Favorited or equipped donor weapons are ignored.
- Stack counts add together: `1x + 1x = 2x`, `2x + 1x = 3x`, `2x + 2x = 4x`.
- The kept weapon is renamed to `Base Name Nx`.
- The donor weapon's condition max/current are multiplied by the sandbox condition multiplier, then added to the kept weapon.
- Damage is recalculated from the kept weapon's original min/max damage.

Sandbox defaults:

- Condition Multiplier: `1.0`
- Damage Percent Per Stack: `1.0`
- Merge Duration: `60`
