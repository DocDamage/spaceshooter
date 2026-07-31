# Release Runbook

This runbook produces the standalone Windows x86_64 artifact defined by ADR 0007. A CI or local output is not a public release until the signature and manual gates below are complete.

## 1. Prepare

1. Start from a clean reviewed commit and an annotated `vMAJOR.MINOR.PATCH` candidate tag.
2. Confirm `VERSION`, `CONTENT_REVISION`, `project.godot`, `CHANGELOG.md`, `KNOWN_ISSUES.md`, and `THIRD_PARTY_NOTICES.md` agree.
3. Install Godot 4.7.1 stable plus its 4.7.1 Windows export templates, Python 3.10+, Git, and Git LFS.
4. Mount the external `../assets` source library and run `pwsh -File tools/run_project.ps1 assets-source` to archive source/license/hash evidence.
5. Run `pwsh -File tools/run_project.ps1 all`. Do not continue after any error, warning classified by the runner, leak diagnostic, missing pass marker, forbidden packed path, or checksum failure.

## 2. Sign the candidate

Install the organization’s Windows code-signing certificate in the current-user or machine certificate store. Never place certificates or secrets in the repository.

```powershell
$env:GALAX_HERO_SIGNING_THUMBPRINT = "<certificate SHA-1 thumbprint>"
$env:GALAX_HERO_SIGNTOOL = "C:\Program Files (x86)\Windows Kits\10\bin\<version>\x64\signtool.exe"
pwsh -File tools/run_project.ps1 export-rc -RequireSignature
pwsh -File tools/run_project.ps1 export-release -RequireSignature
pwsh -File tools/run_project.ps1 export-smoke
pwsh -File tools/run_project.ps1 package-release
```

Confirm `Get-AuthenticodeSignature builds/release/galax-hero-release.exe` reports `Valid`. Recompute the package after signing; signing changes the executable hash.

## 3. Certify on clean machines

Copy only the versioned release ZIP and its `.sha256` to a clean minimum-spec PC and a mid-tier PC. Verify the ZIP hash before extraction. Complete every applicable row in `MANUAL_QA_MATRIX.md`, including first run, profile creation, Stage 1, controller navigation, save/restart, diagnostics export, offline startup, repair/re-extract, upgrade from each supported save schema, uninstall/reinstall with preserved saves, and rollback to the retained known-good build.

The release package is portable; “install” means extract to a user-selected folder. Uninstall removes that folder. Saves remain in Godot’s per-user Galax Hero data directory unless the player explicitly deletes them.

## 4. Retain and publish

Retain together:

- signed executable and versioned ZIP;
- executable/ZIP SHA-256 files;
- `release-manifest.json` and `sbom.spdx.json`;
- CI logs, automated reports, source-license evidence, and completed manual matrix;
- current and previous known-good signed packages for rollback;
- symbols available from the matching pinned export template/build environment;
- approved store metadata, screenshots/trailer, ratings, legal review, and support contact.

Upload to a private candidate channel first. Download that exact store artifact on a non-developer account, verify its checksum/signature, and repeat the launch/profile/Stage 1/save smoke before promotion.

## 5. Rollback and hotfix

If a P0/P1 issue appears, halt rollout, preserve diagnostics, publish the known-issue notice, and restore the previous known-good package. Never downgrade or overwrite player saves. A hotfix branches from the released tag, adds a regression test and migration/rollback note, passes this entire runbook, increments version/content identifiers as appropriate, and is signed as a new artifact.
