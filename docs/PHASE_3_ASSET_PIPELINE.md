# Phase 3 Asset Pipeline

## Boundary and safety

The top-level `assets` directory is the preserved source library. The pipeline reads it but never renames, deletes, or overwrites it. Generated catalog output lives in `project/tools/asset_catalog/generated`; conversion work goes to an explicitly selected output folder; only reviewed assets are copied into `project/assets_runtime`.

The manifest uses stable IDs and records source/runtime paths, hashes, duplicate links, dimensions, animation metadata, faction, category, role, scale, collision/anchor guidance, layer, license evidence, approval status, import profile, and content-definition links. A nearby `license.txt` is discovered by walking toward the source root. Discovery makes the status visible; an asset is copied only when its catalog override explicitly marks it approved and the license classifier permits commercial use.

## Commands

Run from `project`:

```powershell
python tools/asset_catalog/asset_pipeline.py doctor
python tools/asset_catalog/asset_pipeline.py inventory
python tools/asset_catalog/asset_pipeline.py approve
python tools/asset_catalog/asset_pipeline.py search pirate enemy standard_fighter
python tools/asset_catalog/asset_pipeline.py validate --release
godot --headless --path . --script res://tests/phase3/phase3_acceptance.gd
```

Open `tools/asset_catalog/generated/catalog.html` for the searchable thumbnail view. `manifest.json` is the machine-readable catalog, while `atlas_candidates.json` groups four or more same-size PNGs sharing a category and import profile. Candidates are suggestions; atlas construction remains an explicit authoring decision.

Convert source formats into a disposable conversion directory:

```powershell
python tools/asset_catalog/asset_pipeline.py convert "../assets/EPS/UFO_Game_Sprites.eps" --output tools/asset_catalog/conversion_work
python tools/asset_catalog/asset_pipeline.py convert "../assets/PSD/meteor.psd" --output tools/asset_catalog/conversion_work
python tools/asset_catalog/asset_pipeline.py convert "../assets/SCML/example.scml" --output tools/asset_catalog/conversion_work
python tools/asset_catalog/asset_pipeline.py convert-batch "../assets/EPS" --formats eps --output tools/asset_catalog/conversion_work/eps
```

EPS needs ImageMagick or Inkscape. PSD composite extraction needs Pillow; selected named layers additionally need `psd-tools`. SCML import preserves referenced frames and emits animation-name metadata. Optional dependencies fail with an actionable message and never alter source files. Generated outputs also refuse overwrite unless `--force` is supplied; approved runtime copies refuse to overwrite different bytes under all circumstances.

## Approval workflow

1. Inventory the archive.
2. Search/filter the catalog and review the source plus its license evidence.
3. Add a curated override to `catalog_config.json`, including normalized runtime path, role, scale, animation details where relevant, `import_status: approved`, and any content-definition links.
4. Regenerate the catalog, run `approve`, allow Godot to import the copied file, and verify the generated settings against `import_profiles.json`.
5. Run release validation and the Phase 3 acceptance test.

Missing license information remains visible for source candidates but blocks an approved runtime asset. Export filters exclude tools, conversion work, and all source-authoring formats (`PSD`, `EPS`, `SCML`, `AI`, Aseprite, and FL Studio files).

## Content templates

Seven starter resources live under `tools/content_templates`: enemy, ship, projectile, background layer, portrait, UI theme asset, and effect. Copy a template into `production/content/data/<type>`, replace its stable ID and paths, then add the asset's stable ID/content link to the catalog override. Templates deliberately live outside the content database scan root so unfinished examples cannot ship as content.
