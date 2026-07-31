# ADR 0004: High-Contrast Pixel-Space Art Direction

- Status: Accepted
- Date: 2026-07-31

## Decision

Galax Hero uses crisp, high-contrast pixel-space art selected from the approved catalog. Nearest-neighbor filtering is required for actor, projectile, pickup, and UI sprites. Background gradients and particles may use smooth sampling when they do not blur gameplay silhouettes.

Friendly attacks use cyan/blue-white cores; hostile attacks use coral/magenta/orange cores; pickups use gold/green. Every dangerous projectile has a readable core, optional cosmetic halo, and a collision radius smaller than its visible core. Reduced-flash variants preserve timing through value shifts rather than white-out flashes.

Factions are distinguished first by silhouette, then palette: allied ships point upward and use compact symmetric wings; pirates use angular red silhouettes; synthetic forces use geometric violet forms; imperial forces use broad armored gold/black forms. Boss parts must be target-readable at 540×960. UI uses dark navy panels, cyan focus, gold rewards, red danger, and 4-pixel corner language.

Portraits, backgrounds, actors, VFX, and UI promoted to runtime must share this palette/value standard, have explicit pivots/collision metadata, and pass license, scale, and reduced-motion/flash review.
