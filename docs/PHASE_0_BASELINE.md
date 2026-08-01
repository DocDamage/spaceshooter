# Phase 0 Baseline

Captured 2026-07-31 before the arcade-control changes. The comparison build is `builds/development/galax-hero-development.exe` at source revision `c5bb50a`, exported with Godot `4.7.1.stable.official.a13da4feb`; SHA-256: `699be4324ebcef166ce6b50fe21c2866e167b94d60936e7008501bf51d9ae7c9`.

The baseline audit is reproducible from the exported build and the pre-change code. It used the 540×960 playfield, Vanguard, Pulse Cannon, the Raider Scout/Arrowhead encounter family, and the first 30 seconds of Stage 1. Baseline findings were: eased 320 movement with a 153.6 focus speed, a 12-pixel player damage circle, right-stick primary aim, a 0.25 per-axis stick dead zone, and WAV/MP3 runtime audio.

The after-comparison uses [ship_feel_lab.tscn](../production/arcade/ship_feel_lab.tscn), the Phase 1 acceptance test, and the same Stage 1 route. The lab displays fixed tick, input vector, velocity, displacement trace, collision core, graze ring, and the active speed/hitbox profile. Its Inspector exposes the planned A/B values: A = 320/160/4.5 and B = 320/144/4.0 (normal/focus speed/hitbox radius).

Run the retained baseline build for a visual comparison, then launch the lab and record the following target-hardware evidence before beginning Phase 2:

- title/menu path, Stage 1 start, and 30-second pattern-room footage;
- input trace, average/worst frame time, and active projectile count;
- keyboard, D-pad, analog-stick, and arcade-stick diagonal/drift checks;
- a 240 fps external capture for the input-latency claim; and
- five experienced-player and five newcomer control observations required by Section 6.7.

These hardware and human-playtest captures cannot be honestly certified by the headless automated test environment. They remain the formal Phase 1 gate, not a blocker to the implemented prototype or its automated checks.
