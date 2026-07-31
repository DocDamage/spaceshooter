# Phase 18: Operations 2–6 and Full Campaign

Phase 18 expands the campaign to 60 stages through `FullCampaignContentFactory`. The catalog declares five complete operation bibles, fifty distinct mission recipes, fifty campaign-map nodes, operation-specific enemy rosters, fifty miniboss attack decks, and five three-phase operation bosses. Recipes reuse the proven segment library; no stage introduces a one-off mission script.

`FullCampaignController` composes all six operations into one progression graph. It validates deterministic seed batches, gates stages and operations in order, persists story decisions and boss practice, supports the entire campaign in local co-op, creates reward-disabled mode reuse and New Game Plus preview sessions, and grants postgame unlocks after Stage 60. Its progression review makes level, equipment tier, weapon/spell targets, unlock pacing, and zero required grind explicit for every operation.

The production boot now uses this controller directly. Its campaign map supports ship selection, solo/two-player launch, generated mission runtime, operation-colored environments and bosses, briefing radio, persisted results, interactive campaign decisions, and return-to-map progression. Operations 2–6 add five specialist ships, three-piece equipment sets with active set bonuses, spell unlock beats, and 100 briefing/results dialogue definitions.

`FullCampaignQARunner` executes the full regression matrix for every stage: deterministic seed batches, local co-op safety, accessibility-pressure generation, midpoint checkpoint round trips, mode reuse, New Game Plus preview, and generation-time budgets. See `phase18_campaign_qa_report.md`.

Operation identities are encoded in the operation bibles and carried into each miniboss attack identity:

- Operation 2: advanced formations, specialization, missiles, equipment sets, and wingmen.
- Operation 3: alien technology, projectile conversion, branches, secrets, and anomalies.
- Operation 4: faction conflict, complex objectives, system pressure, and environmental weapons.
- Operation 5: elites, returning variants, endgame checks, high-tier rewards, and consequences.
- Operation 6: final invasion, combined mechanics, major sequences, decisions, resolution, and postgame.

Run acceptance coverage with:

```powershell
godot.cmd --headless --path . --script res://tests/phase18/phase18_acceptance.gd
```
