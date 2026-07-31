# Galax Hero generated art sources

`galax_hero_app_icon.png` is the preserved project-owned source for the shipping
application icon. Its approved runtime copy is
`res://assets_runtime/ui/galax_hero_app_icon.png`.

Final generation prompt:

> Create an original square emblem of a compact upward-facing starfighter cutting
> through a circular galaxy arc. Use crisp pixel-art-inspired geometry, a deep
> navy/cyan/ice-blue palette with one gold accent, a bold centered silhouette, no
> text, no trademarked imagery, and enough safe padding to read at 32 pixels.

Generation path: OpenAI built-in image-generation tool. The exact source and
runtime SHA-256 hashes are retained in the generated asset manifest.

## Comms portrait atlas

`galax_hero_comms_portraits_source.png` preserves the original 4×2 generation.
`galax_hero_comms_portraits.png` is the transparent, chroma-keyed production
master promoted to `res://assets_runtime/portraits/comms_portrait_atlas.png`.
The cells are Command, Nova, Kael, Reyes, Rook, Corsair, Corsair Ace, and Wing,
in reading order. Each cell is 448×448 pixels.

Final generation prompt:

> Create one original 4×2 atlas of eight square sci-fi comms portraits in a
> cohesive painted arcade-game style. Reading order: an older Black woman fleet
> commander in navy-and-gold uniform; pilot Nova in a blue flight suit; scientist
> Kael with alien-tech accents; rescue officer Reyes; veteran wingman Rook;
> masked pirate Corsair; younger armored Corsair Ace; and an anonymous helmeted
> allied wing pilot. Use consistent head-and-shoulders framing, strong silhouette
> lighting, no text, no logos, no borders, and a perfectly flat bright magenta
> background for transparent extraction. Keep every figure safely inside its cell.

Generation mode: OpenAI built-in image-generation tool, new image generation.
The transparent production master was derived locally by removing the flat
magenta background; no character pixels were redrawn.
