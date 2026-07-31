# ADR 0006: Bounded, Replay-Safe Progression

- Status: Accepted
- Date: 2026-07-31

## Decision

Profiles advance from level 1 through 99. Allocated statistics have explicit caps; final effective values are calculated in the order base ship, allocation, equipment, skill, temporary upgrade, status, difficulty/co-op modifier. Equipment uses typed slots and two-or-more-piece set bonuses. Permanent weapon/spell upgrades are paid once and capped by their definitions.

Respec always requires confirmation. Training respec is free; campaign respec has a visible currency cost and refunds exact points. Mission rewards are idempotent transactions. Failure may keep explicitly collected session currency at a reduced rate but never grants completion, boss, secret, or first-clear rewards. Replays cap farmable rewards at 70% unless a mode defines a lower value.

New Game Plus carries profiles, equipment, skills, unlocked ships/spells, codex, and campaign decisions. It resets route completion and checkpoints for the new cycle, adds behavioral variants, and never multiplies rewards without a documented economy cap.
