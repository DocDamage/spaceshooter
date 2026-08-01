# Changelog

All notable player-visible and release-engineering changes are recorded here. Versions follow semantic versioning; save schema, content revision, and network protocol versions are tracked independently.

## [Unreleased]

### Added

- End-to-end completion and release-hardening work based on the 2026-07-31 execution plan.
- Reproducible verification/export runner, pinned CI, release preset, repository policy, and product ADRs.
- Executable objective/hazard matrix, eleven specialized local modes, deterministic daily/weekly challenges, local co-op join/ready gating, and pseudolocalization/RTL layout audits.
- Project-owned application icon and 16:9 key-art master with machine-readable provenance.
- Player-triggered privacy-safe diagnostics export and Support & Diagnostics menu.
- Development, QA, Demo, Release Candidate, and Release profiles; exported profile/load/Stage 1 smokes; Authenticode hook; release manifest; SPDX SBOM; versioned ZIP and checksums.
- Fifty explicit Operation 2–6 narrative records with later decision echoes; five specialist hull visuals; distinct operation backdrops; expanded enemy, objective, hazard, pickup, projectile, and UI art; and a shared production theme.
- A project-owned eight-character comms portrait atlas, animated explosion frames, layered mission backdrops, reduced-motion parallax, and dedicated menu navigation cues.
- Bounded save/network parsers, sanitized profile/platform/transport text, provider-backed cloud document I/O, persistent achievement reconciliation, and restorable crossfaded music states.
- Deterministic Phase 22 resilience coverage for 1,024 network messages and 320 save documents, including type confusion, malformed input, checksum failure, and corrupt-file preservation.
- A four-hour simulated Stage 1 endurance gate plus three-candidate RC reproducibility reporting.
- Player/recovery manuals, developer/content guide, network/platform runbook, rollback/hotfix/launch plan, strict completion audit, and a versioned Inno Setup installer with clean install, repair, game, uninstall, reinstall, and final-uninstall smoke.

### Fixed

- Exported builds now resolve Godot `.tres.remap` entries during content discovery; previously the editor passed while disk-authored ships and enemies were absent after export.
- Legacy compatibility facades are isolated to the smoke harness and excluded from shipping exports.
- Phase 2 now tears down through one deterministic coroutine, eliminating an intermittent Godot native access violation after all assertions had passed.
- Network protocol and compatibility validation now rejects attacker-controlled type confusion before performing conversions.
- Profile creation, switching, and deletion now refresh the active campaign controller and reload the selected pilot's saved ship/loadout instead of retaining the previous pilot's choices.
- Saved UI scale and projectile-color selections now initialize correctly in newly created menus.
- Known settings are type-checked and bounded on load, while failed campaign/session preflight keeps a usable recovery menu available.
- The portrait playfield now renders through a fixed viewport instead of cropping into the square desktop window; the mission camera preserves the authored arena, backgrounds use their individual layers, diagnostics default off, radio no longer covers the player or briefing, and long menus scroll within a clean non-stretched theme.

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
