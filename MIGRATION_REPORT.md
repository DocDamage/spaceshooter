# Godot 4.7.1 Migration Report

## Baseline

- Target engine: Godot 4.7.1 stable (`a13da4feb`)
- Donor: `Firstject/godot-space-rpg`
- Donor revision: `625ef7cc64f54c96d48917101cf7347263ccb5e3`
- Preserved compatibility runtime: `res://legacy`
- Untouched donor clone: `../legacy/godot-space-rpg`
- Raw automated conversion: `../legacy/godot-space-rpg-godot4-raw`

The workspace did not contain the Phase 0 donor snapshot or repository metadata. The named public donor was retrieved to make Phase 1 reproducible. This prerequisite gap should be resolved before normal branch-based production work begins.

## Conversion result

Godot's official `--validate-conversion-3to4` and `--convert-3to4` operations were run against all 141 recognized donor project files. The converter reported 141 files converted. Full logs are in `migration_logs/`.

The raw conversion cannot form a stable active project because the donor repository omits many original image/audio sources and retains only Godot 3 `.import` metadata that points at unavailable `.stex` files. Godot 4 cannot recreate those resources, and its import process terminates while processing this incomplete set.

## Compatibility strategy

The migration build preserves the donor's seven autoload names and restores the smallest required gameplay path with Godot 4-native scripts and generated vector visuals. As of Phase 2, this behavioral reference is isolated under `res://legacy`; the project entry point and all new gameplay use `res://production`.

Restored behavior:

- splash and menu flow
- stage load and player spawn
- eight-direction keyboard/controller movement
- primary firing
- timed enemy spawning and enemy fire
- projectile collision and damage
- shield absorption with hull overflow
- player death and game-over flow
- experience gain and level-up
- currency rewards
- stage completion

## Project settings repaired

- `config_version=5`
- Compatibility renderer
- 540×960 portrait viewport with aspect-preserving canvas stretch
- nearest-neighbor 2D texture defaults and pixel snapping
- keyboard and controller actions
- four named collision layers
- main scene
- Windows debug export preset

## Temporary adapters

- `AudioCenter`: safe silent facade because donor sound sources are unavailable
- `BattleServer`: battle counters and compatibility signals
- `EnemySpawnerData`: legacy migration wave provider
- `LevelServer`: stage lifecycle facade
- `LevelGUI`: HUD/message signal facade
- `Currency`: runtime credit counter
- `GameServer`: migration flow state

## Known divergences and replacement list

- Generated vector visuals replace donor sprites in the required path.
- Audio calls are intentionally silent.
- The original theme/font resources are not loaded.
- Touch controls, satellites, modules, and superpowers are outside the Phase 1 acceptance path.
- Compatibility autoloads remain registered only so the legacy smoke path stays reproducible. Production code uses the Phase 2 service hub and has no references to them.
- The compatibility stage is behavioral, not content- or balance-equivalent.

## Validation

Run from this directory:

```powershell
godot --headless --path . --import
godot --headless --path . res://tests/smoke/phase1_smoke.tscn
godot --headless --path . --quit-after 180
godot --headless --path . --export-debug "Windows Desktop (Debug)" builds/galax-hero-phase1-debug.exe
```

The exported executable uses only resources under this project and writes no persistent data. `user://` remains available for later save work.

Final automated result: import `0`, smoke `0`, runtime `0`, Windows debug export `0`. The exported executable was launched independently, remained responsive for the launch probe, and was then closed by the validation command.
