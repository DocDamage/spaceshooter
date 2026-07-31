# Stage Content Checklist Template

Use one copy per stage. A checkbox means the item was observed in a current runnable export, not merely represented by a data class or isolated unit test.

## Identity and ownership

- Stage ID / display name:
- Operation / stage number:
- Content owner:
- Gameplay, art, audio, narrative, QA reviewers:
- Seed review set:
- Target first-clear and expert times:
- Last verified version/content revision:

## Playable contract

- [ ] Menu/campaign entry, loadout, difficulty, solo, and two-player local launch paths work.
- [ ] Mission-specific roster, factions, formations, objectives, hazards, branches, checkpoints, miniboss, and boss execute in runtime.
- [ ] Every encounter has a timeout/escape/deadlock recovery rule.
- [ ] Win, death, objective failure, restart, checkpoint resume, abandon, replay, and next-stage paths work.
- [ ] Score, chain, rank, XP, credits, drops, equipment, unlocks, and reward idempotence are visible and correct.
- [ ] Checkpoint/save reload preserves the intended deterministic state and schema migrations remain compatible.

## Authored content

- [ ] Beat sheet has timestamps, teaching goals, intensity, cooldowns, route choices, and recovery points.
- [ ] At least three reviewed encounter seeds are distinct, safe, bounded, and use the intended roster.
- [ ] Objective and hazard interactions have success/failure feedback and do not rely on placeholder nodes.
- [ ] Miniboss/boss phases, telegraphs, parts, summons, arena rules, rewards, and practice entry are reviewed.
- [ ] Briefing, radio, objective, boss, failure, result, decision, and codex prose are edited in context.

## Presentation and accessibility

- [ ] All runtime art is approved, manifest-linked, coherent with the art bible, and free of programmer placeholders.
- [ ] Music states and gameplay/UI SFX are mixed on the correct buses with voice limits and no missing-audio events.
- [ ] HUD shows health, shield, resources, loadout state, score/chain, objectives, warnings, boss, and co-op state inside safe margins.
- [ ] Keyboard/mouse and controller prompts, navigation, pause, reconnect, and focus order work.
- [ ] Reduced motion/flash, high contrast, color-safe cues, auto-fire, simplified patterns, speed assistance, vibration/shake, text speed, UI scale, and dynamic range are verified.
- [ ] No essential meaning depends only on color, audio, flash, fine motor timing, or small text.

## Quality gates

- [ ] Static/content validation, all acceptance suites, flow tests, and export smoke pass with no leak diagnostics.
- [ ] 30-minute soak shows no growing active/pool count, deadlock, error, or memory trend outside the budget.
- [ ] Debug and release exports contain only approved runtime assets and release diagnostics are disabled.
- [ ] Minimum-spec 60 FPS, frame-time, memory, loading, save, and build-size budgets pass with retained evidence.
- [ ] Clean-machine install/run/uninstall and supported display/controller matrix pass.
- [ ] Human playtest matrix passes; issues and tuning changes are linked.

## Sign-off

- Gameplay:
- Art:
- Audio:
- Narrative:
- Accessibility:
- QA/export:
- Accepted risks/known issues:
- Rollback artifact:
