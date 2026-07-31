# ADR 0001: Portrait Playfield in a Desktop Frame

- Status: Accepted
- Date: 2026-07-31

## Decision

Gameplay uses a 540×960 logical portrait canvas. The default desktop window is 960×960 so the playfield is centered with noninteractive side rails; fullscreen and ultrawide displays preserve the full playfield and add horizontal pillarboxing rather than exposing extra gameplay area.

`canvas_items` stretch with `keep` aspect is authoritative. Integer scaling is preferred when it fits; non-integer scaling is permitted to support 720p and window resizing. Gameplay coordinates, spawn bounds, camera bounds, safe areas, and projectile clearance remain in logical pixels. UI safe margins are 20 logical pixels and essential HUD elements remain inside the portrait canvas.

Supported modes are windowed, borderless fullscreen, and fullscreen. The minimum supported display is 1280×720; at that resolution the 540×960 canvas scales to 405×720. UI/text-scale tests must cover 100%, 125%, 150%, 200%, 16:9, 16:10, 4:3, 21:9, and portrait monitors.

## Consequences

Players always see the same combat information and cannot gain an ultrawide advantage. Side rails may later show decorative art, co-op status, or accessibility help, but may not contain required controls until a dedicated responsive layout is implemented.
