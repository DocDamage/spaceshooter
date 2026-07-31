extends Node

## Compatibility facade; the migrated HUD subscribes to these signals.
signal message_requested(text: String)
signal hud_visibility_changed(visible: bool)

var hud_visible := true

func show_message(text: String) -> void:
	message_requested.emit(text)

func set_hud_visible(value: bool) -> void:
	hud_visible = value
	hud_visibility_changed.emit(value)

