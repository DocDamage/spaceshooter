# Support, Privacy, and Diagnostics

Galax Hero 1.0 is standalone-first. Profiles, settings, saves, checkpoints, leaderboards, challenge history, logs, and diagnostic exports remain local. The game sends no analytics and uploads no crash report automatically.

Players can open **Support & Diagnostics** from the main menu and choose **Export Privacy-Safe Diagnostics**. This explicit action creates a JSON report under `user://diagnostics` and opens its location. The report contains build/content/protocol versions, non-identifying OS/render information, FPS/memory/actor/pool state, save status, redacted warnings, and network quality counters if present. It excludes profile names, save contents, account tokens, IP addresses, and automatic upload destinations.

For support, request: issue summary, reproduction steps, build version, whether the problem reproduces offline, input/display hardware, and the player-selected diagnostic file. Never request credentials or the entire user-data directory. The public support address and response-time promise must be inserted in the store page and release package before launch.

Recovery order: restart the game; verify the release checksum/signature; use the in-game recovery detail when offered; preserve `.previous`, `.recovery`, and `.pre_migration_*` generations; attach the opt-in diagnostic report. Do not instruct a player to delete saves as a first response.

Security or privacy reports receive restricted handling. Do not post diagnostic files publicly. Any future telemetry, online identity, automatic upload, or third-party crash service requires a new privacy review, consent design, retention policy, deletion path, and updated disclosure.
