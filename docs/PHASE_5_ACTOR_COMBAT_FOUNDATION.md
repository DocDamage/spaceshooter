# Phase 5 Actor, Movement, Damage, and Status Foundation

Phase 5 replaces actor-specific health subtraction with a shared, deterministic combat pipeline. `BaseActor2D` owns lifecycle and the health, armor, shield, and status components. `DamageResolver` is the sole production damage-order authority.

## Damage order

1. Target and active-state validation
2. Invulnerability validation
3. Projectile interaction (performed by the projectile before resolution)
4. Shield interaction, absorption, reflection, and penetration
5. Armor and armor penetration
6. Damage-type resistance
7. Critical and status multipliers
8. Damage clamp
9. HP application
10. Status application
11. Typed feedback event
12. Destruction and lifecycle handling

`DamagePacket` carries stable source, player, ability, chain, score, and future network-sequence attribution. No scene-tree lookup is needed during resolution.

## Validation

Run the acceptance suite from the project directory:

```powershell
godot --headless --path . --script res://tests/phase5/phase5_acceptance.gd
```

Open `res://tests/phase5/actor_test_scene.tscn` for the visual actor test scene. The production architecture test mission now routes projectile hits through the same shared packet and resolver used by the suite.
