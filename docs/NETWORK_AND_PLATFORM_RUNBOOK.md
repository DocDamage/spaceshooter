# Network and Platform Runbook

## Supported 1.0 behavior

Galax Hero is standalone-first. Local profiles, saves, achievements, glyphs, direct-IP lab transport, network simulation, and offline fallback are implemented without a store SDK. Public online co-op, matchmaking, invitations, lobbies, and store cloud are deferred by ADR 0003 until real-machine rollout gates pass. Do not market the lab as a shipping feature.

## Trust boundaries

The protocol allows only declared message types, protocol version 19, two sender IDs, positive bounded sequence/tick values, 64 KiB packets, 48 KiB payloads, arrays up to 128 entries, 256 total container entries, 1 KiB strings/keys, and nesting depth 8. Objects, callables, signals, unsupported variants, and non-finite floats are rejected before dispatch. Godot 4.7’s safe object-disallowing decoder is used.

The host owns seed/graph, spawns, enemy state, damage, deaths, drops, objectives, score, rewards, and checkpoints. Compatibility compares protocol, build version, content revision, and manifest hash. Network text and addresses are sanitized. Connection attempts have a timeout and surface explicit failure reasons.

## Provider integration

`PlatformService` accepts a provider through dependency injection and must remain bootable when none exists. Rich presence and invitation strings are sanitized. Cloud paths use a strict storage-key allowlist and documents are capped at 4 MiB. Differing cloud documents always produce an explicit local/remote/keep-both conflict; revision numbers never authorize silent overwrite. Achievement state persists locally and reconciles after a provider becomes available.

Before enabling a provider, test identity, offline launch, provider startup failure, cloud read/write/conflict, achievements, overlay, invitations, privacy disclosure, and account switching. No credential, API key, certificate, or provider token belongs in the repository or package.

## Online rollout gate

Use two Windows PCs and two networks. Test host/client roles, campaign and allowed modes, version/content mismatch, 0–250 ms latency, jitter, 0–10% loss, duplication/reordering, 30-second reconnect, reward ownership, checkpoints, boss transitions, disconnect during results/save, and a 60-minute session. Capture deterministic state hashes and diagnostics. Any host migration promise remains disabled unless separately designed and certified.

