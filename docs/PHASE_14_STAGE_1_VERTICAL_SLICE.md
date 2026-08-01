# Phase 14: Stage 1 Vertical Slice

Phase 14 integrates the production systems from Phases 2–13 into `mission.stage1_vertical_slice`, a deterministic twelve-segment mission with one secret branch. The authored route covers the briefing/preflight loop, tutorial opening, three escalating combat encounters, optional objective, midpoint checkpoint, miniboss, second-half hazard escalation, pre-boss checkpoint, multiphase boss, results, permanent progression, replay, and boss-practice unlock.

`StageOneVerticalSlice` owns preflight selection and the completion transaction. It composes `StageGraphGenerator`, `StageRuntime`, `CampaignProgression`, `RewardCalculator`, `InventoryManager`, `ProfileService`, and the existing boss framework. Reward transaction IDs make XP, currency, and equipment grants idempotent. Campaign and boss-practice state are persisted in the normal version-9 profile rather than a vertical-slice-only save format.

`TutorialDirector` supplies optional, skippable, replayable prompts for movement, primary fire, focus, temporary upgrades, shield, spell, chain, checkpoints, and optional objectives. Prompts resolve through `GameInputService`, so the same topic renders keyboard/mouse or controller glyphs. Accessibility remains driven by `SettingsService` and is recorded in mission metadata.

Run acceptance coverage with:

```powershell
godot.cmd --headless --path . --script res://tests/phase14/phase14_acceptance.gd
```

The Windows debug preset produces `builds/galax-hero-phase14-debug.exe` and excludes source-only and unverified donor formats.
