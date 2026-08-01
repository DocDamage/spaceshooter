# Stage 1 Beat Sheet — First Contact

Status: implementation baseline; human timing and comprehension sign-off remain required.

## Player promise

First Contact teaches the complete Galax Hero combat loop inside one readable frontier sortie: move, fire, focus through patterns, preserve a chain, use defenses and a spell, complete a rescue under pressure, recover at checkpoints, defeat a miniboss, then read and dismantle a multi-phase command ship.

Target first-clear duration is 8–12 minutes. An expert who kills formations before their escape timers and takes the direct route should finish faster. Encounter timing is deterministic for a given seed, difficulty, and player count.

## Beat timeline

| Target time | Segment | Teaching and pacing goal | Runtime gate | Presentation call |
|---:|---|---|---|---|
| 0:00–0:06 | Fleet Entry | Establish movement, portrait bounds, and forward-fire orientation in safety. | Six-second safe opening. | Briefing/radio entry, frontier planet layer, movement prompt. |
| 0:06–0:45 | Patrol Clash | Fire, target priority, pickups, and the first chain. | Three deterministic mission-roster formations; 35-second floor. | Pulse fire, hit/explosion feedback, score/chain HUD. |
| 0:45–1:35 | Formation Breaker | Focus movement and ordered formation kills. | Three varied formations; 42-second floor. | Formation names and focused hitbox/pattern prompt. |
| 1:35–1:50 | Tactical Fork | Choose the visible route; teach that route decisions are intentional. | Focusable branch panel; five-second floor. | Direct-route versus optional-rescue summary. |
| 1:50–2:35 | Rescue Run | Use shield/spell while collecting pilots under pressure. | Durable objective actors plus two waves; 32-second floor. | Objective progress, failure condition, radio calls. |
| 2:35–2:45 | Midpoint Rally | Let the player read resources and establish recovery semantics. | Midpoint checkpoint; five-second floor. | Checkpoint confirmation and concise loadout reminder. |
| 2:45–3:25 | Vanguard Duel | Read larger telegraphs and use heavy/secondary fire. | Registered miniboss, arena gate, 25-second floor. | Warning, boss health/state, miniboss sting. |
| 3:25–4:30 | Elite Intercept | Combine target priority, focus, chain, spell, and heavy fire. | Four escalating formations; 50-second floor. | Stronger silhouettes and denser but bounded audio. |
| 4:30–5:15 | Ion Storm | Maintain awareness while environmental damage and enemies overlap. | Executable ion-storm hazard plus two waves; 32-second floor. | Hazard warning, environmental feedback, reduced-flash-safe presentation. |
| 5:15–5:55 | Final Approach | Cooldown followed by the last mixed roster check. | Pre-boss checkpoint plus two formations; 28-second floor. | Resource warning, checkpoint, boss approach radio. |
| 5:55–7:45+ | Command Ship | Demonstrate phases, parts, arena pressure, and defeat reward. | Registered multi-phase boss and external arena gate; 45-second floor. | Boss intro/phase/defeat lines, health/parts HUD, large explosion. |
| 7:45–8:00+ | Mission Exit | Resolve score/rank/rewards and transition cleanly. | Six-second exit and idempotent completion. | Results dialogue and campaign unlock summary. |

The listed floors are not the expected full duration: waves, objective interaction, movement, and boss durability extend most beats. Human playtest captures must record actual segment timestamps before the Gold gate.

## Encounter rules

- Standard, formation, and elite nodes resolve to 3/3/4 waves at normal difficulty.
- Rescue, hazard, and final-approach nodes add two concurrent pressure waves.
- Each formation selects 4–6 Stage 1 roster members. Local co-op adds a slot; high difficulty may add another, capped at eight.
- Four seeded silhouettes—arrowhead, battle line, echelon, and diamond—replace repeated single-wave composition.
- Formation escape begins after 17 seconds plus pressure allowance. Enemy lifetime and stage bounds provide a second deadlock guard.
- Wave rewards, ordered-kill bonuses, enemy rewards, chain state, and owner attribution all reach the mission score/reward state.

## Route and checkpoint intent

The branch choice must remain keyboard/controller focusable and must not be hidden behind a debug input. The rescue route is the Stage 1 objective tutorial and should remain the default first-play recommendation. Midpoint and pre-boss checkpoints preserve the seed, route, score state, objective/hazard state, and safe spawn. Failure retains the last checkpoint; successful completion clears it and commits rewards once.

## Playtest capture

For every first-time, experienced, accessibility, keyboard/mouse, controller, solo, and local co-op run, record:

- start-to-results time and every segment transition;
- deaths, checkpoint resumes, missed prompts, branch choice, and objective outcome;
- chain peak/break reason, damage sources, spell/shield/heavy usage, and boss phase time;
- whether the player can explain focus, chain, checkpoint recovery, objective priority, and boss parts;
- readability or discomfort issues, including flashes, motion, color reliance, text speed, and audio masking.

Do not mark this beat sheet Gold until ten representative external players meet the completion and comprehension gate without coaching.
