class_name GameAudioService
extends BaseGameService

signal music_state_changed(state_id: StringName)

const BUS_NAMES := [&"Master", &"Music", &"Ambience", &"Weapons", &"Explosions", &"Player", &"Enemies", &"Dialogue", &"UI"]
const DEFAULT_VOICE_LIMITS := {&"Weapons": 12, &"Explosions": 8, &"Player": 6, &"Enemies": 10, &"Dialogue": 2, &"UI": 4, &"Music": 2, &"Ambience": 4}

var master_volume := 1.0
var settings: SettingsService
var voice_limits := DEFAULT_VOICE_LIMITS.duplicate()
var active_emitters: Dictionary = {}
var _dialogue_duck_db := -8.0
var current_music_state: StringName = &"silent"
var current_music_asset_path := ""
var music_crossfade_seconds := 0.75
var _pitch_random := RandomNumberGenerator.new()

func _init() -> void:
	service_id = &"audio"

func initialize(context: Dictionary = {}) -> bool:
	settings = context.get("hub").settings if context.has("hub") else null
	_ensure_buses()
	_pitch_random.seed = int(context.get("audio_seed", 0x47414C4158))
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
		candidate.stop(); candidate.stream = null; voices.erase(candidate)
		if candidate.get_parent() == self: remove_child(candidate)
		candidate.free()
	var emitter := AudioStreamPlayer.new()
	emitter.bus = String(bus); emitter.stream = stream; emitter.pitch_scale = clampf(1.0 + _pitch_random.randf_range(-pitch_variation, pitch_variation), 0.85, 1.15); emitter.set_meta(&"priority", priority); emitter.set_meta(&"position_2d", position_2d); add_child(emitter); voices.append(emitter); active_emitters[bus] = voices
	emitter.finished.connect(func():
		voices.erase(emitter)
		emitter.stream = null
		emitter.queue_free())
	if DisplayServer.get_name() == "headless":
		emitter.set_meta(&"headless_active", true)
	else:
		emitter.play()
	return emitter

func play_music(stream: AudioStream, looped := true) -> AudioStreamPlayer:
	return transition_music(stream, &"music", music_crossfade_seconds, looped)

func transition_music(stream: AudioStream, state_id: StringName, duration := -1.0, looped := true) -> AudioStreamPlayer:
	if stream == null or state_id.is_empty(): return null
	var fade_seconds := music_crossfade_seconds if duration < 0.0 else maxf(0.0, duration)
	var existing: Array = active_emitters.get(&"Music", [])
	for voice in existing:
		if is_instance_valid(voice) and (voice as AudioStreamPlayer).stream == stream:
			current_music_state = state_id
			current_music_asset_path = stream.resource_path
			music_state_changed.emit(state_id)
			return voice
	while existing.size() >= 2:
		_release_emitter(&"Music", existing[0] as AudioStreamPlayer)
		existing = active_emitters.get(&"Music", [])
	_set_stream_loop(stream, looped)
	var emitter := play(stream, &"Music", 10)
	if emitter == null: return null
	current_music_state = state_id
	current_music_asset_path = stream.resource_path
	music_state_changed.emit(state_id)
	var old_voices: Array = []
	for voice in (active_emitters.get(&"Music", []) as Array):
		if voice != emitter and is_instance_valid(voice): old_voices.append(voice)
	if DisplayServer.get_name() == "headless" or fade_seconds <= 0.0:
		for old_voice in old_voices: _release_emitter(&"Music", old_voice as AudioStreamPlayer)
		emitter.volume_db = 0.0
		return emitter
	emitter.volume_db = -60.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(emitter, "volume_db", 0.0, fade_seconds)
	for old_voice in old_voices: tween.tween_property(old_voice, "volume_db", -60.0, fade_seconds)
	tween.chain().tween_callback(func():
		for old_voice in old_voices:
			if is_instance_valid(old_voice): _release_emitter(&"Music", old_voice as AudioStreamPlayer))
	return emitter

func play_path(asset_path: String, bus: StringName, priority := 1, pitch_variation := 0.0, position_2d := Vector2.ZERO) -> AudioStreamPlayer:
	if asset_path.is_empty() or not ResourceLoader.exists(asset_path): return null
	return play(load(asset_path) as AudioStream, bus, priority, pitch_variation, position_2d)

func stop_bus(bus: StringName) -> void:
	if bus not in BUS_NAMES: return
	for voice in (active_emitters.get(bus, []) as Array).duplicate():
		if not is_instance_valid(voice): continue
		var emitter := voice as AudioStreamPlayer
		emitter.stop()
		emitter.set_meta(&"headless_active", false)
		emitter.stream = null
		if emitter.get_parent() == self: remove_child(emitter)
		emitter.free()
	active_emitters[bus] = []
	if bus == &"Music":
		current_music_state = &"silent"
		current_music_asset_path = ""

func set_dialogue_ducking(active: bool) -> void:
	for bus in [&"Music", &"Ambience", &"Weapons", &"Explosions"]:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0: AudioServer.set_bus_volume_db(index, _setting_db(bus) + (_dialogue_duck_db if active else 0.0))

func transition_boss_music(stream: AudioStream) -> AudioStreamPlayer:
	return transition_music(stream, &"boss", music_crossfade_seconds, true)

func set_music_paused(paused: bool) -> void:
	for voice in active_emitters.get(&"Music", []):
		if is_instance_valid(voice): (voice as AudioStreamPlayer).stream_paused = paused

func capture_music_state() -> Dictionary:
	var position := 0.0
	var paused := false
	for voice in active_emitters.get(&"Music", []):
		if is_instance_valid(voice):
			position = (voice as AudioStreamPlayer).get_playback_position()
			paused = (voice as AudioStreamPlayer).stream_paused
	return {"state_id": current_music_state, "asset_path": current_music_asset_path, "position": position, "paused": paused}

func restore_music_state(snapshot: Dictionary) -> bool:
	var path := String(snapshot.get("asset_path", ""))
	if path.is_empty() or not ResourceLoader.exists(path): return false
	var emitter := transition_music(load(path) as AudioStream, StringName(snapshot.get("state_id", &"music")), 0.0, true)
	if emitter == null: return false
	if DisplayServer.get_name() != "headless": emitter.seek(maxf(0.0, float(snapshot.get("position", 0.0))))
	emitter.stream_paused = bool(snapshot.get("paused", false))
	return true

func stop_all() -> void:
	for bus in active_emitters.keys(): stop_bus(bus)

func _exit_tree() -> void:
	stop_all()

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
	active_emitters[bus] = (active_emitters.get(bus, []) as Array).filter(func(voice): return is_instance_valid(voice) and ((voice as AudioStreamPlayer).playing or bool(voice.get_meta(&"headless_active", false))))

func _release_emitter(bus: StringName, emitter: AudioStreamPlayer) -> void:
	if emitter == null or not is_instance_valid(emitter): return
	var voices: Array = active_emitters.get(bus, [])
	voices.erase(emitter)
	active_emitters[bus] = voices
	emitter.stop()
	emitter.set_meta(&"headless_active", false)
	emitter.stream = null
	if emitter.get_parent() == self: remove_child(emitter)
	emitter.free()

func _set_stream_loop(stream: AudioStream, looped: bool) -> void:
	for property in stream.get_property_list():
		if StringName(property.get("name", &"")) == &"loop":
			stream.set("loop", looped)
			return
