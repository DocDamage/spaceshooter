# Phase 13: Boss and Miniboss Framework

Phase 13 provides a reusable, resource-authored boss stack intended for 60 minibosses, six operation bosses, secret bosses, and behavioral New Game Plus variants.

`BossDefinition` composes durability, phases, optional targetable parts, challenges, variants, arena data, dialogue hooks, visual assets, and guaranteed rewards. `BossPhaseDefinition` owns health/duration/external transition rules, movement and attack decks, summons, part availability, arena behavior, music, dialogue, transition presentation, and enrage behavior. Minibosses use the same definition with `is_miniboss`, producing a compact HUD while retaining a deliberately limited phase set.

`BossActor` extends the production actor contract and coordinates the existing health, shield, armor, status, typed-event, enemy attack, enemy movement, and stable-ID systems. Runtime responsibilities are separated into:

- `BossPhaseStateMachine` for deterministic phase and enrage transitions.
- `BossPartRuntime` for independent targetability, armor, durability, attack removal, weakness exposure, movement changes, retaliation hooks, challenges, and drops.
- `BossSummonController` for bounded summon ownership.
- `BossArenaController` for multiplayer clearance, safe entry and respawn, framing bounds, hazards, locks, and cleanup.
- `BossChallengeTracker` for the ten reusable challenge families in the implementation plan.
- `BossHUD` for top-screen health, shields, armor, phase divisions, parts, enrage, statuses, and challenges.
- `BossPracticeSession` for phase/loadout/difficulty selection with rewards and campaign completion disabled by default.

New Game Plus variants add or replace attack behavior, parts, summons, arena behavior, and rewards. Validation rejects variants that only adjust statistics, protecting the plan's requirement that NG+ bosses gain meaningful mechanical differences rather than inflated health.

The sample `boss.corsair_dreadnought` demonstrates two phases, a destructible turret, an arena hazard transition, summons, two challenges, guaranteed rewards, and an NG+ behavior variant. Boss checkpoint state serializes only stable IDs and plain data.

Run acceptance coverage with:

```powershell
godot.cmd --headless --path . --script res://tests/phase13/phase13_acceptance.gd
```

Phase 13 does not change the profile save schema. Boss encounter snapshots are mission/checkpoint data and remain separate from persistent campaign profiles.
