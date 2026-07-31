# Build and Verification

## Requirements

- Windows 10 or 11 x64
- Godot 4.7.1 stable with Windows Desktop export templates
- PowerShell 7 or Windows PowerShell 5.1
- Python 3.10 or newer for asset-pipeline validation
- Git 2.40+ and Git LFS 3+

The runner rejects a different Godot version so local and CI results stay comparable.

## Commands

Run these from the project root:

```powershell
pwsh -File tools/run_project.ps1 import
pwsh -File tools/run_project.ps1 test
pwsh -File tools/run_project.ps1 boot
pwsh -File tools/run_project.ps1 assets-source
pwsh -File tools/run_project.ps1 export-debug
pwsh -File tools/run_project.ps1 export-qa
pwsh -File tools/run_project.ps1 export-demo
pwsh -File tools/run_project.ps1 export-rc
pwsh -File tools/run_project.ps1 export-release
pwsh -File tools/run_project.ps1 export-smoke
pwsh -File tools/run_project.ps1 package-release
pwsh -File tools/run_project.ps1 verify
pwsh -File tools/run_project.ps1 all
```

`verify` runs import, metadata, asset/artifact, Python pipeline, all acceptance, and headless boot checks. `assets-source` additionally requires the external editable library to be mounted. `all` adds the Stage 1 soak, Development and Release exports, waited executable smokes, and the release package/SBOM under `builds/`.

## Release configuration

- Development and QA profiles retain diagnostic tooling; Demo, Release Candidate, and Release use release templates.
- Demo, Release Candidate, and Release exclude tests, tools, documentation, source-only art, legacy reference code, and internal lab scenes. The runner fails if the export log packs them.
- Runtime diagnostics are enabled only when `OS.is_debug_build()` is true.
- Set `GALAX_HERO_SIGNING_THUMBPRINT` to a certificate in the Windows certificate store and optionally `GALAX_HERO_SIGNTOOL` to `signtool.exe`. Run the RC/Release task with `-RequireSignature`; unsigned artifacts are labeled test-only and must never be published as final.
- Every export receives a SHA-256 and build record. Release packaging also creates `release-manifest.json`, `sbom.spdx.json`, a versioned ZIP, and a ZIP checksum.

## Clean checkout gate

On a clean machine: clone, run `git lfs pull`, install Godot/export templates, run `tools/run_project.ps1 all`, verify a fresh profile and physical controller through `docs/MANUAL_QA_MATRIX.md`, and retain checksums plus logs with the build artifacts. Public distribution additionally requires `export-release -RequireSignature` and the signed-build checks in `docs/RELEASE_RUNBOOK.md`.
