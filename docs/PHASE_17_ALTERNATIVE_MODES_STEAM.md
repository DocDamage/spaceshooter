# Phase 17: Alternative Modes, Difficulty, and Steam Foundation

Phase 17 adds a data-driven `ModeDefinition` and catalog for Arcade, Score Attack, Boss Rush, Survival, Endless, Time Attack, and Training. `ModeRunController` owns mode-only lives, continues, chain scoring, timers, penalties, deterministic seeds, survival caps, assist metadata, and result construction. Its results expose no campaign mutations; rewards are opt-in per mode.

`LocalLeaderboard` requires every entry to record effective difficulty and active assists. `ChallengeService` derives deterministic daily and weekly definitions from a period bucket and content revision, saves the exact definition, and preserves local best-result history. `TrainingController` exposes invulnerability, infinite resources, encounter/formation/boss/phase selection, projectile practice, damage numbers, hitboxes, speed control, and reset while permanently disabling rewards.

`DifficultyController` combines the master slider, named presets, granular overrides, bounded dynamic adjustment, mode policy, and assist metadata. Projectile speed, encounter density, and enemy damage are clamped after overrides so generated encounters cannot exceed authored safety ceilings.

`PlatformService` is the platform-agnostic boundary for achievements, cloud comparison, rich presence, invitations, identity, overlay state, Steam Input capability, and glyph selection. It probes the optional Steam singleton at runtime and always retains standalone/offline behavior. Differing cloud payloads create a conflict that must be explicitly resolved as local, remote, or keep-both; revision numbers never silently authorize overwrite. `AchievementService` deduplicates locally before forwarding to the provider.

Run acceptance coverage with:

```powershell
godot.cmd --headless --path . --script res://tests/phase17/phase17_acceptance.gd
```
