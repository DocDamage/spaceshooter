# Phase 11 — Pseudo-3D Presentation, Camera, Effects, and Audio

Phase 11 adds a presentation layer that never owns gameplay coordinates or collision. `PresentationActor` applies altitude, banking, pitch, scale, offsets, shadows, and explicit targetability to a visual child while the actor's `Area2D` remains the collision truth. `ShipPresentation` provides thrust, glow, shield, damage, super-mode, and recoil feedback without changing movement or damage systems.

`ParallaxPresentation` supports far, middle, near, foreground flyover, particle, and environmental-lighting layers. Background definitions now include looping, transition, reduced-motion, environment tags, and layer order. `PresentationCameraRig` supports one or more local players, look-ahead, boss framing, bounded source-layered shake, zoom, and reduced-motion replacement.

`ScreenEffectsController` gates flashes, overlays, speed lines, and distortion through accessibility settings. `EffectsPoolManager` pools eight effect categories, caps the global active count at 200, applies category budgets, and drops decorative work before gameplay-critical feedback.

`GameAudioService` creates Master, Music, Ambience, Weapons, Explosions, Player, Enemies, Dialogue, and UI buses. It supports saved volume/mute settings, dynamic-range dialogue ducking, boss-music transitions, bounded emitters, priority eviction, and safe pitch variation. `VibrationRouter` exposes the eight planned event categories and applies category, strength, and global accessibility settings.

Run acceptance and stress coverage with:

```powershell
godot.cmd --headless --path . --script res://tests/phase11/phase11_acceptance.gd
```

The project version is `0.11.0`. Phase 11 does not alter save schema 9 because presentation state is transient and reconstructed from gameplay state.
