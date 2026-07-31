# Release, Rollback, Hotfix, and Launch Operations

## Candidate production

Follow `RELEASE_RUNBOOK.md`. A candidate requires a clean reviewed commit/tag, matching version/content metadata, source-license evidence, the full `all` pipeline, valid executable/installer signatures, SHA-256 records, release manifest, SPDX SBOM, known issues, manuals, and retained prior known-good artifacts. Upload to a private channel first.

## Rollback

Retain the current and previous signed installers/ZIPs, hashes, manifests, SBOMs, symbols, source commit/tag, save-schema compatibility notes, CI logs, and completed matrices. A rollback restores the prior executable package but never downgrades or overwrites player saves. If the prior build cannot safely read the current schema, halt distribution and ship a forward-compatible hotfix instead.

## Hotfix

For a P0/P1 issue: stop promotion, preserve evidence, update the status notice, identify affected versions/data, and choose rollback or hotfix. Branch from the released tag. Add a direct regression test, migration and recovery behavior where data is involved, security/privacy review where trust boundaries change, and player-facing notes. Increment version/content/protocol/schema only as required, then repeat every release gate and sign a new artifact.

## Launch and support

Before public promotion, accountable owners approve price/date, ratings, legal notices, privacy/support contact, requirements, store questionnaires, screenshots, and trailer captured from the exact candidate. Download the live store artifact on a non-developer account, verify signature/hash, install, launch, create/load a profile, enter Stage 1, save, restart, export diagnostics, and uninstall/reinstall with saves preserved.

Launch monitoring must name a release owner, QA owner, support owner, security contact, escalation channel, status-page location, response targets, and rollback authority. Classify reports by version/build hash and never request credentials or public posting of diagnostics. Publish known issues and workarounds without claiming an unverified fix.

## Day-one decision points

- Crash, save loss, security/privacy exposure, progression deadlock, or installer failure: halt/rollback immediately.
- Severe controller/display/accessibility failure affecting a broad configuration: pause promotion and hotfix.
- Balance/editorial issue without progression loss: document, triage, and patch through the normal candidate path.
- Online/store provider failure: preserve standalone offline operation; disable the provider feature rather than blocking boot.

