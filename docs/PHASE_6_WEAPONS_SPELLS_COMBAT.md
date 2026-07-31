# Phase 6: Weapons, Projectiles, Spells, and Combat Interaction

Phase 6 replaces the legacy per-shot allocation path with reusable, data-driven combat systems.

## Implemented systems

- Category-based pooled combat objects for player/enemy bullets, missiles, mines, pickups, impacts, explosions, and damage popups.
- Complete projectile reset validation and scoped actor-registry ownership.
- Projectile definitions covering movement, damage, teams, pierce/bounce, homing, lifetime, hit/despawn behavior, interaction tags, feedback IDs, and pool category.
- Stateful weapon runtime for automatic, semi-automatic, charge, burst, cooldown, heat, energy, magazines, spread, muzzles, recoil, upgrade scaling, target locks, and weapon switching.
- Data examples for pulse, spread, beam, missile, mine, rail, drone, scatter, homing laser, and chain-lightning families.
- Spell definitions and runtime examples for Nova, Aegis, Gravity, Warp, Void, Solar, Cryo, Storm, Summon, and Repair.
- Data-driven projectile destroy, reflect, absorb, energy/score conversion, freeze, slow, redirect, phase, split, and detonate policies.
- Energy blade/arc targeting, shockwave-ready radius, charged ramming, collision armor, parry, hit stop, and close-range risk bonus.
- Stable-ID lock-on acquisition, prioritization, cycling, multiple targets, classic/twin-stick direction, aim assistance, reticle rendering, and destroyed-target cleanup.
- Charge/duration/cancellation/stage-transition-safe super modes with weapon replacement and optional invulnerability.
- Central feedback events and a 32-voice limiter for hit, shield, reflection, absorb, melee, vibration, and audio presentation.
- An interactive weapon laboratory scene at `res://production/combat/weapon_laboratory.tscn`.

## Verification

Run:

```text
godot --headless --path . --script res://tests/phase6/phase6_acceptance.gd
```

The suite verifies clean pool reset, 2,000-projectile acquisition/release, reflection attribution, absorb safety, destroyed lock targets, cooldown-safe switching, content validation, all ten weapon families, and all ten spell schools.

Regression suites for Phases 2–5 and a 180-frame production boot smoke test also pass under Godot 4.7.1.
