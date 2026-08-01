# Asset Scale Guide

The gameplay viewport uses a 540×960 logical canvas. Visual scale and collision scale are independent: collision shapes favor readable, fair hitboxes even when art has large transparent or decorative margins. Anchors use normalized coordinates, with `[0.5, 0.5]` at the visual center.

| Scale class | Target visual footprint | Collision target | Default layer | Pseudo-altitude |
|---|---:|---:|---|---|
| Player ship | 48–72 px wide | 8–12 px core hit radius | actor | mid |
| Standard fighter | 40–80 px wide | 65–80% of opaque body | actor | mid |
| Elite | 80–140 px wide | 70–85% of opaque body | actor | mid/high |
| Miniboss | 140–260 px wide | composed simple shapes | actor | high |
| Boss | 260–480 px wide | authored parts/simple shapes | actor | high |
| Projectile | 6–32 px readable visual | 45–70% of bright core | projectile | mid |
| Pickup | 24–48 px wide | 80–120% for forgiving collection | pickup | mid |
| Background | viewport-sized or tileable | none | background_far/near | far |

Every catalog record stores `visual_scale`, `collision_scale`, `anchor`, `screen_layer`, and `pseudo_altitude`. These values are authoring defaults, not permission to derive collision from the texture at runtime. Boss art may opt out of the classes when its composition requires authored destructible parts.

Animation metadata is embedded in each manifest record under `animation`: frame width/height, frame count, rows, columns, FPS, looping, named event frames, damage-flash compatibility, and whether the sequence represents destruction. Do not infer irreversible gameplay timing from filenames.
