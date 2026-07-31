# Phase 15: Operation 1 — Frontier Shield

Operation 1 expands the Stage 1 vertical slice into a ten-stage campaign chapter. `OperationDefinition` is the operation bible: it records the theme, human/raider/alien factions, story beats, one teaching mechanic per stage, unlock cadence, deterministic review seeds, segment-usage targets, economy gates, and the Operation 2 handoff.

`OperationOneController` composes the existing content database, graph generator, campaign progression, reward calculator, inventory, profiles, and saves. Missions unlock in prerequisite order. Completion transactions are idempotent, replay rewards retain the Phase 8 seventy-percent cap, every miniboss and declared boss receives a practice entry, and Stage 10 persists `operation1_complete` plus the Operation 2 unlock.

Stages 2–9 terminate with their authored miniboss; Stage 10 adds the Xenarch Command Carrier as the operation's multiphase boss. The stage validator now derives the required terminal encounter from `MissionDefinition.boss_id`: regular stages must reach a miniboss and finale missions that declare a boss must reach that boss. Every recipe retains midpoint and pre-boss checkpoints.

Run acceptance coverage with:

```powershell
godot.cmd --headless --path . --script res://tests/phase15/phase15_acceptance.gd
```

The Windows debug preset produces `builds/galax-hero-phase15-debug.exe`.
