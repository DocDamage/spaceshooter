# Phase 9 — Save Integrity

Phase 9 introduces named local profiles, a controller-navigable slot browser, schema-9 profile DTOs, profile-specific settings and campaign metadata, checksum-protected atomic writes, two rotating backup generations, explicit recovery diagnostics, registered schema migration, content-ID reconciliation, and resumable mission checkpoints.

Save domains remain separate: global settings use `settings_v1.json`; profiles and checkpoints live below `user://saves/<profile-id>/`; the profile index lives at `user://saves/profiles.json`. Leaderboards and platform metadata are intentionally not embedded in profile files.

Atomic writes create and validate a temporary envelope before replacement. The prior primary becomes `.previous`, the older known-good backup becomes `.recovery`, and schema migration first preserves `.pre_migration_v<version>`. Invalid files are never silently reset or deleted. The recovery panel can export `user://save_recovery_diagnostics.json`.

Checkpoints preserve the mission ID, exact seed and route, segment, run transaction ID, selected profiles and ships, loadouts, difficulty, objectives, temporary upgrades, and pending rewards. Pending rewards do not enter permanent progression until a unique transaction is claimed; claimed transaction IDs prevent checkpoint reload duplication.

Run the complete acceptance suite with:

```powershell
godot.cmd --headless --path . --script res://tests/phase9/phase9_acceptance.gd
```

## Milestone retrospective

- Version: `0.9.0`; save schema: `9`; content schema remains resource-driven.
- The original Phase 8 direct JSON snapshot was replaced by a checksummed envelope because integrity cannot be established after a partial write without independently validating the payload.
- Backup rotation intentionally keeps both `.previous` and `.recovery`; invalid generations remain available for diagnostics instead of being deleted.
- Schema migration is registry-based and preserves both unknown fields and an untouched pre-migration file. Missing optional content remains unresolved data; missing equipped content blocks loading with a recovery report.
- Checkpoint rewards stay pending and retain the original run transaction ID, closing reload-based duplication.
- Automated verification covers forced/interrupted writes, corrupt generations, migration, removed and renamed content, profiles, checkpoint round trips, New Game Plus, and reward idempotency.
- Known limitation: Phase 10 must connect authored midpoint and pre-boss stage events to `GameSession.create_checkpoint()`; Phase 9 supplies and tests the persistence contract.
