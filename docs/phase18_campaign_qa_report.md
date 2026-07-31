# Phase 18 Campaign QA Matrix

The automated Phase 18 matrix covers every campaign stage, not only one representative mission. `FullCampaignQARunner` verifies each stage's authored three-seed batch, solo and two-player graph safety, reduced-pressure accessibility generation, checkpoint serialization/restoration, alternative-mode reuse, New Game Plus preview generation, and generation-time budget.

The acceptance suite additionally performs a complete fresh-profile progression run, verifies all 60 stage gates, rewards, decisions, operation unlocks, miniboss and boss practice entries, equipment acquisition, campaign-map visibility, save reload, and the production boot → campaign map → mission → results → next-stage loop. A runtime two-player launch verifies that the production menu reaches the existing local co-op session stack.

Run:

```powershell
godot.cmd --headless --path . --script res://tests/phase18/phase18_acceptance.gd
```

Release-scale human playtesting is still required for subjective difficulty, narrative pacing, visual identity, and fun; the automated matrix is a deterministic regression gate, not a substitute for playtest sign-off.
