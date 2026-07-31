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
pwsh -File tools/run_project.ps1 export-debug
pwsh -File tools/run_project.ps1 export-release
pwsh -File tools/run_project.ps1 verify
pwsh -File tools/run_project.ps1 all
```

`verify` runs import, metadata, asset/artifact, Python pipeline, all acceptance, and headless boot checks. `all` additionally produces debug and release executables under `builds/`.

## Release configuration

- Debug preset includes diagnostic tooling and a console wrapper.
- Release preset excludes tests, tools, documentation, source-only assets, and legacy reference code.
- Runtime diagnostics are enabled only when `OS.is_debug_build()` is true.
- Signing is an explicit release-owner step through `GALAX_SIGNING_IDENTITY`; unsigned artifacts must never be published as final.

## Clean checkout gate

On a clean machine: clone, run `git lfs pull`, install Godot/export templates, run `tools/run_project.ps1 all`, launch both outputs, verify a fresh profile and controller, and retain checksums plus logs with the build artifacts.
