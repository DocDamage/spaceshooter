# Changelog

All notable player-visible and release-engineering changes are recorded here. Versions follow semantic versioning; save schema, content revision, and network protocol versions are tracked independently.

## [Unreleased]

### Added

- End-to-end completion and release-hardening work based on the 2026-07-31 execution plan.
- Reproducible verification/export runner, pinned CI, release preset, repository policy, and product ADRs.

## [0.20.0] - 2026-07-31

### Added

- A complete executable Stage 1 path with mission-aware multi-wave encounters, regular-enemy combat, objectives, hazards, branches, miniboss and boss gates, visible drops, scoring, failure, checkpoint, and result flows.
- Player-selected primary, secondary, heavy, spell, melee, super, ship, progression, and wingman systems in the real generated mission.
- Shipping menu destinations for campaign, modes, hangar/progression, inventory, skills, upgrades, codex, profiles, settings/accessibility, credits, and the deliberately closed online release gate.
- Approved Stage 1 player/enemy/background/VFX/music/SFX assets, an owner-attestation record, art bible, beat sheet, content checklist, and runtime license validation.
- Phase 20 end-to-end acceptance coverage and an accelerated 30-minute Stage 1 replay soak with actor, pool, memory, deadlock, error, and shutdown-leak gates.

### Fixed

- Unsafe collision-state changes during physics callbacks, stale pooled-formation signals, boss phase typing, miniboss targeting, display-mode mapping, and detached pooled-effect leaks.

## [0.19.0] - 2026-07-31

### Added

- Sixty-stage campaign architecture through Phase 19.
- Local and online cooperative foundations, alternative modes, save recovery, progression, bosses, and content validation.

### Known limitations

- Phase acceptance covered isolated contracts more completely than the real shipping loop.
- Runtime integration, final presentation, hardware/network validation, and release packaging remained incomplete at this baseline.
