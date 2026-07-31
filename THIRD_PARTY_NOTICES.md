# Third-Party Notices

Galax Hero includes approved runtime derivatives selected from the owner's local asset library. Approval to use an asset in this project does not change the asset's original license.

The machine-readable source, license, author, and approval records are maintained in:

- `tools/asset_catalog/generated/manifest.json`
- `tools/asset_catalog/owner_approval.json`

Only files copied into `assets_runtime/` and listed as approved may enter a release export. The raw library at `../assets/` is an external production source and is neither part of this repository nor part of a game export.

The 0.20.0 runtime set contains 23 approved derivatives grouped under these source/license records:

- 10 assets from `Space Shooter Pack – 2D Pixel Art Ships, Enemies, VFX & Music/license.txt` (`approved_cc0`).
- 7 assets from `SpaceShooter/license.txt` (`approved_cc0`).
- 5 audio assets from `parallax and backgrounds/Space Shooter files/public-license.txt` (`reviewed_commercial`, attribution not required by the recorded license).
- 1 project-owned Galax Hero application icon recorded by `art_source/generated/LICENSE.txt` (`owner_created`, attribution not required). The project-owned 16:9 key art is cataloged separately as marketing-only and is not packed into the game.

The exact stable IDs, source paths, SHA-256 hashes, runtime paths, and review state are authoritative in the generated manifest. None of the 23 runtime records is marked as requiring attribution.

Godot Engine is distributed under the MIT License. See the official Godot distribution accompanying the editor/export templates for its copyright and license notices.

Before a public release, the release owner must regenerate the catalog reports, preserve the referenced source-license evidence, review every `license_hold` or missing attribution record, and append any newly required attribution text to this document. Approval of visual quality is not a substitute for license clearance.
