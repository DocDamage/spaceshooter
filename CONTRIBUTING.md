# Contributing to Galax Hero

## Local setup

1. Install Godot 4.7.1 and its Windows export templates.
2. Install Git LFS and run `git lfs install` once.
3. From this directory, run `pwsh -File tools/run_project.ps1 verify`.
4. Run `pwsh -File tools/run_project.ps1 all` before requesting review.

## Change rules

- Production runtime code belongs under `production/`; `legacy/` is reference-only.
- Stable content IDs are save-data and network protocol. Rename them only through an explicit migration.
- Add or change content through definitions/resources and validate it with deterministic seeds.
- Runtime assets must be approved in the asset catalog and copied into `assets_runtime/` through the asset pipeline.
- Tests must free every Node they create and remove temporary `user://` data before exiting.
- Never commit `.godot/`, exported executables, PCKs, crash dumps, or ad-hoc captures.
- A system is not complete until it is reachable from the shipping UI and exercised by a runtime or manual test.

## Review evidence

Describe the player-visible outcome, tests run, affected stable IDs/save schemas, performance impact, accessibility behavior, and any asset/license records added.
