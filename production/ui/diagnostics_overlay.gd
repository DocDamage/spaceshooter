class_name DiagnosticsOverlay
extends CanvasLayer

var diagnostics: DiagnosticsService
var save_service: SaveService
var label: Label
var refresh_timer := 0.0

func configure(diagnostics_service: DiagnosticsService, game_save_service: SaveService) -> void:
	diagnostics = diagnostics_service
	save_service = game_save_service

func _ready() -> void:
	layer = 100
	label = Label.new()
	label.position = Vector2(8, 92)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("a8f4ff"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_diagnostics"):
		visible = not visible
	refresh_timer -= delta
	if not visible or refresh_timer > 0.0 or diagnostics == null:
		return
	refresh_timer = 0.25
	var data := diagnostics.get_snapshot()
	label.text = "DEV DIAGNOSTICS [F3]\nFPS %d  %.2f ms  MEM %.1f MB\nP %d  W %d  E %d  B %d  SHOTS %d  FX %d\nPICKUPS %d  HAZARDS %d  POOL %d\nSEED %d  SEG %d  WAVES %d  DIFF %s\nSAVE %s  WARNINGS %d" % [
		data.fps, data.frame_time_ms, data.memory_mb,
		data.players, data.wingmen, data.enemies, data.bosses, data.projectiles, data.effects,
		data.pickups, data.hazards, data.pool_occupancy,
		data.mission_seed, data.segment, data.active_waves, data.difficulty,
		save_service.status, data.warnings.size()
	]
