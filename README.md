# Galax Hero

Galax Hero is a portrait-format arcade space shooter with a 60-stage campaign, solo and two-player local play, persistent ships/loadouts/progression, bosses, branching routes, accessibility assists, and eleven local challenge/training modes. Open `project.godot` with Godot 4.7.1 and run the project.

The shipping entry point is `res://production/boot/production_boot.tscn`. Online co-op remains a deliberately closed post-launch gate and is not part of the 1.0 promise.

Phase implementation notes live in `docs/`, including `PHASE_5_ACTOR_COMBAT_FOUNDATION.md` for actor lifecycle, movement states, deterministic damage, shields, armor, subsystem damage, and statuses.

- Move: WASD, arrow keys, or left stick
- Fire: Space, K, or controller A
- Diagnostics overlay in Development builds: F3

Run `pwsh -File tools/run_project.ps1 verify` for the full source-tree gate, or `pwsh -File tools/run_project.ps1 all` for verification, soak, Development/Release exports, executable smokes, checksums, manifest, SPDX SBOM, release archive, versioned Windows installer, clean install smoke, and uninstall smoke. See `BUILDING.md`, `docs/PLAYER_MANUAL.md`, `docs/DEVELOPER_SETUP_ARCHITECTURE_AND_CONTENT.md`, and `docs/RELEASE_RUNBOOK.md`.

The Phase 1 compatibility implementation is isolated under `res://legacy` as a behavioral reference. New runtime work belongs under `res://production` and must use the production services and session boundaries.

See `docs/PHASE_2_ARCHITECTURE.md` for dependency flow and service APIs. See `docs/PHASE_3_ASSET_PIPELINE.md` for the searchable asset catalog, safe conversion/approval workflow, import profiles, content templates, and validation commands. See `MIGRATION_REPORT.md` for the preserved Phase 1 migration record.

Phase 7 adds resource-authored enemies, movement and attack libraries, formations, waves, fixed elites, deterministic drops, difficulty scaling, pooling, and a 20-entry starter roster. See `docs/PHASE_7_ENEMIES_FORMATIONS.md` and open `res://production/enemies/enemy_laboratory.tscn` for the interactive laboratory.

Phase 8 adds persistent level 1–99 profiles, stat allocation, equipment inventory and presets, permanent weapon/spell upgrades, five data-driven skill trees with safe respec, temporary mission upgrades, one-time mission rewards, a results screen, atomic saves, and economy reports. See `docs/PHASE_8_RPG_PROGRESSION.md` and run `godot --headless --path . --script res://tests/phase8/phase8_acceptance.gd` for the acceptance suite.

Phase 9 hardens progression with profile-slot management, schema migration, checksummed atomic saves, rotating backups, explicit recovery diagnostics, content-ID reconciliation, and exact resumable checkpoints. See `docs/PHASE_9_SAVE_INTEGRITY.md` and run `godot.cmd --headless --path . --script res://tests/phase9/phase9_acceptance.gd`.

Phase 10 adds deterministic mission recipes and stage graphs, all 19 segment categories, segment/wave runtime orchestration, objectives, secrets, structural and multiplayer validators, midpoint and pre-boss checkpoint integration, seed replay, a stage preview, and a minimum mission-authoring API. See `docs/PHASE_10_STAGE_GENERATION.md` and run `godot.cmd --headless --path . --script res://tests/phase10/phase10_acceptance.gd`.

Phase 12 adds data-authored story/dialogue contexts, checkpoint-safe radio, campaign progression and map state, pilot selection data, multiplayer-compatible wingman slots and commands, codex unlocks, and persistent narrative state. See `docs/PHASE_12_STORY_CAMPAIGN_WINGMEN.md` and run `godot.cmd --headless --path . --script res://tests/phase12/phase12_acceptance.gd`.

Phase 13 adds reusable boss/miniboss actors, authored phase state machines, targetable parts, summon and arena control, a top-screen boss HUD, reusable challenge tracking, practice sessions, checkpoint snapshots, reward hooks, and behavioral New Game Plus variants. See `docs/PHASE_13_BOSS_MINIBOSS_FRAMEWORK.md` and run `godot.cmd --headless --path . --script res://tests/phase13/phase13_acceptance.gd`.

Phase 14 integrates mission briefing/preflight data, a device-aware tutorial, a twelve-segment Stage 1 recipe with a secret branch, optional objective, two checkpoints, production miniboss and boss encounters, failure/resume flows, idempotent XP/currency/equipment rewards, replay, boss-practice unlock, persistence, accessibility checks, and performance telemetry. See `docs/PHASE_14_STAGE_1_VERTICAL_SLICE.md` and run `godot.cmd --headless --path . --script res://tests/phase14/phase14_acceptance.gd`.

Phase 16 adds a stable two-player roster, device and guest-profile joining, disconnect recovery, shared-camera tethering, down/revive and lives state, participant-aware checkpoints, co-op rewards, wingman replacement rules, multi-axis difficulty scaling, and a color-coded multiplayer HUD. See `docs/PHASE_16_LOCAL_COOPERATIVE_MULTIPLAYER.md` and run `godot.cmd --headless --path . --script res://tests/phase16/phase16_acceptance.gd`.

Phase 18 completes the six-operation campaign with fifty additional authored stage recipes, operation-specific enemy rosters and environments, fifty executable miniboss attack decks, five three-phase operation bosses, 100 briefing/results dialogue resources, five persistent campaign decisions, five specialist ships, fifteen equipment-set pieces, spell unlock pacing, postgame rewards, and campaign-wide deterministic QA. See `docs/PHASE_18_FULL_CAMPAIGN.md`, `docs/phase18_campaign_qa_report.md`, and run `godot.cmd --headless --path . --script res://tests/phase18/phase18_acceptance.gd`.
