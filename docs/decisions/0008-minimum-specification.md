# ADR 0008: Windows Performance and Compatibility Floor

- Status: Accepted
- Date: 2026-07-31

## Minimum PC

- Windows 10 22H2 or Windows 11, 64-bit
- Dual-core 2.5 GHz CPU with four hardware threads
- 8 GiB RAM
- DirectX 11 / OpenGL 3.3-class integrated GPU with 1 GiB shared/dedicated memory
- 2 GiB free storage target pending final content compression
- 1280×720 display
- Keyboard/mouse; controller optional

## Reference tiers

- Low: 8 GiB RAM, integrated Intel UHD-class GPU, 720p display.
- Mid: 16 GiB RAM, GTX 1060/RX 580-class GPU, 1080p display.
- High/compatibility: modern discrete GPU at 1440p/ultrawide.

Input certification covers keyboard/mouse plus current Xbox, PlayStation, and Nintendo-layout controllers through wired and Bluetooth paths. The release target is 60 FPS with 16.67 ms average frame, 25 ms worst gameplay frame, under 2 GiB peak memory, under 10-second cold startup, and under 5-second stage transition on the low tier.
