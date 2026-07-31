# Phase 15 Operation QA Report

## Automated scope

- Content database validation for the operation bible, ten missions, campaign nodes, recipes, bosses, and rewards.
- Three deterministic review seeds per stage.
- Structural and gameplay validation for all 30 generated plans.
- Midpoint and pre-boss checkpoint presence and order for every plan.
- Ten distinct stage mechanics and miniboss attack identities.
- Stage 8 branch/secret-route generation and Stage 10 twelve-segment boss route.
- Sequential fresh-profile progression through Stages 1–10.
- Locked-stage rejection, idempotent rewards, replay reward cap, and economy gates after Stages 3, 6, and 10.
- Practice unlocks for all ten minibosses and declared bosses.
- Profile persistence and Operation 2 campaign handoff.
- Phase 10–14 regression coverage and Windows debug export smoke coverage.

## Economy targets

| Gate | Expected level | Fresh-profile currency range |
|---|---:|---:|
| Stage 3 | 3 | 900–3,600 |
| Stage 6 | 6 | 2,200–7,600 |
| Stage 10 | 10 | 4,500–15,000 |

Base completion rewards fit these ranges without a replay requirement. Replays grant seventy percent of calculated XP and currency; completion transaction IDs prevent duplicated claims.

## Manual production review still required

Final art silhouette replacement, authored dialogue prose, controller playthroughs, accessibility perception checks, fresh/expected/overpowered balance runs, and clean-machine export playthroughs remain human review tasks. The automated suite verifies the production data and runtime contracts that make those passes repeatable.
