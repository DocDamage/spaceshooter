# Known Issues and Readiness

Status terms are intentionally strict:

- **Implemented:** code/data exists.
- **Integrated:** reachable in the real runtime.
- **Playtested:** exercised by a human on representative hardware.
- **Shipping-ready:** exported, clean-machine tested, licensed, supported, and within release gates.

| Area | Current status | Release consequence |
|---|---|---|
| Phase 2–19 architecture | Implemented; automated suites pass | Preserve APIs while completing runtime integration |
| Generated campaign combat | Integrated; automated end-to-end test and soak pass | Human balance/readability and representative-hardware validation remain |
| Stage hazards/objective actors | All ten objective types and all eight hazards are integrated and regression-tested | Human readability, balance, and physical-display review remain |
| Stage 1 presentation/audio | Integrated approved art/audio, objective/hazard/pickup/projectile visuals, operation backdrop, and shared UI theme | Final human mix, readability, pacing, and external playtest gates remain |
| Operations 1–6 | Integrated; Operations 2–6 have 50 explicit authored narrative records, distinct decision echoes, backdrops, specialist hull art, and expanded enemy silhouettes | Every stage still needs individual balance, art, audio, accessibility, and fun sign-off |
| Local co-op | Reachable with distinct-device, guest/profile, distinct-ship, and ready gating | Two-physical-device campaign/mode matrix remains before shipping-ready |
| Online co-op | Lab validated only | Post-launch beta until two-machine/network gates pass; do not market for 1.0 |
| Test lifecycle | 20 acceptance suites, isolated legacy smoke, boot, Stage 1 soak, and Development/Release executable smokes pass leak-free | Representative-hardware and human endurance passes remain |
| Platform/store | Standalone fallback, provider-injected cloud/achievement paths, five build profiles, ZIP/installer packaging, clean install smoke, SBOM, checksums, icon, and key art are implemented | Store provider certification, code-signing certificate, screenshots/trailer, and clean-machine owner sign-off remain |
| Legal/attribution | All 50 runtime assets resolve to reviewed CC0/commercial/project-owned records | Proof archival and final release-owner legal review remain required |

Update this file whenever an item crosses a readiness boundary. Passing a data-contract test alone may not advance it past **Implemented**.
