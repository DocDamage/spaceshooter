# Phase 7 — Enemies, Formations, Waves, and Drops

Phase 7 turns enemy production into resource authoring. `EnemyDefinition` now composes visuals, scaled stats, collision, movement, attack decks, drops, fixed elite profiles, score, and experience. Runtime target, registry, event bus, and pool references are injected once; attack code performs no scene-tree searches.

The reusable libraries cover the plan's 16 movement modes and 14 attack modes. `FormationDefinition` and `FormationRuntime` own slots, leaders, synchronization, loss behavior, ordered-kill rewards, completion, escape behavior, substitutions, and multiplayer spacing. `WaveDefinition` and `WaveScheduler` own spawn timing and completion. `DropResolver` provides seeded weighted/guaranteed drops, pity protection, difficulty modifiers, and multiplayer ownership.

The initial roster contains twenty presentation-distinct resource variants backed by shared controllers. Open `res://production/enemies/enemy_laboratory.tscn` to cycle through them.

Run acceptance tests:

```powershell
godot --headless --path . --script res://tests/phase7/phase7_acceptance.gd
```
