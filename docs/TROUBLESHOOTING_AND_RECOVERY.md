# Troubleshooting, Saves, and Recovery

## First checks

1. Restart the game and reproduce the issue offline.
2. Confirm the displayed version and content revision match the package manifest.
3. Verify the ZIP or installer SHA-256 file and, for a public candidate, its Authenticode signature.
4. Open **Support & Diagnostics** and export the privacy-safe report if support requests it.
5. Preserve affected files. Never delete the user-data folder as a first troubleshooting step.

## Common problems

- **No controller input:** reconnect the device, open **Settings → Input Test**, confirm Windows sees it, then review Bindings. For co-op, two distinct device IDs must be assigned.
- **Clipped or oversized UI:** reset UI/text scale, return to 100% Windows scaling for diagnosis, and test windowed 1280×720. Record display resolution, DPI, mode, and a screenshot.
- **Poor readability or discomfort:** enable reduced flash/motion/shake/particles, simplified patterns, subtitle background, and game-speed assistance.
- **Audio missing:** check Master and category volumes, mute state, output device, and dynamic range. Restart after changing the Windows default output device.
- **Stage appears locked:** complete its direct prerequisite with the same host profile. Guest local-co-op progress does not own campaign unlocks.
- **Online co-op unavailable:** this is expected for the 1.0 standalone scope. The visible online page is a gate, not a broken matchmaking service.

## Save location and generations

On Windows, Godot normally maps `user://` beneath `%APPDATA%\Godot\app_userdata\Galax Hero`. The exact location can be opened from Support & Diagnostics. Profile saves live under `saves/<profile-id>/profile.json`; checkpoints use `checkpoint.json`. Settings, achievement state, local boards, and diagnostics have separate files.

Atomic save replacement retains these generations where applicable:

- the current `.json` document;
- `.json.previous`;
- `.json.recovery`;
- `.pre_migration_vN` when a schema upgrade is committed.

Each save uses a versioned envelope and SHA-256 corruption checksum. The checksum detects damage; it is not anti-cheat protection. Oversized, deeply nested, malformed, or checksum-invalid documents are preserved and rejected rather than silently replaced.

## Recovery procedure

When the game reports recovery, read the in-game status before editing anything. Close the game, copy the complete Galax Hero user-data directory to a safe location, and retain all generations. The loader tries current, previous, then recovery. If required content is missing, restore the matching game build/content rather than resetting the profile.

For upgrade problems, retain the old release package and the pre-migration save copy. Never use an older build to overwrite a save produced by a newer schema unless the release notes explicitly certify backward compatibility. Reinstalling the game does not intentionally delete per-user saves; uninstallers must preserve them.

## Support request contents

Provide the issue summary, exact reproduction steps, version/content revision, offline result, hardware/input/display details, and the player-generated diagnostic file. Do not send credentials, platform tokens, private IP addresses, or the whole user-data directory publicly. Security and privacy reports require restricted handling.

