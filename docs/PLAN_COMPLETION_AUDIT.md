# End-to-End Plan Completion Audit

Updated 2026-07-31 for 0.20.0. This is the current evidence ledger for `PROJECT_END_TO_END_COMPLETION_AND_IMPROVEMENT_PLAN.md`; historical phase documents are not release declarations.

## Status definitions

- **Proven locally:** direct automated/runtime/export evidence passes in this repository.
- **Implemented, external sign-off pending:** the feature is reachable, but the plan requires human or representative-hardware evidence that cannot be honestly manufactured in source.
- **External gate:** requires an accountable owner, certificate, physical hardware, store account, legal approval, users, or live distribution.
- **Deferred by decision:** deliberately outside the 1.0 promise under an accepted ADR.
- **Post-launch:** support work starts only after a public release exists.

## Phase ledger

| Plan area | Status | Evidence and remaining gate |
|---|---|---|
| Phase 0 — truthful baseline | Proven locally, except hardware capture | Pinned Godot, Git history, artifact policy, one-command gates, release preset, ADRs, hashes and reports exist. Representative profiler/video baseline remains external. |
| Phase 1 — real gameplay runtime | Proven locally | Phase 20 runs real players, loadouts, enemies, projectiles, damage, drops, hazards, objectives, branches, boss systems, failure/checkpoints, score and modes in SceneTree. |
| Phase 2 — Gold Stage 1 | Implemented, external sign-off pending | Executable Stage 1, approved first-pass presentation/audio, HUD/tutorial/accessibility, failure/resume/results, leak-free integration, boot and accelerated soak pass. Human pacing/readability/fun, physical input/display, visible endurance, and minimum-spec profiling remain. |
| Phase 3 — asset/content pipeline | Proven locally | 4,788 catalog records, 50 approved derivatives, import profiles, approval/license/hash validation, reports, operation factories, templates and release rejection gates. |
| Phase 4 — Operation 1 Alpha | Implemented, external sign-off pending | Ten missions and stage contracts are structurally and executably integrated. Each stage still needs its completed human checklist and exported-build playtest. |
| Phase 5 — metagame, modes, accessibility, local co-op | Proven locally; hardware matrix pending | Shipping UI reaches campaign, hangar/progression, profiles, codex, settings, support, 11 modes and gated online page. Two-device and display/controller certification remain external. |
| Phase 6 — Operations 2–6 | Implemented, external sign-off pending | Fifty explicit narrative records, 50 missions/minibosses, five bosses, decisions with later echoes, specialist ships/art, equipment sets, distinct backgrounds/rosters and deterministic campaign QA pass. Individual balance/art/audio/fun sign-off remains. |
| Phase 7 — online co-op | Deferred by ADR 0003 | Protocol, authority, compatibility, transport and simulation lab exist. Public online is post-launch until the two-PC/two-network matrix passes. |
| Phase 8 — platform/build/legal/release | Local engineering implemented; external gates remain | Five exports, packed-executable smoke, ZIP, manifest, SBOM, checksums, versioned Inno installer and clean install/uninstall smoke are local gates. Certificate, selected provider, legal/ratings/store media/account approval remain external. |
| Phase 9 — alpha/beta/RC/launch | External gate | Requires human cohorts, defect triage, signed candidate, clean representative machines, approved storefront and live-download smoke. |
| Phase 10 — post-launch | Post-launch | Runbooks exist; monitoring, patch cadence and retrospective require a live release. |

## Cross-cutting ledger

Architecture boundaries, runtime integration, score/progression, objective/hazard visuals, operation backdrops, specialist/enemy silhouettes, UI theme assets, music lifecycle, authored narrative, decision consequences, atomic saves, recovery generations, achievement persistence, cloud-provider abstraction, privacy-safe diagnostics, and save/network allocation bounds are implemented and directly tested. The remaining cross-cutting work is evidence, not hidden code: final mix/editing, per-stage human approval, localization by native reviewers, minimum-spec profiling, fuzz campaign duration, physical controller/display coverage, certificate signing, legal review, storefront production, and support staffing.

## Final checklist truth

Automated evidence proves all 60 stages generate, validate, progress, checkpoint, reward, replay through controllers, and survive a full campaign save reload; it does not prove that 60 humans-approved experiences are balanced or fun. All local suites, source asset validation, boot, exports, packed smokes, packaging, and installer smoke must pass from the final clean commit. The release cannot be called Gold until every row in `MANUAL_QA_MATRIX.md` is signed, the final candidate is Authenticode-signed, legal/store material is approved, and the live store download is installed and smoke-tested.

Online co-op is not an incomplete 1.0 checklist item because ADR 0003 removes it from the approved launch scope. Any later marketing promise reopens its complete real-world matrix.

