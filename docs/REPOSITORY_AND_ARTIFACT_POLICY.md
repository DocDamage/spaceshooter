# Repository and Artifact Policy

## Boundary decision

The Git repository root is the runnable `project/` directory. It contains `production/`, the preserved `legacy/` reference, automated tests, tools, approved runtime derivatives, and project documentation.

The sibling `../assets/` directory is a multi-gigabyte editable/source library. It is intentionally external: it is cataloged by path and hash, but raw contents are not added to ordinary source history or game exports. The sibling `../legacy/` and `../docs/` directories are historical workspace material; the authoritative copies required to build are inside this repository.

## Large files

Editable source formats are tracked with Git LFS only when intentionally promoted into this repository. Optimized runtime PNG/OGG derivatives may use normal Git when small; any single binary over 10 MiB requires a review and normally uses LFS. Generated thumbnails remain tooling artifacts and are never exported.

## Build artifacts

`builds/` is ignored except for `.gitkeep`. CI retains versioned executables, PCKs, symbols, checksums, reports, and logs in the workflow artifact store. Published releases retain the previous known-good build for rollback. Executables must not be committed.

## Version identity

`VERSION`, `CONTENT_REVISION`, the save schema, and the online protocol together identify compatibility. CI checks that the first two match `project.godot`; release tags use `vMAJOR.MINOR.PATCH` and may point only at a verified, clean commit.

## History protection

The `main` branch should require review and the verification workflow. Release tags are annotated and immutable. Save-schema/content-ID migrations require test fixtures and rollback notes.
