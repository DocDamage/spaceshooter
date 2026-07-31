# Developer Setup, Architecture, and Content Authoring

## Reproducible setup

Use Windows PowerShell, Git, Python 3.10+, Godot 4.7.1 stable with matching Windows export templates, and Inno Setup 6.7 or newer. The repository is the `project` directory. The licensed source library remains external at `../assets`; only approved derivatives under `assets_runtime` may ship.

Run `pwsh -File tools/run_project.ps1 import` after resource changes, `verify` for source gates, and `all` for the full local release pipeline. `all` performs import, metadata/artifact and asset validation, all acceptance suites, boot, accelerated soak, Development/Release exports, executable smokes, release packaging, installer construction, clean install smoke, and uninstall smoke.

## Runtime dependency flow

`ProductionBoot` owns front-end flow and creates a `GameSession`. `ServiceHub` initializes content, settings, platform, localization, input, audio, saves, profiles, story, achievements, routing, flow, and diagnostics in a fixed order. A `GameSessionConfig` carries mission, profiles, ships, loadouts, seed, difficulty, mode rules, and multiplayer configuration. `GeneratedMission` turns that configuration into actors, pools, objectives, hazards, story presentation, HUD, stage runtime, bosses, scoring, rewards, and checkpoints.

Production code is under `production`; compatibility code under `legacy` is not a shipping dependency. Stable IDs and resource definitions are the boundary between data and runtime. Services own platform/data concerns; actors do not reach directly into storage or providers. Online transport remains gated by ADR 0003.

## Authoring campaign content

Disk-authored `.tres` resources live under `production/content/data`. Operations 2–6 are expanded by `FullCampaignContentFactory`; their 50 explicit narrative records live in `production/content/data/campaign/full_campaign_authored_content.json`. Every stage requires a mission, recipe, campaign node, deterministic seed batch, enemy roster, miniboss, briefing, result, rewards, checkpoint route, and validation pass. Titles and narrative fields must be unique and editorially authored; factory placeholder phrases are rejected by Phase 21.

Use `docs/STAGE_CONTENT_CHECKLIST_TEMPLATE.md` for every human sign-off. Structural generation success does not certify balance, readability, pacing, or fun.

## Asset workflow

Run the catalog inventory before choosing assets. Add an explicit override in `tools/asset_catalog/catalog_config.json`, including stable ID, source path, normalized runtime path, role, import profile, license state, and definition links. Run `asset_pipeline.py inventory`, then `approve`; inspect the derivative and run `tools/run_project.ps1 assets-source` when the external library is mounted. Never copy a candidate directly into `assets_runtime` or change a license state to solve validation.

## Testing and performance

Acceptance suites layer data/unit checks with live SceneTree integration. Phase 20 exercises executable Stage 1 gameplay and the shipping menu. Phase 21 directly tests authored narrative, decision consequences, runtime art breadth, parser limits, cloud abstraction, achievement persistence, and audio state. Export smokes run the actual packed executable.

Automated timings and headless soaks detect regressions but do not certify GPU frame time. Minimum-spec profiling must record startup, stage transition, 99th-percentile frame time, worst hitch, checkpoint/result save duration, peak memory, projectile/enemy/effect ceilings, and a four-hour visible soak before Gold.

