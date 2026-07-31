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
| Stage hazards/objective actors | Integrated for the Stage 1 shipping path | Full objective/hazard matrix and human readability review remain |
| Stage 1 presentation/audio | Integrated approved first-pass assets | Additional bespoke objective/hazard/UI art, full mix pass, and external playtest gates remain |
| Operations 1–6 | Structurally generated | Every stage still needs distinct runtime/playtest sign-off |
| Local co-op | Reachable in campaign and supported modes | Join/ready UX and two-physical-device matrix remain before shipping-ready |
| Online co-op | Lab validated only | Post-launch beta until two-machine/network gates pass; do not market for 1.0 |
| Test lifecycle | 19 acceptance suites, legacy smoke, boot, and Stage 1 soak pass leak-free | Exported-build smoke and longer representative-hardware soak remain |
| Platform/store | Standalone fallback implemented | Store provider, cloud, achievements, signing, and clean-machine validation remain |
| Legal/attribution | All 22 runtime assets resolve to reviewed CC0/commercial records | Proof archival and final release-owner legal review remain required |

Update this file whenever an item crosses a readiness boundary. Passing a data-contract test alone may not advance it past **Implemented**.
