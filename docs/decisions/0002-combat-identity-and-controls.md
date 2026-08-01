# ADR 0002: Classic Forward-Fire Combat

- Status: Accepted
- Date: 2026-07-31

## Decision

Classic forward fire is the default combat identity. Movement uses keyboard/left stick; the right stick or pointer biases lock-on and aim-capable equipment but does not turn the base ship into a mandatory twin-stick shooter.

Focus is a held precision-movement action. Dash is a just-pressed burst on a distinct binding and can never share its default control with focus. Primary fire, secondary/heavy fire, spell, melee/parry, shield, super, lock-on, and wingman command are universal input concepts; a missing loadout capability is shown as unavailable rather than silently consuming input.

Auto-fire, focus toggle, shield toggle, aim assistance, simplified patterns, and game-speed assistance are supported runtime settings. Assist use is recorded in run metadata; it never blocks campaign progress, though competitive local leaderboard categories may separate assisted runs.
