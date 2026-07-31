class_name PresentationCameraRig
extends Camera2D

var settings: SettingsService
var targets: Array[Node2D] = []
var look_ahead := Vector2.ZERO
var framing_padding := 90.0
var speed_zoom_strength := 0.06
var _shake_sources: Dictionary = {}
var _base_position := Vector2.ZERO
var _time := 0.0
var maximum_player_separation := 420.0
var soft_tether_start := 320.0
var teleport_recovery_distance := 560.0
var edge_warning_slots: Array[StringName] = []
var player_target_count := 0

func configure(settings_service: SettingsService) -> void:
	settings = settings_service
	position_smoothing_enabled = true
	position_smoothing_speed = 7.0

func set_targets(value: Array[Node2D]) -> void:
	targets = value
	player_target_count = value.size()

func add_shake(source: StringName, strength: float, duration: float, frequency := 24.0) -> void:
	_shake_sources[source] = {"strength": maxf(0.0, strength), "remaining": maxf(0.0, duration), "frequency": maxf(1.0, frequency)}

func frame_boss(boss: Node2D, players: Array[Node2D]) -> void:
	targets = players.duplicate()
	player_target_count = players.size()
	if boss != null: targets.append(boss)

func _process(delta: float) -> void:
	_time += delta
	_apply_shared_camera_rules()
	if not targets.is_empty():
		var bounds := Rect2(targets[0].global_position, Vector2.ZERO)
		for target in targets:
			if is_instance_valid(target): bounds = bounds.expand(target.global_position)
		_base_position = bounds.get_center() + look_ahead
		var viewport_size := get_viewport_rect().size
		var required := maxf((bounds.size.x + framing_padding) / maxf(viewport_size.x, 1.0), (bounds.size.y + framing_padding) / maxf(viewport_size.y, 1.0))
		zoom = Vector2.ONE / maxf(1.0, required)
	position = _base_position + _shake_offset(delta)

func _apply_shared_camera_rules() -> void:
	edge_warning_slots.clear()
	if player_target_count < 2 or targets.size() < 2: return
	var anchor := targets[0]
	if not is_instance_valid(anchor): return
	for index in range(1, mini(player_target_count, targets.size())):
		var target := targets[index]
		if not is_instance_valid(target): continue
		var offset := target.global_position - anchor.global_position
		var distance := offset.length()
		if distance >= soft_tether_start: edge_warning_slots.append(StringName("player_slot.%d" % (index + 1)))
		if distance > teleport_recovery_distance:
			target.global_position = anchor.global_position + offset.normalized() * soft_tether_start
		elif distance > maximum_player_separation:
			target.global_position = anchor.global_position + offset.normalized() * maximum_player_separation

func _shake_offset(delta: float) -> Vector2:
	var scale := float(settings.get_setting(&"screen_shake_scale", 1.0)) if settings != null else 1.0
	if settings != null and float(settings.get_setting(&"background_motion_reduction", 0.0)) >= 0.95: scale *= 0.2
	var result := Vector2.ZERO
	for source in _shake_sources.keys():
		var state: Dictionary = _shake_sources[source]
		state.remaining = maxf(0.0, float(state.remaining) - delta)
		var phase := _time * float(state.frequency) + float(hash(source) % 100)
		result += Vector2(sin(phase), cos(phase * 1.37)) * float(state.strength) * scale
		if state.remaining <= 0.0: _shake_sources.erase(source)
		else: _shake_sources[source] = state
	return result.limit_length(24.0 * scale)
