# Phase 19 — Online Cooperative Multiplayer

Phase 19 adds a two-player, host-authoritative online layer over the Phase 16 cooperative identities and Phase 18 campaign. Peer 1 owns the mission seed and graph, actor/spawn state, damage, deaths, drops, objectives, score, boss phases, checkpoint snapshots, and reward results. Clients send ordered input and projectile requests; authority-only message types from a client are rejected.

## Runtime architecture

- `OnlineTransport` provides an ENet host/client transport with validated packets. Steam remains optional: platform lobbies and invitations are advertised only when the provider exists, while direct-IP and network simulation remain available in standalone development builds.
- `NetworkProtocol` owns the protocol version, message schemas, deterministic state hashing, and build/content compatibility manifests.
- `OnlineSessionCoordinator` owns ordered message acceptance, authoritative world snapshots, score, damage, objectives, boss phases, checkpoints, rewards, and disconnect handling.
- `MovementPredictor` provides local prediction, acknowledged-input replay, interpolation, boundary clamping, dash correction, pause behavior, and large-error teleport correction.
- `ProjectileNetworkReplicator` sends event-driven spawns/interactions. It does not stream every projectile transform. The host verifies owner, direction, speed, hit, reflection, absorption, and destruction.
- `OnlineLobby` provides create/join/leave, profile/ship/loadout selection, ready state, compatibility rejection, and an explicit no-host-migration shipping policy.
- `OnlineDisconnectManager` supports AI takeover for a disconnected remote player, a 30-second reconnect window, checkpoint restoration, reward eligibility, and host-disconnect mission abort.
- `NetworkDiagnostics` reports ping, packet loss, snapshot age, correction count, desync warnings, authority peer, stage seed, and event sequence.

## Rollout and safety

`OnlineRolloutPolicy` enforces the production order: boss practice, arcade, one campaign stage, Operation 1, then the full campaign. `GameSessionConfig` requires two peer identities, authority peer 1, matching seed, and a stage-graph hash. Campaign-generated online configs validate two-player clearance before launch.

Rewards retain stable transaction IDs and are accepted once by host authority. A disconnect snapshot never directly mutates persistent progression, and reconnect restores only the authoritative checkpoint. Version or content mismatch blocks joining with a player-readable reason.

## Verification

```powershell
godot --headless --path . --script res://tests/phase19/phase19_acceptance.gd
```

The suite covers lobby/version checks, prediction under latency, seed/graph synchronization, projectile reflection authority, forged damage rejection, boss phase and score synchronization, reconnect safety, duplicate reward protection, desync detection, campaign configuration, and rollout gating. The online test lab is `res://production/network/online_test_lab.tscn`.
