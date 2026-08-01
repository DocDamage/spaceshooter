# Phase 16: Local Cooperative Multiplayer

Phase 16 establishes the two-player local campaign, boss-practice, and arcade foundation without introducing a second actor stack. Both pilots are `ProductionPlayer` actors registered by stable actor and player-slot IDs and routed through the existing device-aware input service.

`LocalCoopRoster` owns pre-mission joining, unique device/profile validation, guest profiles, ship duplication rules, player colors, host branch ownership, and disconnect reassignment. The roster locks when a mission starts. Guests receive a results summary but never mutate a persistent profile.

`LocalCoopSessionManager` owns individual lives, HP and shields, downed state, limited hold-to-revive behavior, team defeat, participant checkpoint state, and controller-loss pause signals. `CoopRewardDistributor` gives every persistent participant shared XP and currency through profile-specific idempotent transaction IDs, rotates item ownership, and converts duplicate items to salvage. Campaign unlock authority remains with the host.

`PresentationCameraRig` now provides single-screen soft tethering, edge warnings, forced catch-up, teleport recovery, and existing boss framing. `CoopDifficultyScaler` increases enemy presence, target switching, boss health and attack variety, arena margins, revive pressure, and pickup supply. Human pilots consume mission wingman capacity before scaled AI wingmen are allocated.

`CooperativeHUD` renders color-coded per-player HP, shields, spell energy, super charge, team chain, lives, revive availability, command indicators, and downed status. Resource ownership remains in the existing combat and command runtimes.

Run acceptance coverage with:

```powershell
godot.cmd --headless --path . --script res://tests/phase16/phase16_acceptance.gd
```

The initial production target is two players. Three- and four-player support remains gated on readability and Operation 1 completion testing.
