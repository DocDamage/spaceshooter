# Phase 2 Production Architecture

## Boundary

All new runtime code lives under `res://production`. The migrated Phase 1 implementation lives under `res://legacy` and is reference-only; production actors do not call its autoloads or scripts.

## Boot and dependency flow

`production_boot.tscn` is the project entry point. `ProductionServices` initializes the content database and services, then the boot creates a `GameSessionConfig`, configures a `GameSession`, and activates the mission. Runtime nodes follow a constructor-like pattern: call `configure(...)` before adding the node to the active scene tree.

Leaf actors receive only the dependencies they use: definitions, the session `ActorRegistry`, the `TypedEventBus`, and (for players) `GameInputService`. They do not search the tree, access UI scenes, or use the global service hub.

## Content

`ContentDatabase` recursively scans registered directories for `ContentDefinition` resources, indexes them by `stable_id` and content type, validates duplicates and missing dependency IDs, and records version metadata. Registration order is irrelevant. Runtime access returns definitions without exposing the mutable index. Development tools may call `reload()` when no active content references would be invalidated.

Initial content proves the required resolution path:

- `mission.architecture_test`
- `ship.vanguard`
- `weapon.pulse_cannon`
- `enemy.scout`

## Global services

Services expose small APIs and report errors through `BaseGameService.service_error`. They initialize in this order: settings, platform, localization, input, audio, profiles, saves, achievements, scene routing, game flow, diagnostics. Content validation precedes all services.

The hub owns game flow, scene routing, settings, input, profiles, saves, audio, localization, achievements, platform abstraction, and diagnostics. These are initial local implementations designed to preserve their API boundaries when platform SDKs and persistent storage arrive later.

## Session scope

`GameSession` owns mission, reward, objective, checkpoint, and completion state. It also owns two scoped collaborators:

- `ActorRegistry`: stable-ID cached references for players, wingmen, enemies, bosses, projectiles, pickups, and hazards.
- `TypedEventBus`: typed payload dispatch. Payloads always require a stable source ID and carry a stable target ID where applicable.

Session configuration includes mission definition, profiles, ships, loadouts, difficulty, seed, mode rules, and multiplayer configuration. No registry changes are needed to add another local player.

## Diagnostics and development mode

`development/enabled` and `development/diagnostics_visible` are project settings. The F3 overlay reports FPS, frame time, actor/effect counts, pool occupancy, mission seed, segment, waves, difficulty, memory estimate, save status, and warnings. Build version comes from `application/config/version`.

## Validation

Run from the repository root:

```powershell
godot --headless --path project --script res://tests/phase2/phase2_acceptance.gd
```

The acceptance harness validates stable-ID loading, content versioning, duplicate detection, service initialization, typed events, MissionDefinition launch, two-player registration, active diagnostics, checkpoint creation, rewards, completion, and save status.
