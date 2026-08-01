# Galax Hero Player Manual

This manual applies to version 0.20.0. Galax Hero is a portrait arcade shooter with a 60-stage campaign, persistent progression, solo play, two-player local co-op, and eleven local modes. Online co-op is not part of the 1.0 promise and remains visibly gated.

## Start and save

Choose or create a local pilot profile, open **Campaign Map — Operations 1–6**, choose a ship and loadout, then launch an available stage. Profiles, settings, checkpoint state, rewards, campaign decisions, local leaderboards, and achievement state save locally. The game also keeps two prior valid save generations. Do not close the game while the save indicator is active.

Campaign stages unlock in order. Completed stages can be replayed. Rewards use transaction IDs, so retrying a result cannot grant the same reward twice. Checkpoints preserve route, objective, participant, temporary-upgrade, reward, story, and boss state.

## Default controls

| Action | Keyboard | Controller |
|---|---|---|
| Move | WASD or arrow keys | Left stick |
| Primary fire / confirm | Space or K | South / A / Cross |
| Secondary / cancel | J or Escape where shown | East / B / Circle |
| Pause / start | Enter | Start / Menu |
| Select | Backspace | Back / View |
| Development diagnostics | F3 | Development builds only |

The **Settings → Bindings** page shows the authoritative current bindings, detects conflicts, and permits rebinding. Input prompts change with the active device. Menus remain keyboard- and controller-focusable.

Combat loadouts can include primary, secondary, and heavy weapons; a spell; melee/parry; a shield; a super mode; equipment; skills; and an optional wingman. The HUD shows health, shields, objectives, score chain, boss state, co-op state, warnings, and route choices. A stage can be won, failed, retried, resumed from a valid checkpoint, abandoned, or replayed.

## Local co-op

Choose **Local Co-op (2 Players)** on the campaign or an allowed mode. Assign two distinct connected devices, choose Player 2’s guest or local profile and ship, then mark Player 2 ready. The game will not launch while both players share one device. Co-op uses camera tethering, down/revive rules, participant-aware checkpoints, player attribution, and host-profile campaign progression. Guest progress is not persisted as a separate profile.

## Modes

The Modes page provides Arcade, Score Attack, Time Attack, Boss Rush, Boss Practice, Survival, Endless, Daily Challenge, Weekly Challenge, Mutator, and Training. Mode runs isolate campaign rewards and progression where their rules require it. Training supports encounter selection, boss phases, infinite resources, invulnerability, hitbox display, damage numbers, and speed control.

## Accessibility

Open **Settings → Accessibility** before or during play. Available controls include text scale, subtitles and subtitle background, reduced flash, motion, shake, particles, game-speed assistance, aim assistance, auto-fire/toggle behaviors, simplified patterns, color modes, vibration categories, and volume/dynamic-range controls. Important states use text, shape, motion, or position in addition to color. A photosensitivity warning appears on the main menu.

Galax Hero includes a pseudolocale and RTL audit mode for development/layout review. English is the shipping language until an accountable localization owner approves another locale.

## Support and privacy

**Support & Diagnostics** can create an opt-in privacy-safe JSON report. No analytics or crash report is uploaded automatically. The report excludes profile names, save contents, credentials, account tokens, and IP addresses. See `TROUBLESHOOTING_AND_RECOVERY.md` before changing save files.

