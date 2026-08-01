# Galax Hero Art Bible

This is the production contract for assets promoted into `assets_runtime/`. The machine-readable manifest and owner approval record remain authoritative for licensing and release inclusion.

## Canvas and pixel treatment

- Gameplay is authored in a 540×960 logical portrait frame. Desktop presentation is 960×960 with pillarbox/side-panel space; gameplay coordinates never stretch to fill widescreen.
- Pixel art uses nearest-neighbor filtering, no mipmaps for actor/UI sprites, whole-pixel source artwork, and uniform X/Y scale. Backgrounds may be cropped but not non-uniformly distorted.
- Player fighters read at roughly 48–64 logical pixels wide. Standard enemies read at 28–48, elites at 45–70, minibosses at 55–90, and operation bosses at 70–130.
- Gameplay collision is authored separately from transparent canvas bounds. Enemy collision normally covers 65–80% of the solid central silhouette. The player is the exception: its bullet-hell damage core is the `ShipDefinition` hitbox (currently 4.5 logical pixels), with a separate 28-pixel graze ring; the core is shown while focusing and may be set to always visible.
- Player and enemy ships face up in source art. Runtime movement/telegraphing communicates faction direction; do not rotate raster ships merely to indicate aim unless the weapon explicitly supports it.

## Silhouette and faction language

- Human ships use broad bilateral wings, bright cyan engine light, orange structural accents, and an obvious forward nose. Vanguard is the balanced baseline; Bastion is heavier and wider; Lancer must receive its own approved narrow/aggressive silhouette before Gold.
- Operation 1 raiders use green scout crescents, purple interceptor triangles, orange/blue heavy bars, and a tall gray command hull. Roles must be recognizable from shape before tint.
- Never make elite/boss identity tint-only. Size, outline, appendages, motion, attack telegraph, and audio must carry redundant information.
- The frontier environment stays dark navy/black with sparse purple/blue planets. Actor values remain brighter than the field, and hostile projectiles use warm pink/red while player projectiles use cyan/white.

## Rendering layers

1. Far background: dark field and sparse stars.
2. Frontier planet layer: approved transparent 1024×1024 crop, low contrast.
3. Environmental hazards and distant debris.
4. Pickups and objective actors.
5. Player/enemy actors and gameplay projectiles.
6. Impact, shield, explosion, and warning effects.
7. HUD, radio, prompts, branch choice, pause/results UI.

The far field must never reduce projectile contrast. Decorative effects may be dropped under the effects budget; gameplay warnings may not.

## Animation and VFX

- Typical fighter animation: 8–18 fps. UI and camera motion may run at frame rate but must honor reduced-motion settings.
- Fire recoil should settle in 80–140 ms; small impacts in 100–220 ms; fighter destruction in 250–500 ms; boss destruction may stage longer without obscuring control or results state.
- Shield art is centered on the collision body and scales with current shield visibility. A fallback outline remains available if the texture is absent.
- Projectiles must remain visible at minimum scale and use a halo plus faction color. Collision radius and visible core should agree within a few pixels.
- Flash, shake, particle density, contrast, and damage overlays must route through stored accessibility settings. Telegraph meaning may not depend on flash alone.

## UI language

- Use deep navy panels, cyan focus/accent, warm warning colors, white primary text, and muted blue-gray secondary text.
- Interactive controls require normal, hover, focused, pressed, disabled, and locked states. Focus should be visible without relying on motion.
- Minimum gameplay text is 16 logical pixels; key titles and state warnings are 22–32. HUD elements stay inside a 20-pixel safe margin.
- Format rewards and rule summaries for people; do not display raw dictionaries or internal stable IDs.

## Import and approval workflow

1. Inventory source assets with `tools/asset_catalog/asset_pipeline.py inventory`.
2. Select a need-driven family and add a stable override in `catalog_config.json`.
3. Confirm source license/owner attestation, attribution requirements, role, scale, collision, import profile, and content links.
4. Set `import_status=approved` only after visual, license, and runtime review.
5. Run the approval copy and release validator. Only normalized copies in `assets_runtime/` may ship.
6. Wire through a content definition or an explicitly documented presentation constant; never load from the raw library at runtime.
7. Verify at 540×960, reduced motion, high contrast, solo, and two-player local co-op.
8. Update the content matrix and third-party notices when obligations require it.

## Stage 1 approved family

| Role | Stable asset |
|---|---|
| Vanguard/Bastion | `asset.ship.vanguard_final`, `asset.ship.bastion_final` |
| Raider scout/interceptor/heavy | `asset.ship.raider_scout_final`, `asset.ship.raider_interceptor_final`, `asset.ship.raider_heavy_final` |
| Raider miniboss/boss | `asset.ship.raider_command_final` with distinct scale and encounter behavior |
| Frontier layer | `asset.background.frontier_planets_final` |
| Projectile | `asset.projectile.plasma_orb_01` plus team halo/tint |
| Shield/explosion | `asset.effect.shield_final`, `asset.effect.explosion_raider_final` |

Open Stage 1 art gaps before Gold: a unique Lancer sprite, pickups/objective sprites, hazard-specific art, portraits, complete UI skin application, per-weapon projectile families, and multi-frame boss destruction.
