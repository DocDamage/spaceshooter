# Phase 4 — Input, UI, Settings, and Accessibility

Phase 4 supplies the shared interaction layer for later production screens.

## Runtime entry point

Run the project to open the controller-first command menu. It includes profile/device assignment, persistent settings, live accessibility preview, safe control rebinding, and an input test. Launching the architecture test mission exposes the pause shell with the same navigation conventions.

Keyboard emergency navigation always retains Enter/Space for confirm and Escape for cancel. A disconnected controller is unassigned and menu input falls back to keyboard and mouse. Devices cannot be assigned to more than one local player unless shared-device mode is explicitly enabled.

Settings and bindings are stored atomically as schema-versioned JSON at `user://settings_v1.json`. Accessibility assists are recorded in run metadata and never block campaign progression.

## Validation

```powershell
godot --headless --path project --script res://tests/phase4/phase4_acceptance.gd
```

The harness checks the complete action catalog, default bindings, assignment rules, glyph selection, conflict recovery, emergency bindings, persistence, reusable UI controls, and accessibility metadata.
