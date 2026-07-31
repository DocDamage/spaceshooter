class_name GameAudioService
extends BaseGameService

const BUS_NAMES := [&"Master", &"Music", &"Ambience", &"Weapons", &"Explosions", &"Player", &"Enemies", &"Dialogue", &"UI"]
const DEFAULT_VOICE_LIMITS := {&"Weapons": 12, &"Explosions": 8, &"Player": 6, &"Enemies": 10, &"Dialogue": 2, &"UI": 4, &"Music": 2, &"Ambience": 4}

var master_volume := 1.0
var settings: SettingsService
var voice_limits := DEFAULT_VOICE_LIMITS.duplicate()
var active_emitters: Dictionary = {}
var _dialogue_duck_db := -8.0

func _init() -> void:
	service_id = &"audio"

func initialize(context: Dictionary = {}) -> bool:
	settings = context.get("hub").settings if context.has("hub") else null
	_ensure_buses()
	for bus in BUS_NAMES: active_emitters[bus] = []
	if settings != null:
		settings.setting_changed.connect(_on_setting_changed)
		_apply_settings()
	is_initialized = true
	return true

func set_master_volume(linear_volume: float) -> void:
	master_volume = clampf(linear_volume, 0.0, 1.0)
	_set_bus_linear(&"Master", master_volume)

func play(stream: AudioStream, bus: StringName, priority := 1, pitch_variation := 0.0, position_2d := Vector2.ZERO) -> AudioStreamPlayer:
	if stream == null or bus not in BUS_NAMES: return null
	_prune(bus)
	var voices: Array = active_emitters[bus]
	var limit := int(voice_limits.get(bus, 4))
	if voices.size() >= limit:
		var candidate: AudioStreamPlayer = null
		for voice in voices:
			if int(voice.get_meta(&"priority", 1)) < priority: candidate = voice; break
		if candidate == null: return null
		candidate.stop(); candidate.queue_free(); voices.erase(candidate)
	var emitter := AudioStreamPlayer.new()
	emitter.bus = String(bus); emitter.stream = stream; emitter.pitch_scale = clampf(1.0 + randf_range(-pitch_variation, pitch_variation), 0.85, 1.15); emitter.set_meta(&"priority", priority); emitter.set_meta(&"position_2d", position_2d); add_child(emitter); voices.append(emitter); active_emitters[bus] = voices
	emitter.finished.connect(func(): voices.erase(emitter); emitter.queue_free())
	emitter.play()
	return emitter

func set_dialogue_ducking(active: bool) -> void:
	for bus in [&"Music", &"Ambience", &"Weapons", &"Explosions"]:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0: AudioServer.set_bus_volume_db(index, _setting_db(bus) + (_dialogue_duck_db if active else 0.0))

func transition_boss_music(stream: AudioStream) -> AudioStreamPlayer:
	for voice in active_emitters.get(&"Music", []): (voice as AudioStreamPlayer).stop()
	return play(stream, &"Music", 10)

func active_voice_count(bus: StringName = &"") -> int:
	if not bus.is_empty(): _prune(bus); return (active_emitters.get(bus, []) as Array).size()
	var total := 0
	for key in active_emitters: _prune(key); total += (active_emitters[key] as Array).size()
	return total

func _ensure_buses() -> void:
	for bus in BUS_NAMES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus(); AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)

func _apply_settings() -> void:
	set_master_volume(float(settings.get_setting(&"master_volume", 1.0)))
	for bus in BUS_NAMES.slice(1): _set_bus_linear(bus, float(settings.get_setting(StringName("%s_volume" % String(bus).to_snake_case()), 1.0)))
	AudioServer.set_bus_mute(0, bool(settings.get_setting(&"audio_muted", false)))
	var mode := String(settings.get_setting(&"dynamic_range", "full"))
	_dialogue_duck_db = -5.0 if mode == "night" else -8.0

func _on_setting_changed(key: StringName, _value: Variant) -> void:
	if key == &"master_volume" or key == &"audio_muted" or key == &"dynamic_range" or String(key).ends_with("_volume"): _apply_settings()

func _set_bus_linear(bus: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0: AudioServer.set_bus_volume_db(index, linear_to_db(clampf(value, 0.0001, 1.0)))

func _setting_db(bus: StringName) -> float:
	var key := StringName("%s_volume" % String(bus).to_snake_case())
	return linear_to_db(clampf(float(settings.get_setting(key, 1.0)) if settings != null else 1.0, 0.0001, 1.0))

func _prune(bus: StringName) -> void:
	active_emitters[bus] = (active_emitters.get(bus, []) as Array).filter(func(voice): return is_instance_valid(voice) and (voice as AudioStreamPlayer).playing)
