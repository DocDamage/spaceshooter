# Phase 10 — Stage Segments, Procedural Assembly, Objectives, and Tools

Phase 10 replaces one-off mission scene assembly with deterministic, resource-authored stage plans. `MissionDefinition` points to a `MissionRecipeDefinition`; the graph generator combines its required sequence, optional pool, branch pool, repetition rules, difficulty bounds, and ordered checkpoint requirements into a replayable `StagePlan`.

The sample library under `res://production/content/data/segment/` covers opening, standard and formation combat, hazards, turret corridors, asteroid and debris fields, elites, rescue, escort, sabotage, survival, branches, secrets, checkpoints, minibosses, pre-boss staging, bosses, and exits. Segments compose existing Phase 7 waves and formations, objective and secret definitions, hazards, background layers, connectors, safe spawns, multiplayer clearance, and projectile-budget estimates.

`StageValidator` rejects missing nodes, connector mismatches, invalid resources, insufficient local multiplayer clearance, missing or misordered checkpoints, and any non-intentional route that terminates before the boss and exit. Validation returns error, warning, and information channels. Generation uses named deterministic random streams and stores per-node seeds, so a plan can be reproduced exactly without blocking gameplay.

`StageRuntime` loads and unloads segment runtimes, schedules waves, registers objectives and secrets, activates hazards/background metadata, and advances the generated route. The production launch uses `GeneratedMission`, which creates players, routes generated wave requests into production enemies, and completes the session when the stage exits.

Midpoint and pre-boss segment completion now call `GameSession.create_checkpoint()` automatically. Checkpoints include the complete stage plan, seed, visited route, cleared segments, next segment, route choices, safe spawn, local participants, objective/secret state, temporary upgrades, and pending rewards. Phase 9 atomic persistence and reward-idempotency guarantees remain unchanged.

The runtime preview at `res://production/stages/stage_preview.tscn` generates several seeds and displays nodes, edges, objectives, projectile budgets, and validation output. `MissionEditor` supplies the minimum create/assign/preview/validate/save authoring workflow without requiring a bespoke master scene.

Run the complete acceptance suite with:

```powershell
godot.cmd --headless --path . --script res://tests/phase10/phase10_acceptance.gd
```

## Milestone retrospective

- Version: `0.10.0`; save schema remains `9` because Phase 10 extends checkpoint payloads with backward-compatible optional fields.
- Stage selection, node seeds, and branch selection use isolated named random streams so adding one random consumer does not perturb unrelated systems.
- Authored required sequences guarantee pacing landmarks while optional compatible segments provide replayable variation.
- Phase 9 checkpoint persistence is now connected to real midpoint and pre-boss stage events.
- The minimum editor is intentionally an authoring API plus preview screen; a richer Godot editor dock can build on the same validated resources later.
- Automated verification covers all Phase 10 exit-gate requirements and the production boot is smoke-tested headlessly.
