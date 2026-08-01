# Phase 12: Story, Campaign, Pilots, and Wingmen

Phase 12 adds data-driven dialogue contexts behind `StoryService` and a pinned adapter contract, a priority radio queue with checkpoint-safe one-shot tracking, six-operation campaign node/progression models, pilot and wingman definitions, multiplayer-compatible actor slots, wingman commands, codex entries, and persistent profile story state.

Run the acceptance suite with:

```powershell
godot.cmd --headless --path . --script res://tests/phase12/phase12_acceptance.gd
```

Story content is authored as `DialogueDefinition`, `CampaignNodeDefinition`, `PilotDefinition`, `WingmanDefinition`, and `CodexEntryDefinition` resources. Combat code only interacts with the public story, radio, campaign, and command APIs.
