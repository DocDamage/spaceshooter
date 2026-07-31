# ADR 0003: Local Co-op for 1.0; Online as a Gated Update

- Status: Accepted
- Date: 2026-07-31

## Decision

Version 1.0 promises solo play and two-player local cooperative play across the approved campaign and modes. Two-player online co-op remains disabled in public release messaging and shipping navigation until the real-machine beta gates pass on two PCs, two networks, and representative latency/loss profiles.

The host-authoritative protocol, lobby, prediction, reconnect, and simulation work stays in production and may be exposed in development builds as a labeled test lab. There is no host migration; host loss ends or checkpoint-recovers the run with a clear message. Four-player play, PvP, dedicated servers, and cross-platform matchmaking are out of scope.

## Release gate

Online may move into a post-launch release only after the complete real mission—not a lab simulation—passes synchronization, attribution, disconnect, save, boss, reward-idempotency, security, and 60-minute soak tests on real machines.
