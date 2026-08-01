# Manual QA and Certification Matrix

Automated checks do not satisfy these rows. Record build hash, tester, UTC date, device/model, result, issue link, and evidence path for every pass.

Build version: ______  Content revision: ______  SHA-256: ______  Tester: ______

## Hardware and performance

| Configuration | Required evidence | Result |
|---|---|---|
| Minimum: Windows 10 22H2/11, 4 threads, 8 GiB, integrated DX11/OpenGL 3.3 GPU, 1280×720 | Cold start <10 s; stage transition <5 s; average 60 FPS/16.67 ms; worst gameplay frame <25 ms; peak memory <2 GiB | Pending |
| Mid: 16 GiB, GTX 1060/RX 580 class, 1920×1080 | Same metrics during Stage 1 boss and two-player effects peak | Pending |
| Compatibility: modern discrete GPU, 1440p and ultrawide | Stable scaling, no clipped UI, no unsafe playfield expansion | Pending |
| Endurance | 60-minute visible play/idle/mission loop; no crash, deadlock, runaway memory, audio loss, or controller loss | Pending |

## Display and input

Test 1280×720, 1920×1080, 2560×1440, 16:10, 4:3, 21:9, and portrait; windowed, borderless, and exclusive fullscreen; 100/125/150/200% Windows scaling. For each, inspect safe margins, focus, text scale, subtitle background, branch choice, HUD, pause, and results.

Test keyboard/mouse; wired and Bluetooth Xbox-layout, PlayStation-layout, and Nintendo-layout controllers; disconnect/reconnect; remapping conflicts; emergency Enter/Escape; keyboard+controller co-op; two-controller co-op. Play Stage 1 and every local mode with two physical players before local co-op can be certified.

## Gameplay and data

- Fresh profile: tutorial, Stage 1 success/failure/retry/checkpoint/replay, rewards, loadout effect, boss practice, and next-stage unlock.
- Campaign: each of 60 stages completed, failed, restarted, resumed, and replayed; every route/secret/objective/miniboss/boss/reward/decision recorded on its stage checklist.
- Modes: all eleven lifecycles, score/time/death penalties, continue exhaustion, challenge determinism, mutators, training options, and reward suppression.
- Saves: schemas 1–9 upgrade fixtures, checksum corruption, both recovery generations, reinstall preservation, rollback compatibility, offline operation, and power-loss simulation during save.
- Accessibility: every assist applied during gameplay, subtitles on/off/background, reduced motion/flash/shake/particles, color differentiation without color alone, 200% text, pseudolocale expansion, RTL mirror, and full keyboard/controller navigation.

## Release/platform/legal

- Valid Authenticode signature and matching manifest/checksums/SBOM.
- No tests, tools, docs, editable art, legacy facades, lab scenes, secrets, tokens, or unapproved runtime assets in the packed release.
- Clean extract/run/repair/uninstall/reinstall/upgrade/rollback on a non-developer account.
- Store provider absent/offline fallback; provider achievements/cloud/invites only if that provider is selected and separately certified.
- Credits, third-party notices, photosensitivity warning, privacy/support text, ratings, system requirements, screenshots, trailer, and store questionnaire approved by their accountable human owners.

Release approval: Product ______  QA ______  Accessibility ______  Legal ______  Release owner ______  UTC ______
