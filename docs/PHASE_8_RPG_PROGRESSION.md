# Phase 8 — RPG Progression, Equipment, Skills, and Rewards

Phase 8 adds a persistent `ProgressionProfile` with capped level 1–99 experience, stat and skill points, currency, unlocks, inventory/loadouts, permanent weapon and spell levels, skill ranks, and idempotent reward claims. Profiles round-trip through versioned dictionaries and `SaveService.save_snapshot_atomic()`.

The runtime separates authored definitions from mutable state. `EquipmentDefinition`, `SkillNodeDefinition`, and `TemporaryUpgradeDefinition` are indexed by the content database. `InventoryManager`, `SkillTreeManager`, `TemporaryUpgradeDraft`, `StatCalculator`, and `RewardCalculator` enforce compatibility, caps, stacking order, respec refunds, safe draft presentation, checkpoint restoration, mission reset, and one-time reward transactions. `WeaponRuntime` and `SpellRuntime` consume permanent upgrade levels so builds affect combat.

`ExperienceCurve` and `EconomyReporter` export level and campaign economy CSV files. `ResultsScreen` calculates and claims a transaction once before continuing.

Authored balance snapshots are stored in `phase8_level_curve.csv` and `phase8_economy_report.csv`. Regenerate them with `godot --headless --path . --script res://tools/export_phase8_balance_reports.gd` after changing curve constants.

Run acceptance tests:

```powershell
godot --headless --path . --script res://tests/phase8/phase8_acceptance.gd
```
