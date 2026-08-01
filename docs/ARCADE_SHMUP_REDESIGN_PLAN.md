# Galax Hero: Arcade Shmup Gameplay Redesign Plan

- **Reference direction:** Caladrius Blaze, DoDonPachi Resurrection, and Danmaku Unlimited 3
- **Plan date:** 2026-07-31
- **Status:** Phases 0–3 implementation and automated acceptance are complete (2026-08-01); target-hardware, human loop-comprehension, and two-minute-course gates remain required before Stage 1 re-authoring.
- **Engine baseline:** Godot 4.7.1
- **Primary playfield:** 540 × 960 portrait
- **Planning assumption:** One primary developer; estimates should be re-baselined after the control prototype and Stage 1 playtest.

**Plan navigation:** [Baseline](#3-audited-project-baseline) · [Reference study](#4-reference-game-study) · [Controls](#6-ship-controls-and-feel) · [Enemy systems](#8-enemy-ai-pattern-choreography-and-the-large-asset-library) · [Level design](#9-level-design) · [Backgrounds and props](#10-backgrounds-parallax-asteroids-and-props) · [Menus and HUD](#12-menus-hud-practice-and-results) · [Roadmap](#15-phased-roadmap)

---

## 1. Outcome

Galax Hero should become a precise, readable, replayable arcade-style bullet-hell shooter whose depth comes from a small control vocabulary, authored enemy choreography, a unified risk/reward system, and short stages that feel like journeys through distinct places.

The target is not to clone any reference game:

- Take Caladrius Blaze's tactical weapon-resource decisions, character/loadout variety, large transforming bosses, and environmental spectacle.
- Take DoDonPachi Resurrection's immediate shot-versus-laser control grammar, chain continuity, hyper risk, deterministic encounter routing, detailed environments, and practice tooling.
- Take Danmaku Unlimited 3's focus precision, visible true hitbox, graze-to-power loop, readable bullet choreography, difficulty philosophy, and fast restart/practice structure.
- Avoid Caladrius's visual obstruction and overloaded HUD, Resurrection's opaque rules and version labels, and Danmaku Unlimited 3's weak environmental identity and limited pause menu.

The immediate product goal is one Gold-quality Stage 1 and then a five-stage flagship Arcade Route. The existing 60-stage campaign remains valuable, but it must not be treated as authored or polished merely because recipes and data records exist.

---

## 2. Decisions This Plan Recommends

1. **Ship feel comes first.** Do not expand campaign content until movement, focus, hitbox, firing transitions, collision honesty, and input latency pass playtest.
2. **Use deterministic choreography, not general-purpose combat AI.** Regular enemies are performers in a timed encounter score: entry, telegraph, attack, reposition, and exit.
3. **Create one closed scoring/resource loop.** Graze, chain, Element use, bullet conversion, and Overdrive must feed one another instead of appearing as unrelated meters.
4. **Use a compact default control scheme.** Remove universal mid-combat actions that do not reinforce the arcade loop.
5. **Author five flagship stages before scaling to sixty.** Each needs its own timeline, landmarks, enemy grammar, music arc, midboss, boss, and visual transformation.
6. **Replace the two competing background paths with one Stage Background Director.** Backgrounds become timed environmental journeys, not repeating texture sheets.
7. **Treat the asset catalog as a large content reservoir.** The project has thousands of ship, enemy, asteroid, effect, background, and prop records. The bottleneck is classification, assembly, approval, and runtime wiring—not asset quantity.
8. **Split the procedural menu shell into scene-backed pages.** Play, Practice, Hangar, Records, and Settings must each communicate the game visually and work completely with controller or keyboard.
9. **Normalize regulation play.** Persistent RPG upgrades may not change hitbox size or unpredictably change route-critical movement speed in Arcade/Score modes.
10. **Measure claims.** Exact speed, hitbox, latency, density, and difficulty values in the reference games are not fully published; prototype targets below are starting points, not copied facts.

### Relationship to existing project decisions

- This is a targeted gameplay and presentation plan. It complements docs/PROJECT_END_TO_END_COMPLETION_AND_IMPROVEMENT_PLAN.md.
- After the control prototype passes, create a new ADR that supersedes or amends docs/decisions/0002-combat-identity-and-controls.md.
- Revise docs/ART_BIBLE.md so the existing 65–80% collision guidance continues to apply to enemies where appropriate, but not to the player's bullet-hell hitbox.
- Keep the production service/session/content boundaries. Replace behavior and presentation within those boundaries rather than restarting the project.

---

## 3. Audited Project Baseline

### 3.1 Important distinction: runtime wiring versus available art

The production data folder currently has 21 enemy definition resources, one authored wave resource, three authored movement resources, and three authored attack-pattern resources. That is the current **playable wiring**, not the size of the available art library.

The generated asset manifest currently contains 4,789 asset records, including:

- 2,764 records categorized as ships.
- 122 records categorized as backgrounds.
- 1,643 source paths containing “asteroid.”
- Large groups of effects, projectiles, ship parts, bosses, animation frames, planets, rocks, turrets, and other props.

Those record counts include individual frames, layered parts, duplicates, source variants, and incomplete assemblies. They should not be interpreted as 2,764 ready-made enemies or 1,643 distinct gameplay asteroids. They do prove that the project already has a very large visual library to curate.

### 3.2 Current strengths to preserve

| Area | Existing strength |
|---|---|
| Display | Fixed 540 × 960 gameplay space with widescreen pillarboxing and clear scaling policy. |
| Architecture | Production services, sessions, content definitions, typed events, pools, save/profile systems, modes, bosses, objectives, co-op, and test infrastructure already exist. |
| Accessibility foundation | Remapping, auto-fire, focus toggle, motion/flash/particle controls, color options, text/UI scale, and game-speed assistance have settings entries. |
| Content library | Thousands of source assets plus a searchable manifest and approval pipeline. |
| Player systems | Ships, weapons, spells, super mode, progression, loadouts, and presentation hooks are data-driven. |
| Stage systems | Deterministic graph generation, segments, objectives, hazards, branches, checkpoints, bosses, and seeds exist. |
| Practice/modes | Training, stage reuse, boss practice, local leaderboards, and multiple modes have backend support. |

### 3.3 Current gaps this plan directly addresses

| Area | Audited evidence | Consequence |
|---|---|---|
| Movement feel | PlayerMovementController eases velocity using acceleration/deceleration. Vanguard focus is derived as 48% of normal speed. | The ship can feel like a general action game actor instead of an immediate arcade craft. |
| Hitbox | ProductionPlayer configures a roughly 12-pixel-radius player hurtbox/collision shape while the visible ship is only about 40–50 pixels wide in play. | The collision core is too large for dense danmaku and is not honestly communicated. |
| Input grammar | InputService exposes movement, focus, aim, lock-on, primary, secondary, heavy, spell, melee, shield, parry, dash, roll, boost, teleport, super, weapon cycling, and two wingman commands. | Too many universal actions compete for the player's attention and controller space. |
| Aim identity | Right-stick aim can redirect the primary weapon even though the accepted ADR describes classic forward fire. | Ship positioning and forward-fire routing lose clarity. |
| Analog tuning | Movement sensitivity can scale from 0.25 to 2.0, changing top speed; the default dead zone is 0.25. | Regulation balance and single-tap precision vary by settings. |
| Projectile honesty | ProductionProjectile creates a fixed 5-pixel collision shape while definitions can draw a different collision radius. | Visual core and collision can disagree. |
| Scoring | MissionScoreTracker is primarily a four-second kill chain with a capped multiplier; there is no graze loop or bullet conversion. | Scoring is disconnected from the signature act of dodging bullets. |
| Enemy variety | Most production enemy definitions share the same sine movement resource and Scout Tactical Deck. | Different sprites and statistics do not create different combat roles. |
| Attack behavior | Telegraph seconds exists in AttackPatternDefinition but is not consumed by EnemyAttackController. | Attacks can fire without the authored windup being represented. |
| Wave variety | One authored Arrowhead wave is duplicated and reshaped by EncounterPackageResolver. | Structural variation masks repeated combat grammar. |
| Stage authorship | Generic segment templates and generated formation packages stand in for most stage beats. | The campaign has breadth without the route memory and pacing of a handcrafted shmup. |
| Backgrounds | MissionBackdrop slices five-layer sheets for an operation; StageSegmentRuntime also creates ParallaxPresentation, but no segment assigns background_layers. | One generic backdrop runs underneath an effectively empty per-segment parallax system. |
| Environmental art | Current approved sheets are mostly dark fields, nebula shapes, and sparse stars. | They are useful ingredients but not complete locations or memorable routes. |
| Menus | MenuShell is an 850+ line procedural file that rebuilds many text-heavy pages. | Navigation works, but preview, hierarchy, layout, animation, and maintainability are weak. |
| HUD/results | Mission HUD uses compressed strings such as HP, SH, EN, and OV; results emphasize XP and credits. | The arcade loop and score decisions are not explained at the point of play. |
| Accessibility wiring | Some settings, including simplified patterns and aim assistance, are recorded but do not materially alter the relevant runtime behavior. | A visible setting can promise more than the game currently delivers. |

---

## 4. Reference Game Study

### 4.1 Comparison Matrix

| Design area | Caladrius Blaze | DoDonPachi Resurrection | Danmaku Unlimited 3 | Galax Hero direction |
|---|---|---|---|---|
| Movement | Immediate classic movement, ship-specific speeds, no dedicated focus command. | Immediate 8-way movement; laser instantly slows the craft. | Tight 8-way movement; focus beam slows the craft to roughly half speed. | Immediate no-inertia movement with normal and focus gears. |
| Main offense | Unlimited main shot plus three direct Element Shots. | Fast/wide rapid shot versus slow/narrow laser; laser aura and counter-laser utility. | Wide rapid shot plus narrow high-DPS focus beam. | Rapid shot and focus beam are the non-negotiable core. |
| Tactical resource | Three regenerating Element gauges plus bomb and mode super. | Bomb/style plus Hyper; high-level play uses Hyper as score, safety, and player-controlled danger. | Graze/Spirit feeds Trance; Trance clears bullets and powers offense. | One Element tool, one Overdrive meter, and a separate bomb/safety stock. |
| Scoring | Element kills raise rate; Element use fills Ether upgrades. | Kill chaining, laser contact, bees, Hyper cancels, and route conditions. | Grazing raises multiplier and fuels Trance; timed kills convert bullets. | Kills, beam contact, graze, Element conversion, and Overdrive form one loop. |
| Enemy design | Authored formations, ground emplacements, anchors, large animated bosses. | Deterministic stage routes, aimed streaming, laser gates, cancel targets, anchor enemies. | Scripted light/heavy pattern phrases; authored difficulty topology. | Timeline-authored enemy roles and readable pattern phrases. |
| Stage structure | Five or six compact stages, strong environmental progression, long bosses. | Five stages with short onboarding, pressure wall, route secrets, and long final reprise. | Five stages, each with midboss and boss; strong choreography but weaker stage identity. | Five flagship stages, each 5–7 minutes; final stage 8–10 minutes. |
| Backgrounds | Ambitious multi-layer/3D journeys; sometimes too busy. | Detailed terrain, infrastructure, landmarks, and parallax progression. | Readable foreground, but often generic foggy space backgrounds. | Resurrection-like landmarks plus Caladrius-like transitions, under a readability governor. |
| Menus/practice | Many modes and loadout depth; dense HUD, passive/tiny tutorials. | Excellent granular training/replays; opaque mode names and weak onboarding. | Good practice/restart/difficulty options; bare pause flow. | Plain-language mode cards, interactive drills, replay/practice depth, complete pause settings. |

### 4.2 Caladrius Blaze: What to Learn

#### Verified gameplay findings

- Official controls use one normal-fire action, three direct Element Shot actions—offense, support, and defense/melee—a mode-specific super, and bomb.
- Each Element Shot has its own rechargeable gauge. Tools include penetration, homing, off-screen coverage, shields, reflection, and bullet cancellation.
- When all three gauges pass a threshold, Original, Arcade, and Evolution modes provide different screen-clear/power states.
- Element kills raise score rate. Element use fills an Ether gauge whose chips upgrade Element Shots between stages.
- All tactical tools are available immediately; the game does not depend on random weapon drops.
- Original has five stages and Evolution adds a sixth, with compact stage journeys and long multi-phase bosses.
- MOSS explicitly valued multi-layer scrolling, reflections, and the desire to see “what comes next,” while acknowledging that busy backgrounds can hurt bullet visibility.

#### Use in Galax Hero

- Preserve a regenerating tactical resource that can buy damage, control, cancellation, or defense.
- Preserve horizontal loadout choices and between-stage upgrade decisions.
- Ensure every stage has a movement-only solution; an Element loadout may improve safety or score but may not be mandatory.
- Give bosses physical phase changes, exposed parts, and long-form attack development.
- Use cinematic camera/parallax events between precision-dodging beats.

#### Do not copy

- Do not copy six always-required combat actions into the default mapping.
- Do not hide the true hitbox.
- Do not let player bloom, cut-ins, or 3D background motion obscure hostile bullets.
- Do not use last-hit-only scoring for Element kills; attribute by active state or damage contribution.
- Do not reproduce the sexualized Shame Break framing. If a timed boss-phase reward is useful, present it as armor fracture, system overload, or exposed core.

Primary and high-quality sources: [MOSS controls/HUD](https://caladrius.mossjp.co.jp/ps3/play00.html), [MOSS modes](https://caladrius.mossjp.co.jp/ps3/mode00.html), [MOSS secondary modes](https://caladrius.mossjp.co.jp/ps3/mode02.html), [developer interview](https://shmuplations.com/caladrius/), [4Gamer background interview](https://www.4gamer.net/games/202/G020259/20130416076/index_2.html), [Steam feature page](https://store.steampowered.com/app/386770/Caladrius_Blaze/).

### 4.3 DoDonPachi Resurrection: What to Learn

#### Verified gameplay findings

- CAVE's official control page defines the essential grammar: move with the lever; tap/press A for shot; hold A for laser; C provides rapid shot; D activates Hyper; B bombs or changes Power style.
- Laser immediately reduces movement speed. It also concentrates damage, creates a close-range aura, and participates in counter-laser interactions.
- Three hulls combine speed and coverage tradeoffs; three Styles alter power, safety, and stance behavior.
- Hyper cancels bullets, increases firepower, helps chaining, and can also raise danger through Hyper Rank and counter-bullet/laser behavior.
- Kill chaining, laser engagement, hidden bees, alternate routes, and Hyper timing make enemy placement and scenery part of score routing.
- Stages are authored around aimed streaming, durable anchors, laser gates, cancel targets, rotating obstacles, and final-stage reprises.
- Console/PC packages include granular training, replay playback, input display, screen layouts, multiple rulesets, and local co-op.

#### Use in Galax Hero

- Make rapid-shot and focus-beam transitions immediate and lossless.
- Let fast movement solve macro repositioning and focus movement solve micro-dodging.
- Let beam contact hold or slow chain decay so large enemies bridge wave gaps.
- Use Overdrive as offense, score conversion, and temporary safety.
- Use route landmarks, destructible scenery, and cancel targets to create learnable optional paths.
- Make the final stage a longer recombination of learned verbs, not merely a larger health budget.

#### Do not copy

- Do not present internal version labels as player-facing mode explanations.
- Do not hide basic survival and score rules behind experimentation.
- Do not make Novice only “fewer bullets”; teach mechanics and soften resource failure.
- Do not allow indefinite boss milking.
- Do not inherit mixed projectile colors or effects that weaken peripheral reading.

Primary and high-quality sources: [CAVE official controls](https://www.cave.co.jp/gameonline/daifukkatu/system/01_oi.html), [CAVE Hyper Counter](https://www.cave.co.jp/gameonline/daifukkatu/system/03_hcm.html), [CAVE Counter Laser](https://www.cave.co.jp/gameonline/daifukkatu/system/04_cl.html), [CAVE Black Label](https://www.cave.co.jp/gameonline/daifukkatu/black/index.html), [technical reference](https://shmups.wiki/library/DoDonPachi_DaiFukkatsu_Ver1.5), [official Steam feature page](https://store.steampowered.com/app/464450/DoDonPachi_Resurrection/).

### 4.4 Danmaku Unlimited 3: What to Learn

#### Verified gameplay findings

- The craft has free 8-way movement, a wide rapid shot, a narrower stronger focus beam, and a contextual bomb/Trance action.
- Focus is the core precision state and slows the craft to roughly half speed.
- The bright center core is the vulnerable point. Graze rings communicate near misses.
- Five regular-shot patterns and five beam patterns create 25 combinations without changing the movement model.
- In Spirit mode, destroying an enemy turns its remaining bullets into harmless spirits. In Graze mode, greater risk is required before conversion.
- Grazing sustains a score multiplier and fills Trance. Trance powers offense, converts bullets to score items, and slows chain decay.
- The developer describes patterns as scripted rather than random and alternates light and heavy attack phrases.
- Lower difficulties were retuned to preserve pattern form rather than simply deleting bullets.
- Five stages use the stage–midboss–stage–boss cadence. Practice, Boss Rush, Boss Free Play, quick restart, TATE, remapping, and regulation-aware assists support replay.

#### Use in Galax Hero

- Always show the true collision core, with stronger emphasis during focus.
- Add a graze sensor that is separate from damage collision.
- Make enemy bullets a resource only through deliberate risk and source-kill timing.
- Author light/heavy bullet phrases and named movement tests.
- Build separate difficulty variants that preserve the recognizable pattern silhouette.
- Unlock stage and boss practice when first encountered, not only after a full clear.

#### Do not copy

- Do not accept generic space fog as adequate stage identity.
- Do not make “Easy” hostile to genuine newcomers.
- Do not restrict important settings outside pause.
- Do not rely on color alone to separate live bullets, spirits, score items, and friendly shots.

Primary and high-quality sources: [official developer site](https://www.doragongames.com/danmaku3/), [official Steam page](https://store.steampowered.com/app/450950/Danmaku_Unlimited_3/), [developer level-design interview](https://www.forgottenworlds.net/bullet-hell-danmaku), [developer color/difficulty interview](https://twobeardgaming.wordpress.com/2021/02/27/interview-sunny-sy-tam-danmaku-unlimited-3-developer/), [technical reference](https://shmups.wiki/library/Danmaku_Unlimited_3), [official patch notes](https://steamcommunity.com/app/450950/allnews/).

---

## 5. Recommended Core Game

### 5.1 Player promise

“Move instantly, switch between fast coverage and focused precision, graze danger to build power, convert enemy fire into opportunity, and route short handcrafted stages for survival or score.”

### 5.2 Closed gameplay loop

1. Rapid Shot clears light enemies and lets the player reposition quickly.
2. Focus Beam slows the ship, reveals/emphasizes the true hitbox, and concentrates damage.
3. Grazing live bullets builds Chain stability and Overdrive.
4. An Element ability spends a regenerating gauge on attack, control, cancellation, or defense.
5. Destroying a marked enemy while its bullets are active converts eligible bullets into Flux.
6. Collecting Flux restores Element energy, raises score rate, and fills Overdrive.
7. Activating Overdrive clears or converts the screen, boosts offense, and slows Chain decay.
8. In higher regulation modes, Overdrive also raises visible Rank, selecting denser or more demanding authored variants at the next attack-phrase or boss-phase boundary.
9. Taking damage, bombing, or dropping Chain costs scoring value but should not make a casual clear unrecoverable.

### 5.3 Regulation layers

| Layer | Purpose | Rules |
|---|---|---|
| Story | Learn, progress, and use RPG systems. | Checkpoints, bounded upgrades, auto-bomb/auto-Overdrive options, adjustable lives. |
| Arcade | Primary authored ruleset. | Fixed ship movement/hitbox, no stat-driven speed change, limited continues, score table. |
| Expert | High-risk scoring. | Manual resources, visible Rank, hardest authored pattern variants, strict chain. |
| Practice | Learn sections. | Section select, resources/rank setup, slow motion, overlays, instant restart, no score submission. |

Persistent progression may unlock visual variants, shot/beam/Element choices, and bounded resource/damage options. It may not change the Arcade hitbox or allow equipment to invalidate authored safe lanes.

---

## 6. Ship Controls and Feel

### 6.1 Recommended default mapping

The default should have five combat intents, not the current universal action list.

Offer two coherent keyboard presets at first launch so one hand moves while the other handles combat.

| Intent | Arcade keyboard | WASD keyboard | Controller default | Behavior |
|---|---|---|---|---|
| Move | Arrow keys | WASD | D-pad and left stick | Immediate 8-way/direct movement. |
| Rapid Shot | Z | J | A / Cross | Wide/coverage fire at normal movement speed. |
| Focus Beam | X | K | X / Square | Fires narrow beam, immediately changes to focus speed, emphasizes hitbox. |
| Element | C | L | Y / Triangle | Uses the one active Element tool selected in the Hangar. |
| Overdrive | V | I | B / Circle | Activates only when ready; bullet conversion/clear plus timed power state. |
| Bomb | Left Shift | Space | Right bumper | Separate emergency stock; optional auto-bomb assist. |
| Pause | Escape | Escape | Start/Menu | Pauses on press and opens complete pause menu. |

All actions remain remappable. The selected preset is only a starting point, and controller/keyboard glyphs must update live.

#### Why one active Element tool

Caladrius proves that offense, support, and defense tools create strong decisions, but its direct six-action layout is not the best default for this project. Galax Hero should preserve the categories in the Hangar while equipping one active Element action for a run:

- **Attack:** penetration, homing burst, heavy beam, close aura, or armor break.
- **Control:** bullet reflection, slow field, gravity pull, option sweep, or cancel mark.
- **Defense:** shield, phase step, absorb field, or emergency barrier.

Additional Element slots are a post-prototype option, not a first milestone. Every stage must remain solvable with movement, Rapid Shot, and Focus Beam alone.

### 6.2 Input resolution rules

- Rapid Shot begins on the press tick.
- Focus Beam begins and applies focus speed on the same simulation tick.
- Focus Beam overrides held Rapid Shot without a dead frame.
- Releasing Focus Beam returns to Rapid Shot immediately if Rapid Shot is still held.
- Element may temporarily override the normal muzzle pattern, but movement remains responsive unless the ability clearly and briefly communicates a commitment.
- Overdrive and Bomb use a two-frame input buffer so a press at a state boundary is not lost.
- Pause is edge-triggered, device-owned, and cannot fire a gameplay action on resume.
- Presentation banking and thruster easing are visual only; they do not modify gameplay velocity or collision.
- Right-stick free aim is removed from the regulation default. Aim-capable equipment may use bounded auto-aim or an explicit non-regulation twin-stick mode.

### 6.3 Movement prototype targets

These are starting values to test, not final copied numbers.

| Property | Prototype target |
|---|---:|
| Simulation rate | Fixed 60 Hz |
| Input-to-simulation response | Same tick or no more than one fixed tick |
| Acceleration/deceleration | None in regulation movement |
| Diagonal handling | Normalized |
| Normal full-field crossing | Roughly 1.4–1.8 seconds |
| Focus speed | 45–52% of normal speed |
| Player damage hitbox radius | 3.5–5.0 logical pixels |
| Graze radius | 24–32 logical pixels |
| Boundary margin | Hitbox-based, not sprite-canvas-based |
| Analog dead zone | Radial, prototype 0.15–0.20 |
| Analog top speed | Capped at the ship's authored normal speed |

Do not let “movement sensitivity” multiply the ship above authored top speed. Replace it with:

- Dead-zone size.
- Response curve.
- Digital 8-way versus proportional analog preference.
- Optional focus-speed accessibility adjustment, recorded in run metadata.

### 6.4 Ship identity without invalidating stage design

Ship differences should be meaningful but narrower than the current 255–385 speed range.

| Ship role | Normal movement | Focus movement | Rapid Shot | Focus Beam | Element tendency |
|---|---|---|---|---|---|
| Vanguard | Baseline | Baseline | Medium spread | Medium beam | Balanced recharge |
| Lancer | About 8–12% faster | About 4–8% faster | Narrow forward | High DPS/point-blank | Attack/control |
| Bastion | About 8–12% slower | Near baseline focus | Wide coverage | Wide but lower DPS | Defense/control |

Use one clearly disclosed hitbox size across core ships during the first prototype. Cosmetic sprite size must never silently alter survival collision.

### 6.5 Current action migration

| Current universal action | New treatment |
|---|---|
| Primary fire | Rapid Shot |
| Focus | Focus Beam and precision speed |
| Secondary/heavy fire | Fold into shot/beam loadout patterns or Element choices |
| Spell | Element choice |
| Shield | Defensive Element or passive resource |
| Melee/parry | Specialized Element tools; not universal |
| Dash/roll/teleport/boost | Remove from universal regulation mapping; individual Element variants only if patterns remain movement-solvable |
| Super mode | Overdrive |
| Lock-on/right-stick aim | Bounded passive targeting; no default free aim |
| Next/previous weapon | Hangar selection; avoid mid-pattern cycling |
| Wingman commands/wheel | Wingman formation follows Rapid/Focus state or becomes a passive loadout rule |

### 6.6 Control implementation work

- [ ] Add normal_speed, focus_speed, hitbox_radius, graze_radius, shot_pattern_id, focus_pattern_id, and element_slot_id to ShipDefinition or a dedicated ArcadeShipProfile.
- [ ] Replace velocity easing in production/movement/player_movement_controller.gd with a regulation direct-movement path.
- [ ] Keep the old movement state machine only for non-regulation abilities that genuinely need a state.
- [ ] Add a radial analog dead-zone/curve implementation to production/services/input_service.gd.
- [ ] Stop movement sensitivity from changing authored top speed.
- [ ] Add explicit Rapid Shot, Focus Beam, Element, Overdrive, and Bomb actions; migrate stored bindings safely.
- [ ] Add two-frame buffering for Bomb and Overdrive.
- [ ] Separate visual hull, damage hitbox, graze ring, pickup radius, and contact collision.
- [ ] Update the physical CollisionShape2D when a configured radius changes.
- [ ] Show the true hitbox at all times or at minimum whenever Focus Beam is held; include an always-visible option.
- [ ] Add a control test scene with motion traces, tick counters, live input state, and measured displacement.
- [ ] Record a 240 fps external capture on representative hardware before claiming low latency.

### 6.7 Control acceptance gate

- The craft begins and stops within one fixed tick in regulation mode.
- Rapid-to-Focus and Focus-to-Rapid transitions have no firing gap.
- Twenty alternating one-tick focus taps produce repeatable displacement.
- Keyboard, D-pad, analog stick, and arcade stick all pass diagonal and drift tests.
- The visible hitbox agrees with debug collision to within one logical pixel.
- Five experienced shmup players can intentionally use both movement gears within ten minutes.
- Five newcomers can explain “fast coverage versus slow precision” after a playable drill without coaching.
- No Stage 1 pattern is solved by holding focus forever or by never using focus.

---

## 7. Combat, Graze, Chain, Element, and Overdrive

### 7.1 One readable score model

Keep the HUD to four core values:

1. **Score**
2. **Chain number plus visible drain bar**
3. **Rate multiplier**
4. **Overdrive meter**

Element energy appears near the Element icon. Bomb stock appears near the player status. Do not add another unexplained currency during active play.

### 7.2 Proposed rules

#### Chain

- Destroying an enemy refills the Chain bar and increases Chain.
- Damaging a large enemy with Focus Beam slows or pauses Chain decay, allowing it to bridge wave gaps.
- Grazing adds small Chain stability but does not replace kills.
- Taking health damage breaks Chain. Shield-only damage may reduce the bar instead of fully breaking it on Story difficulty.
- Bombing immediately reduces Rate and Chain; the exact penalty is shown before the run.

#### Graze

- Each hostile projectile may award graze only once per player until it exits and re-enters the graze radius under an explicitly supported pattern.
- Graze requires the projectile to be live and dangerous.
- Graze produces a short spark, directional tick sound, small meter pulse, and readable ring feedback.
- Graze events are pooled and rate-limited so dense patterns do not create audio/VFX noise or allocation spikes.

#### Element

- Element energy regenerates slowly and is accelerated by collecting Flux.
- Attack, Control, and Defense tools share one clear resource contract.
- Element contribution is attributed by active state or damage share, not opaque last hit.
- Cancelable and non-cancelable bullets use distinct cores/shapes plus color.
- Element lockout after Overdrive or depletion is visible as a timed recovery arc.

#### Flux conversion

- Selected enemy roles carry a visible conversion marker.
- Destroying the source while eligible bullets are active converts those bullets into harmless Flux along their current paths.
- Flux has a different silhouette, trail, speed language, and protected render layer from hostile bullets.
- Story mode may allow broader conversion. Expert mode may require Graze High, Element damage, or precise timing.

#### Overdrive

- Full meter activation grants a brief invulnerability window, converts or clears eligible bullets, boosts weapons, and slows Chain decay.
- Activation and ending are deterministic and fully replayable.
- Overdrive cannot indefinitely loop on bosses; use phase timers, diminishing cancel value, and capped meter gain.
- Expert mode adds visible Rank pips. Rank is sampled only at attack-phrase or boss-phase boundaries; it never changes topology or safe lanes during an active pattern.
- Ending Overdrive creates a short recovery state, inspired by Caladrius Evolution's commitment cost, but never disables movement.

### 7.3 Difficulty philosophy

Each major pattern has authored variants:

- **Novice:** wider lanes, slower convergence, fewer simultaneous emitters, generous conversion and auto-bomb.
- **Arcade:** intended topology, manual Overdrive, bounded auto-bomb option.
- **Expert:** additional aimed layer, tighter but validated lanes, higher Rank branches, strict scoring.

Do not generate lower difficulty by deleting every other bullet. Preserve the recognizable pattern shape and the movement lesson.

### 7.4 Combat implementation work

- [x] Add GrazeComponent or a dedicated graze Area2D separate from damage collision.
- [x] Add per-projectile grazed-player state and cancel/conversion tags.
- [x] Update ProductionProjectile collision shape from its definition rather than leaving it fixed at five pixels.
- [x] Add BulletConversionService with pooled Flux items and deterministic attribution.
- [x] Expand MissionScoreTracker into an explicit Chain state with drain, beam hold, graze, damage, bomb, and Overdrive events.
- [x] Expand SuperModeRuntime or replace it with OverdriveRuntime supporting conversion, Rank, recovery, and score metadata.
- [x] Add ElementRuntime as the single active tactical slot; adapt existing spells/shield/melee tools behind it.
- [x] Add damage-contribution tracking for Element scoring.
- [x] Add score breakdown and reason codes to results/replay metadata.
- [x] Add debug overlays for damage core, graze ring, cancel eligibility, chain source, and Rank branch.

---

## 8. Enemy “AI,” Pattern Choreography, and the Large Asset Library

### 8.1 Design principle

In a routing-focused shmup, better enemy AI usually means better **authored behavior**, not enemies that continuously chase or outsmart the player.

Use this state score:

**Entry path → formation settle → telegraph → attack phrase → reposition → second phrase or exit → timeout/desperation**

Player-reactive behavior is allowed only when it remains learnable:

- Snapshot aim at a defined telegraph moment.
- Choose one of a few seeded lanes based on the player's horizontal band.
- Change a later phrase after a documented kill-order or route condition.
- Add a desperation phrase if an anchor survives too long.

Do not continuously steer ordinary bullets toward the player after firing.

### 8.2 Core combat roles

| Role | Movement/attack job | Asset opportunities |
|---|---|---|
| Popcorn | Quick arcs, one aimed volley, chain glue | Small fighters, drones, UFOs |
| Streamer | Repeated aimed snapshots that force lateral herding | Fast fighters, interceptors |
| Fan turret | Fixed symmetric spread for micro-dodge | Turrets, stations, ground guns |
| Sweeper | Rotating arc/beam that forces macro reposition | Beam ships, satellite parts |
| Anchor | High HP, sustained pressure, controls overlap timing | Gunships, carriers, heavy hulls |
| Flanker | Side/rear entry at authored beats | Agile side-profile craft |
| Charger | Telegraph, lane rush, vulnerable recovery | Spear/nose-heavy ships |
| Shield/support | Protects or buffs a formation; high target priority | Drones, generators, escorts |
| Cancel target | Converts current danger when destroyed | Reactor cores, marked carriers |
| Laser gate | Explicitly asks for Focus/Counter behavior | Large cannons, tower assets |
| Mine layer | Creates delayed spatial constraints | Mine ships, asteroid rigs |
| Cleanup unit | Short release phrase after a heavy beat | Small disposable craft |

No encounter should activate more than two high-attention roles at once until late-game exams.

### 8.3 Runtime composition model

Do not create a unique script for every available sprite. Separate four layers:

1. **Visual Family:** sprite/sheet/animation/parts, faction palette, scale, pivots, effects, license.
2. **Combat Archetype:** health band, hurtbox, role, movement capability, target priority, reward.
3. **Behavior Score:** entry/reposition/exit paths plus timed attack phrases.
4. **Encounter Variant:** combines a visual family, archetype, behavior score, difficulty variant, and stage context.

This lets hundreds of enemy visuals appear across the campaign without requiring hundreds of unrelated AI implementations or making all ships feel statistically interchangeable.

### 8.4 Enemy and prop asset onboarding pipeline

- [ ] Query the 4,789-record manifest and build curated views for complete ships, bosses, ship parts, turrets, asteroids, props, backgrounds, and effects.
- [ ] Deduplicate exact files, animation frames, color variants, layered parts, and obsolete exports.
- [ ] Identify complete sprites versus assemblies requiring Spriter/SCML or part composition.
- [ ] Group complete enemy visuals by silhouette, apparent scale, facing, faction fit, and animation readiness.
- [ ] Group asteroid/prop assets by depth use, size family, collision suitability, tileability, and animation.
- [ ] Confirm license/approval before promotion to assets_runtime.
- [ ] Create EnemyVisualFamilyDefinition and StagePropDefinition resources with pivots, scale, collision recommendation, and presentation tags.
- [ ] Generate draft resources only as review aids; do not auto-approve gameplay statistics.
- [ ] Preview every promoted enemy in enemy_laboratory.tscn against player bullets, hostile-bullet palettes, explosion scale, and hitbox overlay.
- [ ] Preview every prop at far, middle, near, and gameplay depth before choosing its layer.
- [ ] Add contact sheets filtered by role/faction/scale so stage authors can select assets intentionally.

### 8.5 Movement and path authoring

Replace generic clamped vector movement as the main content tool with path/timeline resources:

- Bezier entry and exit curves.
- Screen-relative anchor points.
- Formation offsets driven by shared path progress.
- Ease type and duration.
- Pause/hover duration.
- Facing/banking presentation separate from collision direction.
- Reposition cues synchronized with attack phrases.
- Off-screen spawn/fire restrictions.
- Kill/escape/timeout behavior.

Keep procedural sine/zigzag only as reusable path modifiers.

### 8.6 Bullet-pattern authoring

Expand AttackPatternDefinition into composable emitter phrases:

- Emitter count and transforms.
- Aimed, fixed, predictive-snapshot, radial, spiral, wave, wall, sweep, laser, mine, and conversion tags.
- Layer count, shots per layer, cadence, angular offset, angular velocity, and acceleration.
- Bullet visual family, collision core, cancel class, and graze value.
- Telegraph duration and cue contract: dedicated windup, readable entry/muzzle charge, beam preview, or established cadence.
- Fire duration, recovery duration, and repeat count.
- Safe-lane metadata and expected player gear: normal, focus, or either.
- Difficulty variants that preserve topology.
- Co-op widening/target rules.

Every attack phrase must satisfy a readable warning contract before its first damaging projectile. EnemyAttackController consumes telegraph_seconds when a dedicated windup is authored; a clearly readable entry animation, muzzle charge, beam preview, or already-established cadence may satisfy the contract without adding a redundant flash or sound. The effective warning remains explicit and testable.

### 8.7 Encounter authoring

Replace “duplicate Arrowhead three times” with a StageEncounterTimeline:

- Absolute or music-relative cue time.
- Landmark/background zone.
- Spawn group and path.
- Combat role and pattern phrase.
- Chain bridge target.
- Optional route condition.
- Cancel/release target.
- Maximum screen-pressure budget.
- Completion rule that may overlap the next beat.

Waves should not always wait for defeat_all. Expert routing depends on controlled overlap, escape consequences, and chain bridges.

### 8.8 Enemy acceptance gate

- Stage 1 uses at least eight visually distinct enemy families and six distinct combat roles.
- No two consecutive Stage 1 beats reuse the same entry path plus attack phrase.
- Every damaging phrase has a readable, testable warning contract and a movement-only solution.
- A replay with the same seed and inputs remains deterministic.
- Difficulty variants preserve named pattern shapes and validated safe lanes.
- Enemy sprites, hitboxes, muzzle points, and explosions agree visually.
- No ordinary enemy fires while substantially off-screen unless explicitly telegraphed.
- The asset catalog can add a new visual variant without a code change.

---

## 9. Level Design

### 9.1 Scope correction

The quality target set by the references is five or six deeply authored stages, not sixty lightly remixed recipes. Keep the 60-stage campaign data, but change production order:

1. Gold Stage 1.
2. Five-stage Arcade Route.
3. Operation 1 story variants built from proven content.
4. Remaining campaign stages only after each has a unique beat sheet and environmental storyboard.

If schedule pressure appears, reduce the number of campaign stages before reducing the quality of controls, patterns, bosses, or environments.

### 9.2 Standard flagship stage shape

Target 5–7 minutes for Stages 1–4 and 8–10 minutes for the final stage.

| Approximate time | Beat | Purpose |
|---:|---|---|
| 0:00–0:15 | Visual hook | Show the location and allow movement/firing confirmation. |
| 0:15–0:55 | Teach | One enemy role and one bullet verb. |
| 0:55–1:35 | Repeat with displacement | Same idea from a new entry angle or lane. |
| 1:35–2:15 | Combine | Add a second role; introduce chain bridge/cancel target. |
| 2:15–3:00 | Midboss | Exam of the stage's first grammar. |
| 3:00–3:15 | Release | Short visual/music breath; Flux/resource recovery. |
| 3:15–4:30 | Escalate | Harder remix, environmental interaction, route cue. |
| 4:30–5:15 | Landmark set piece | Memorable terrain/prop sequence tied to combat. |
| 5:15–5:30 | Boss approach | Clear warnings, resource read, arena transition. |
| 5:30–7:00 | Boss | Three phrases: teach, remix, mastery. |

The timeline is a target, not a hard gate. High DPS may shorten bosses; low DPS must not create dead air or infinite milking.

### 9.3 Five-stage Arcade Route

This route intentionally uses the approved background families as ingredients and the raw prop/asteroid/enemy library for landmarks.

| Stage | Environment journey | New gameplay grammar | Midboss/boss identity | Required landmarks |
|---|---|---|---|---|
| 1. Frontier Intercept | Sparse outer orbit → planet horizon → raider relay | Aimed streaming, fan spreads, Focus Beam, first conversion | Raider ace → command ship | Large planet pass, relay station, carrier arrival |
| 2. Fleet Foundry | Blue fleet lanes → shipyard scaffolds → launch trench | Anchors, support drones, laser gates, destructible turrets | Mobile foundry guardian → arsenal carrier | Docked hulls, crane corridor, hangar mouth |
| 3. Shattered Veil | Violet nebula → ancient ruins → phase rift | Spirals, conversion timing, seeded route branch, anomaly drift | Relay specter → veil engine | Ruin rings, broken gate, rift transition |
| 4. Amber Warfront | High atmosphere → burning defense line → orbital weapon | Crossfire, sweepers, rescue/cancel choices, foreground flyovers | Siege lancer → orbital cannon core | Cloud descent, fleet battle, weapon barrel |
| 5. Convergence | Gold rift exterior → machine interior → exposed core | Reprises every prior verb, controlled Rank, multi-boss sequence | Returning rivals → convergence entity | Megastructure approach, tunnel, reactor chamber |

### 9.4 Stage identity contract

Every stage must introduce:

- One new enemy combat role.
- One new bullet or laser behavior.
- One new scoring/conversion decision.
- One unmistakable palette and silhouette family.
- Three to five named environmental landmarks.
- One background transformation.
- One music transition synchronized to a gameplay beat.
- One midboss and one multi-phase boss.
- One optional route, secret, or score challenge with a visible cue.

Every later beat should teach, repeat, combine, release, or test. Beats that do none of those should be cut.

### 9.5 Route and secret design

- Put route triggers in visible scenery: generators, gates, marked carriers, asteroid tunnels, or relay nodes.
- Show the trigger state and provide practice restart near it.
- A route should change combat, scenery, midboss, or reward—not only add currency.
- Keep secret conditions readable enough to discover without a guide.
- Preserve deterministic route outcomes in replay/checkpoint data.

### 9.6 Stage authoring work

- [ ] Add StageEncounterTimeline and StageBeatDefinition resources.
- [ ] Author Stage 1 in absolute beats before reconnecting procedural variation.
- [ ] Allow controlled beat overlap and escape completion.
- [ ] Synchronize enemy cues, background zones, landmarks, music states, and dialogue.
- [ ] Add per-stage pressure curves for enemy count, projectile count, speed, and attention roles.
- [ ] Add beat labels and live timeline diagnostics to stage_preview.tscn.
- [ ] Replace generated stage identity claims with explicit beat sheets.
- [ ] Keep seed variation inside authored bounds: mirrored entries, selected lane, cosmetic prop layout, or one of a few approved phrases.
- [ ] Add section-start practice identifiers at every named beat.

---

## 10. Backgrounds, Parallax, Asteroids, and Props

### 10.1 Current opportunity

The project has abundant asteroids and other props. These should become:

- Distant silhouettes and scale references.
- Midground routes, fleets, stations, gates, ruins, and wreckage.
- Near-camera flyovers used only during safe visual beats.
- Gameplay-plane hazards when explicitly promoted with collision and telegraphs.
- Destructible scenery, route gates, cancel targets, and boss-arena parts.

Do not put a collision shape on every decorative asteroid. A visual prop and a gameplay hazard are different content types.

### 10.2 One background architecture

Replace MissionBackdrop plus the empty per-segment ParallaxPresentation path with one StageBackgroundDirector.

The director owns:

- StageBackgroundDefinition.
- Layer stack and tiling.
- Zone timeline.
- Landmark cues.
- Scroll speed and direction.
- Crossfade/slide/cut transitions.
- Background camera offset, mild roll, and altitude transitions.
- Readability grade.
- Reduced-motion behavior.
- Boss-arena lock.
- Prop pools and deterministic decorative seeds.

StageSegmentRuntime should send semantic cues to the director rather than constructing its own background nodes.

### 10.3 Starting depth stack

These ratios are prototype starting points, not measurements copied from a reference game.

| Band | Typical ratio | Content | Rules |
|---|---:|---|---|
| Far sky | 0.02–0.08 | Gradient, stars, distant nebula | Very low contrast and no bullet-sized particles |
| Distant landmark | 0.08–0.18 | Planets, moons, megastructures | Large slow silhouettes |
| Mid environment | 0.20–0.45 | Fleets, ruins, station layers, large asteroids | Establish route and encounter boundaries |
| Gameplay ground/base | 1.00 | Roads, ship decks, trenches, arena plane | Stable reference plane; may host turrets/hazards |
| Near environment | 1.10–1.35 | Sparse beams, fog strips, flyby props | Suppressed during heavy patterns |
| Foreground flyover | 1.35–1.60 | Rare large debris/ships | Only during safe or clearly framed beats |
| Particles | Depth-derived | Dust, sparks, embers | Never match hostile bullet size, core, hue, or trajectory |

### 10.4 Environmental zone design

Each stage background is a 3–5 zone journey:

1. Establish the location.
2. Approach a landmark.
3. Pass over/through/under it.
4. Reveal the threat or route fork.
5. Lock into the boss arena.

Do not loop the same five cells for the entire stage. Repeating textures can support a zone, but landmarks and palette/lighting changes must show progress.

### 10.5 Readability governor

During heavy bullet phrases:

- Lower background saturation and contrast.
- Reduce near-layer opacity.
- Suppress nonessential particles and foreground props.
- Cap explosion bloom and player-shot opacity over hostile cores.
- Keep hostile bullets on a protected render layer.
- Preserve landmark silhouettes without small high-frequency detail.
- Apply changes over 150–300 ms to avoid a visible pop.

Reduced-motion mode:

- Keeps slow environmental drift rather than freezing all depth.
- Removes or greatly reduces roll, acceleration, near flyovers, and rapid crossfades.
- Never changes gameplay timing or safe lanes.

### 10.6 Prop content model

StagePropDefinition should include:

- Stable ID and approved visual family.
- Decorative, landmark, destructible, or hazard role.
- Depth band and scroll ratio.
- Scale class, pivot, facing, and allowed rotation.
- Animation and variant list.
- Collision profile only when gameplay-relevant.
- Spawn mode: authored cue, tiled field, seeded scatter, attached to landmark, or pooled flyover.
- Lighting/tint/readability response.
- Reduced-motion substitute.
- License and attribution metadata.

### 10.7 Asteroid-field rules

- Curate asteroid families by size and silhouette rather than spawning every source record.
- Far and mid asteroids are decorative and collision-free.
- Gameplay asteroids have a strong outline, warning entry, honest collision core, depth shadow, and distinct speed.
- No decorative asteroid may share the gameplay-hazard outline or shadow.
- Use large slow objects for macro routing and small sparse objects for texture; avoid random pinball clutter.
- Seeded layouts must pass safe-corridor validation.

### 10.8 Background acceptance gate

- Stage 1 has at least three recognizable environmental zones and three named landmarks.
- Ten-minute seam test shows no exposed edges, jumps, or repeated landmark pop.
- Dense-pattern screenshots remain readable in normal, high-contrast, and colorblind palettes.
- Near props never cover the player core or untelegraphed hostile bullets.
- Background motion reduction preserves route comprehension.
- Background state restores correctly after pause, checkpoint, retry, and boss practice.
- The same stage seed reproduces prop layout where layout matters.
- Minimum-spec hardware sustains 60 FPS with background, bullets, enemies, and effects active.

---

## 11. Boss Design

Each boss should be a stage grammar exam and a physical spectacle.

### Boss phase structure

1. **Teach:** one clear emitter rule and generous recovery.
2. **Remix:** combine the rule with movement, a second emitter, or a targetable part.
3. **Mastery:** denser authored topology, arena interaction, or controlled Rank branch.

### Required behaviors

- Intro does not accept damage until the player can read the arena.
- Every phase transition clears or safely resolves old bullets.
- Targetable parts have obvious silhouettes, hit feedback, and reward consequences.
- Enrage is visible and audible before behavior changes.
- Boss motion cannot pin the player without a validated escape.
- Anti-milking timer or diminishing score applies per phase.
- Boss Practice can start at every phase with configurable resources.
- Destroyed parts and armor fracture alter the model, emitters, and background arena.

Use the large boss/ship-part library to assemble genuinely different silhouettes rather than tinting one command ship for many encounters.

---

## 12. Menus, HUD, Practice, and Results

### 12.1 New information architecture

Top-level menu:

1. **Play**
2. **Practice**
3. **Hangar**
4. **Records & Replays**
5. **Settings**
6. **Extras**
7. **Quit**

Play contains Story, Arcade, Challenge, and Local Co-op. Online remains clearly labeled as post-launch/lab scope until it passes its existing gate.

Practice contains:

- Playable Tutorial
- Stage Practice
- Section Practice
- Boss Practice
- Pattern Lab
- Replay/Ghost Practice

Profiles lives in a persistent profile switcher on the title/front-end shell. The Campaign Map lives inside Story. Extras contains Codex, Gallery, Credits, Support, licenses, and other non-run content. Online appears under Play only when it passes the existing production gate; until then it remains clearly labeled lab/post-launch scope.

Do not put Campaign Map, Profiles, Online, Support, Credits, Codex, and every progression system as equal-weight buttons on the first screen.

### 12.2 Launch flow

**Play → Mode card → Difficulty card → Ship/loadout preview → Regulation/assist summary → Launch**

The returning-player quick path should remember selections and offer Continue or Quick Arcade in one confirmation.

Every mode card shows:

- Plain-language purpose.
- Approximate run length.
- Lives/continues/checkpoints.
- Bullet-density and difficulty intent.
- Overdrive/Element rule changes.
- Score/leaderboard eligibility.
- Recommended experience.
- Ten-second visual preview.

### 12.3 Hangar

The Hangar must visually preview:

- Ship animation and hitbox core.
- Normal and focus movement trails.
- Rapid Shot pattern.
- Focus Beam pattern.
- Active Element ability.
- Overdrive effect.
- Relative bars for normal speed, focus speed, coverage, beam DPS, Element recharge, and safety.

Add Test Flight directly from the Hangar. Do not force a full mission to understand a loadout.

### 12.4 HUD hierarchy

#### Immediate, near the playfield

- True hitbox.
- Bomb stock.
- Element icon/energy.
- Overdrive readiness cue.
- Player damage/shield state in readable icons/bars.

#### Tactical, top/side

- Score.
- Chain number and drain bar.
- Rate multiplier.
- Objective/route cue.
- Boss health/phase/timer.

#### Run-level, side rails or pause

- Stage.
- Lives/continues.
- Extra-life progress.
- Upgrade currency and route state.

Replace compressed diagnostic strings with icon-supported bars and labels. Keep the diagnostics overlay separate from the shipping HUD.

### 12.5 Results

Results should show:

- Total score and rank.
- Stage clear/no-miss/no-bomb status.
- Maximum Chain and where it broke.
- Graze count.
- Flux converted/collected.
- Element contribution.
- Overdrive activations and Rank reached.
- Boss phase times.
- Route/secrets.
- Score comparison and personal best.
- Rewards/progression in a separate readable block.
- Retry, next stage, save replay, watch replay, and return.

### 12.6 Practice requirements

- Start at stage, named section, wave, midboss, boss, or boss phase.
- Select ship/loadout/difficulty.
- Set Bomb, Element, Overdrive, Chain, Rate, Rank, lives, and boss health.
- Instant restart hotkey with a target below two seconds.
- Slow motion and frame step.
- Input display.
- Player hitbox, graze radius, bullet hitbox, safe-lane, and conversion overlays.
- Save/load practice presets.
- Import replay ghost/input stream.
- No leaderboard submission under modified conditions.

### 12.7 Pause requirements

- Resume.
- Instant restart section/stage with confirmation option.
- Controls/remapping.
- Display and accessibility settings.
- How to Play/gauge definitions.
- Photo/screenshot mode only if it safely pauses all simulation.
- Quit to menu.

### 12.8 UI implementation work

- [ ] Split production/ui/menu_shell.gd into scene-backed pages and presenters.
- [ ] Create a shared navigation shell, transition controller, focus manager, and regulation badge.
- [ ] Build Play, Practice, Hangar, Records, Settings, and Pause scenes.
- [ ] Keep data access in presenters/models, not scene construction code.
- [ ] Add animated ship/shot previews with reduced-motion fallbacks.
- [ ] Add a responsive portrait-plus-side-rails layout.
- [ ] Add automatic focus tests and controller-navigation screenshots.
- [ ] Replace raw dictionary formatting with player-facing formatters.
- [ ] Add first-run calibration and a skippable/replayable playable tutorial.

### 12.9 Menu acceptance gate

- A new player can reach a recommended first run without understanding internal content IDs or version labels.
- A returning player can restart Arcade play in under 30 seconds.
- Every page is completable with keyboard only and controller only.
- No dead-end focus, clipped text, or hidden critical prompt at supported UI/text scales.
- Changing a binding updates glyphs immediately.
- Pause exposes controls, display, and accessibility settings.
- Assisted/non-regulation rules are visible before launch and in results.

---

## 13. Audio and Feedback

The references pair patterns and music tightly. Add audio work to every gameplay phase rather than leaving it until content completion.

- Rapid Shot, Focus Beam, Element, Bomb, Overdrive ready/activate/end, graze, Flux, Chain warning/break, player hit, laser gate, cancel target, boss phase, and route cue need distinct sounds.
- Graze sounds must be rate-limited and pitch/volume-grouped.
- Chain drain needs an escalating warning that does not mask bullets or damage alerts.
- Boss and stage music states align to named timeline beats.
- Background flyovers and landmarks use ambience without competing with telegraphs.
- Audio priority prevents warning cues from being voice-stolen.
- Reduced sensory settings may lower repetition/intensity without removing semantic cues.

---

## 14. File and Data Change Map

| Current area | Planned change |
|---|---|
| production/content/definitions/ship_definition.gd | Add or reference regulation movement, hitbox, graze, shot, beam, and Element data. |
| production/movement/player_movement_controller.gd | Add direct arcade movement path; remove acceleration from regulation play. |
| production/services/input_service.gd | Radial dead zone, authored top-speed cap, buffered actions, simplified action grammar, binding migration. |
| production/actors/production_player.gd | Replace universal action orchestration with Rapid/Focus/Element/Overdrive/Bomb states. |
| production/actors/production_projectile.gd | Definition-driven collision, graze state, cancel class, conversion support, honest visuals. |
| production/missions/mission_score_tracker.gd | Chain drain bar, beam hold, graze, Element contribution, Flux, Bomb, Overdrive, Rank. |
| production/combat/super_mode_runtime.gd | Evolve into Overdrive with conversion, recovery, Rank, replay state. |
| production/enemies/enemy_movement_controller.gd | Timeline/path execution and authored state transitions. |
| production/enemies/enemy_attack_controller.gd | Telegraph, phrase timing, emitter composition, difficulty variants. |
| production/content/definitions/attack_pattern_definition.gd | Emitter layers, topology, safe-lane metadata, cancel class, presentation cues. |
| production/stages/encounter_package_resolver.gd | Stop defining flagship combat by generic duplication; limit to bounded variants. |
| production/stages/stage_segment_runtime.gd | Emit semantic background/timeline cues; do not construct a separate empty parallax stack. |
| production/presentation/mission_backdrop.gd | Replace with StageBackgroundDirector after migration. |
| production/presentation/parallax_presentation.gd | Fold useful layer behavior into the director; remove duplicate ownership. |
| production/ui/menu_shell.gd | Split into scenes/presenters. |
| production/missions/mission_hud.gd | Arcade HUD hierarchy and regulation feedback. |
| production/ui/results_screen.gd | Score/route/replay breakdown plus separate progression rewards. |
| tools/asset_catalog | Add curated contact sheets and visual-family/prop onboarding reports. |

### New recommended resources/classes

- ArcadeShipProfile
- ElementDefinition and ElementRuntime
- GrazeComponent
- BulletConversionService
- EnemyVisualFamilyDefinition
- EnemyBehaviorScoreDefinition
- MovementPathDefinition
- AttackPhraseDefinition
- DifficultyPatternVariant
- StageEncounterTimeline
- StageBeatDefinition
- StageBackgroundDefinition
- StageBackgroundDirector
- StageBackgroundZoneDefinition
- StagePropDefinition
- RegulationProfile

Names may change, but ownership boundaries should remain explicit.

---

## 15. Phased Roadmap

### Phase 0 — Baseline and design freeze

**Estimate:** 3–5 working days

**Goal:** Capture the current feel and define the prototype experiment.

- [x] Export a current debug build as a comparison artifact.
- [x] Freeze Vanguard, Pulse Cannon, Raider Scout/Arrowhead, and the first 30 seconds of Stage 1 as the prototype comparison set.
- [x] Add the Ship Feel Lab debug display for movement speed, input vector, collision core, graze ring, displacement trace, and fixed tick.
- [x] Document control hypotheses, A/B profiles, and the target-hardware capture matrix in `docs/PHASE_0_BASELINE.md`.
- [ ] Record the target-hardware gameplay/menu video, screenshots, frame-time/projectile capture, and input traces listed in that baseline document.

**Gate:** Reproducible before/after comparison exists.

### Phase 1 — Ship Feel Prototype

**Estimate:** 7–10 working days

**Goal:** Prove immediate movement, focus, hitbox, and shot/beam transitions.

- [x] Implement direct no-inertia regulation movement.
- [x] Implement radial analog input with a capped response curve.
- [x] Implement a 4.5-pixel honest hitbox and a separate 28-pixel graze ring.
- [x] Implement Focus Beam priority over Rapid Shot with no empty input mode.
- [x] Add the controller/keyboard/arcade-stick Ship Feel Lab.
- [x] Add Inspector-configurable A/B focus-ratio and hitbox profiles plus automated acceptance coverage.
- [ ] Run the required target-hardware and human control tests in Section 6.7.

**Gate:** Section 6.7 passes. Do not start stage content before this gate.

### Phase 2 — Closed Combat/Score Loop

**Estimate:** 10–15 working days

**Goal:** Graze, Chain, Flux, Element, Bomb, and Overdrive form one understandable loop. Automated implementation/acceptance completed 2026-08-01 (`tests/phase23_arcade/phase23_arcade_acceptance.gd`).

- [x] Implement collision/graze/conversion state.
- [x] Implement Chain bar and beam hold.
- [x] Implement one Attack Element, one Control Element, and one Defense Element.
- [x] Implement Overdrive activation/recovery and Story auto-bomb option.
- [x] Build HUD prototype and results breakdown.
- [x] Add deterministic replay state.

**Gate:** Newcomers can describe the loop; experts can find at least two meaningful score routes in the test room.

### Phase 3 — Enemy Choreography and Authoring Tools

**Estimate:** 15–20 working days

**Goal:** Replace same-deck enemies with roles, paths, phrases, telegraphs, and difficulty variants. Automated implementation/acceptance completed 2026-08-01 (`tests/phase23_arcade/phase23_arcade_acceptance.gd`).

- [x] Add visual-family/archetype/behavior/encounter separation.
- [x] Implement six core roles and ten attack phrases.
- [x] Implement path resources and telegraph state.
- [x] Upgrade enemy laboratory and stage preview.
- [x] Add safe-lane and deterministic replay validators.

**Gate:** A two-minute combat course teaches, combines, releases, and tests three pattern verbs without random dead ends.

### Phase 4 — Asset and Prop Curation

**Estimate:** 10–20 working days, partly parallel

**Goal:** Turn the large source library into searchable runtime-ready families.

- Generate curated enemy, boss-part, asteroid, turret, prop, background, and effect contact sheets.
- Deduplicate/assemble candidates.
- Approve Stage 1 visual families.
- Create StagePropDefinition and EnemyVisualFamilyDefinition resources.
- Validate scale, pivots, hitboxes, animation, palette, and licenses.

**Gate:** Stage 1 has an approved visual kit with no placeholder silhouettes.

### Phase 5 — Stage 1 Gold Re-author

**Estimate:** 20–30 working days

**Goal:** Deliver one complete 6–7 minute flagship stage.

- Author the encounter timeline and background storyboard together.
- Build three or more environmental zones and landmarks.
- Add eight enemy visual families and six roles.
- Add a midboss and three-phase boss.
- Add route/secret, practice sections, music states, tutorial cues, and results.
- Tune Novice, Arcade, and Expert variants.

**Gate:** Stage 1 passes human controls, readability, pacing, fun, accessibility, and minimum-spec performance review.

### Phase 6 — Front End, HUD, Practice, and Replays

**Estimate:** 15–20 working days

**Goal:** Make the polished loop discoverable and trainable.

- Split MenuShell.
- Implement new information architecture and loadout previews.
- Complete interactive tutorial, practice, pause, replay, HUD, and results.
- Verify all input devices, text scales, TATE/side rails, and regulation badges.

**Gate:** A player can install, learn, practice, play, retry, save a replay, and understand results without developer help.

### Phase 7 — Five-Stage Arcade Route

**Estimate:** 8–14 weeks after tools and Stage 1 are proven

**Goal:** Complete the reference-quality flagship run.

- Produce Stages 2–5 in environment/encounter batches.
- Add stage-specific enemies, props, bosses, music, and routes.
- Reuse combat verbs intentionally, not by generic duplication.
- Add final-stage reprise and true-final challenge conditions if desired.
- Run full-route score, replay, performance, and difficulty tuning.

**Gate:** Full run is 28–38 minutes, visually distinct by stage, learnable, replayable, and stable.

### Phase 8 — Campaign Reconciliation and Scale

**Estimate:** Re-plan after Arcade Route Gold

**Goal:** Apply the proven grammar to the 60-stage campaign without diluting it.

- Decide whether all 60 stages remain in 1.0.
- Assign each stage a flagship environment kit, authored beat sheet, unique landmark/set piece, route/reward purpose, and boss/miniboss identity.
- Use the broad enemy/prop library through curated encounter variants.
- Bound RPG progression against regulation movement/pattern design.
- Preserve story/co-op/objectives only where they strengthen the arcade rhythm.

**Gate:** No stage is approved solely because a deterministic recipe validates.

---

## 16. First 30 Work Items in Order

1. Create the gameplay-redesign ADR draft and link this plan.
2. Capture current Stage 1 video, input, frame-time, and collision baseline.
3. Add a dedicated ship-feel laboratory scene.
4. Add debug hitbox, graze ring, velocity, and fixed-tick display.
5. Add regulation movement fields to ship data.
6. Implement direct no-inertia movement.
7. Implement radial dead zone and remove sensitivity-based speed multiplication.
8. Implement honest player hitbox and separate graze radius.
9. Implement Rapid Shot/Focus Beam input priority with no dead frames.
10. Add always-visible/focus-visible hitbox options.
11. Test keyboard, D-pad, analog, and arcade stick.
12. Select prototype speed/focus/hitbox values through recorded playtest.
13. Replace the universal control tutorial with the compact action grammar.
14. Add projectile-definition-driven collision.
15. Implement once-per-projectile graze tracking.
16. Implement Chain drain and Focus Beam chain hold.
17. Implement Flux conversion and collection.
18. Convert one spell/shield/heavy tool from each category into three Element prototypes.
19. Expand Overdrive with activation clear, timed power, and recovery.
20. Implement manual Bomb and optional auto-bomb with visible penalties.
21. Build the prototype arcade HUD and score breakdown.
22. Add telegraph consumption to EnemyAttackController.
23. Add path/timeline movement resources.
24. Build six enemy combat archetypes using existing approved visuals.
25. Build ten reusable attack phrases with three difficulty variants each.
26. Upgrade enemy laboratory and section-restart practice.
27. Generate curated enemy/asteroid/prop contact sheets from the full manifest.
28. Approve the Stage 1 enemy, prop, landmark, and effect kit.
29. Implement StageBackgroundDirector and migrate Stage 1 away from MissionBackdrop.
30. Author and playtest the new Stage 1 encounter/background timeline.

---

## 17. Verification and Playtest Plan

### 17.1 Automated

- Fixed-tick movement displacement and diagonal normalization tests.
- Input priority/buffer tests for Rapid, Focus, Element, Overdrive, Bomb, and Pause.
- Player/projectile collision-core agreement tests.
- Once-per-projectile graze and multiplayer attribution tests.
- Bullet conversion determinism and pool-reset tests.
- Chain/Rate/Overdrive snapshot and checkpoint tests.
- Enemy behavior-score determinism tests.
- Telegraph-before-fire tests.
- Rank-branch selection tests that prohibit topology changes inside an active phrase or phase.
- Safe-lane spatial sampling for authored patterns.
- Stage-timeline cue ordering and replay restoration tests.
- Background seam, zone restore, and reduced-motion state tests.
- Controller focus graph and no-dead-end menu tests.

### 17.2 Human cohorts

At minimum:

- Five players new to bullet hell.
- Five regular shmup players.
- Keyboard-only, controller, D-pad, analog stick, and arcade-stick coverage.
- Reduced motion/flash, high contrast, auto-fire, auto-bomb, and game-speed assistance coverage.
- Solo and local co-op passes.

Record:

- Input device and display.
- Time to understand normal/focus movement.
- Death location and cause.
- Bomb/Element/Overdrive usage.
- Chain breaks and score-route choices.
- Background/bullet confusion.
- Menu time-to-launch and navigation errors.
- Stage beat timestamps.
- Perceived fairness, control confidence, and desire to retry.

### 17.3 Quantitative starting gates

| Metric | Initial target |
|---|---:|
| Regulation simulation | Stable fixed 60 Hz |
| Engine input response | Same or next fixed tick |
| Normal Stage 1 duration | 6–7 minutes |
| Flagship Stage 1 boss | 75–120 seconds for intended loadout |
| Practice restart | Under 2 seconds |
| Returning-player menu to launch | Under 30 seconds |
| Dense normal projectile load | Authored under readability budget |
| Synthetic projectile stress | 2,000 pooled projectiles without failure |
| Background seam soak | 10 minutes per zone |
| Full Arcade Route | 28–38 minutes |
| Unintentional dead air | No more than 2–3 seconds outside authored release beats |

Performance numbers must be measured on the declared minimum-spec machine.

---

## 18. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Hundreds of assets become hundreds of shallow enemies | High | Separate visual families from combat archetypes and behavior scores. Curate per stage. |
| Asteroid/prop volume creates clutter | High | Depth-tag assets, keep decorative props collision-free, use a readability governor. |
| Five-button compact scheme still feels busy | High | Prototype before content; core stage remains solvable with Rapid and Focus alone. |
| Removing RPG actions wastes existing systems | Medium | Repackage them as Element choices, passives, ship identity, or non-regulation modes. |
| RPG speed upgrades break safe lanes | Critical | Fix regulation movement per ship; bound Story modifiers and record assists. |
| Graze/Chain/Element/Overdrive becomes too complex | High | One HUD hierarchy, interactive drills, staged unlock of concepts, user comprehension gate. |
| Background spectacle harms bullets | Critical | Protected bullet layer, background dimming, near-layer suppression, contrast tests. |
| Procedural generation fights authored routing | High | Use procedural selection only within approved beat variants. |
| Sixty stages dilute quality | Critical | Gold five-stage route first; cut scope before lowering stage identity. |
| Co-op doubles visual noise | High | Widen formations, cap effects, distinct player cores, avoid simply doubling bullet speed/count. |
| Multiple difficulty modes multiply content cost | High | Shared phrase data with authored topology variants and automated validation. |
| Reference inspiration becomes imitation | Critical | Use structural lessons only; no copied art, music, names, layouts, exact patterns, or proprietary content. |

---

## 19. Definition of Done

The redesign is successful when:

- The ship feels immediate and precise on keyboard, controller, D-pad, analog, and arcade stick.
- The true hitbox and every hostile projectile core are visually honest.
- Rapid and Focus are both required by authored play without input friction.
- Graze, Chain, Element, Flux, Bomb, and Overdrive form one understandable risk/reward loop.
- Enemy difficulty comes from roles, timing, routes, pattern phrases, and controlled overlap—not stat inflation or random pursuit.
- The large enemy/asteroid/prop library is searchable and can be promoted through a repeatable visual-family pipeline.
- Every flagship stage is recognizable from a screenshot, a landmark, an enemy grammar, and a music beat.
- Backgrounds progress through locations and never hide gameplay.
- Menus explain modes and loadouts in plain language and work completely with controller or keyboard.
- Practice can restart any named section or boss phase quickly with configurable state.
- Replays are deterministic and useful for learning.
- Novice preserves spectacle and teaches; Arcade is the intended ruleset; Expert increases authored risk.
- Stage 1 and the five-stage Arcade Route pass external human playtests and exported-build performance gates.
- Campaign content is not marked complete until each stage is authored, presented, practiced, and playtested—not merely generated.

---

## 20. Research Notes and Limitations

- Exact hitbox sizes, movement units, dead zones, acceleration values, and total input latency are not consistently published for the reference games. This plan uses their verified control relationships and treats numeric values as prototype targets.
- Background layer counts and parallax ratios in the references are not reliably documented. The ratios in this plan are original starting values to test in Galax Hero.
- Longplay observations are useful for route, pacing, and visual analysis but are labeled as observations rather than official rules.
- Critical claims favor official developer pages, official store descriptions, developer interviews, and established technical references. Reviews are used mainly for control impressions, readability criticism, and menu/usability observations.

### Additional reference links

- [Caladrius Blaze Steam page](https://store.steampowered.com/app/386770/Caladrius_Blaze/)
- [Caladrius Blaze Nintendo Life review](https://www.nintendolife.com/reviews/nintendo-switch/caladrius_blaze)
- [Caladrius Blaze technical/player controls summary](https://www.xboxachievements.com/forum/topic/421772-achievement-guide-and-roadmap/)
- [DoDonPachi Resurrection official Steam page](https://store.steampowered.com/app/464450/DoDonPachi_Resurrection/)
- [DoDonPachi Resurrection port/training study](https://www.hardcoregaming101.net/dodonpachi-daifukkatsu/)
- [DoDonPachi Resurrection gameplay/control review](https://www.thesixthaxis.com/2011/11/09/dodonpachi-resurrection-review/)
- [Danmaku Unlimited 3 Nintendo page](https://www.nintendo.com/us/store/products/danmaku-unlimited-3-switch/)
- [Danmaku Unlimited 3 Nintendo Life review](https://www.nintendolife.com/reviews/switch-eshop/danmaku_unlimited_3)
- [Danmaku Unlimited 3 gameplay reference](https://shmups.wiki/library/Danmaku_Unlimited_3)
