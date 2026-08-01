class_name ScreenEffectsController
extends CanvasLayer

var settings: SettingsService
var overlays: Dictionary = {}

func configure(settings_service: SettingsService) -> void:
	settings = settings_service
	for id in [&"hit_flash", &"vignette", &"damage", &"spell", &"boss_warning", &"low_hp", &"speed_lines", &"distortion"]:
		var rect := ColorRect.new(); rect.name = String(id); rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; rect.color = Color.TRANSPARENT; add_child(rect); overlays[id] = rect

func trigger(effect_id: StringName, intensity := 1.0) -> float:
	var effective := clampf(intensity, 0.0, 1.0)
	if settings != null:
		if effect_id in [&"hit_flash", &"boss_warning"]: effective *= 1.0 - float(settings.get_setting(&"flash_reduction", 0.0))
		if effect_id in [&"speed_lines", &"distortion"]: effective *= 1.0 - float(settings.get_setting(&"background_motion_reduction", 0.0))
		if effect_id in [&"speed_lines"]: effective *= float(settings.get_setting(&"particle_density", 1.0))
	var rect := overlays.get(effect_id) as ColorRect
	if rect != null: rect.color = _effect_color(effect_id, effective)
	return effective

func clear(effect_id: StringName) -> void:
	var rect := overlays.get(effect_id) as ColorRect
	if rect != null: rect.color = Color.TRANSPARENT

func _effect_color(effect_id: StringName, intensity: float) -> Color:
	match effect_id:
		&"hit_flash": return Color(1, 1, 1, intensity * 0.35)
		&"damage", &"low_hp": return Color(0.65, 0.02, 0.04, intensity * 0.32)
		&"spell": return Color(0.12, 0.3, 0.8, intensity * 0.24)
		&"boss_warning": return Color(0.8, 0.05, 0.04, intensity * 0.28)
		_: return Color(0.1, 0.12, 0.2, intensity * 0.18)
