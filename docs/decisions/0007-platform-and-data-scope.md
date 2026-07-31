# ADR 0007: Standalone-First Platform Scope

- Status: Accepted
- Date: 2026-07-31

## Decision

The first supported artifact is a standalone Windows x86_64 build with offline profiles, local achievements, local leaderboards, and explicit save backup/recovery. A store provider may add identity, achievements, invites, and cloud saves through the existing platform boundary, but the game must boot and remain playable when that provider is absent or offline.

Cloud conflicts require an explicit local, remote, or keep-both choice. No player analytics leave the machine for 1.0. Crash reports are locally exportable and user-submitted; automatic upload requires a later privacy review and consent design. Secrets, tokens, signing identities, and provider credentials never enter the repository or game pack.

Release signing is required for public distribution. The signing identity is supplied by the release environment, and unsigned CI artifacts are labeled test-only.
