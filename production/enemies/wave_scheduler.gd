class_name WaveScheduler
extends Node

signal wave_started(wave_id: StringName)
signal enemy_spawn_requested(enemy_id: StringName, position: Vector2, formation: FormationRuntime, slot: int, wave_id: StringName)
signal wave_completed(wave_id: StringName, reward_hooks: Array[Dictionary])
signal schedule_completed
signal formation_bonus(amount: int)

var waves: Array[WaveDefinition] = []
var current_index := -1
var current_wave: WaveDefinition
var active_enemies := 0
var elapsed := 0.0
var spawn_elapsed := 0.0
var spawn_index := 0
var running := false
var current_formation: FormationRuntime
var _states: Array[Dictionary] = []

func configure(wave_definitions: Array[WaveDefinition]) -> void:
	waves.assign(wave_definitions)

func snapshot() -> Dictionary:
	var states: Array[Dictionary] = []
	for state in _states:
		states.append({"index": state.index, "active_enemies": state.active_enemies, "elapsed": state.elapsed, "spawn_elapsed": state.spawn_elapsed, "spawn_index": state.spawn_index, "completed": state.completed})
	return {"current_index": current_index, "active_enemies": active_enemies, "elapsed": elapsed, "spawn_elapsed": spawn_elapsed, "spawn_index": spawn_index, "running": running, "states": states}

func restore(data: Dictionary) -> bool:
	if waves.is_empty(): return false
	_clear_states()
	var saved_states: Array = data.get("states", [])
	if saved_states.is_empty():
		var saved_index := int(data.get("current_index", -1))
		if saved_index < 0 or saved_index >= waves.size(): return false
		_start_wave(saved_index)
		var state: Dictionary = _states[0]
		state.active_enemies = maxi(0, int(data.get("active_enemies", 0)))
		state.elapsed = maxf(0.0, float(data.get("elapsed", 0.0)))
		state.spawn_elapsed = maxf(0.0, float(data.get("spawn_elapsed", 0.0)))
		state.spawn_index = clampi(int(data.get("spawn_index", 0)), 0, _ids(state.wave).size())
		_states[0] = state
	else:
		for saved in saved_states:
			var index := int(saved.get("index", -1))
			if index < 0 or index >= waves.size(): return false
			_start_wave(index)
			var state: Dictionary = _state_for(index)
			state.active_enemies = maxi(0, int(saved.get("active_enemies", 0)))
			state.elapsed = maxf(0.0, float(saved.get("elapsed", 0.0)))
			state.spawn_elapsed = maxf(0.0, float(saved.get("spawn_elapsed", 0.0)))
			state.spawn_index = clampi(int(saved.get("spawn_index", 0)), 0, _ids(state.wave).size())
			state.completed = bool(saved.get("completed", false))
			_store_state(state)
	current_index = int(data.get("current_index", current_index))
	running = bool(data.get("running", true))
	_refresh_public_state()
	return true

func start() -> bool:
	if waves.is_empty(): return false
	_clear_states()
	_start_wave(0)
	running = true
	return true

func tick(delta: float) -> void:
	if not running: return
	for source in _states.duplicate():
		var state: Dictionary = _state_for(int(source.index))
		if state.is_empty() or bool(state.completed): continue
		_tick_state(state, delta)
		if _is_complete(state): _complete_state(state)
		else: _store_state(state)
	var latest := _state_for(current_index)
	if not latest.is_empty() and current_index + 1 < waves.size() and _can_start_next(latest): _start_wave(current_index + 1)
	if current_index >= waves.size() - 1 and _states.all(func(state): return bool(state.completed)):
		running = false
		schedule_completed.emit()
	_refresh_public_state()

func notify_enemy_finished(wave_id: StringName = &"") -> void:
	var state := _state_for_wave(wave_id)
	if state.is_empty(): return
	state.active_enemies = maxi(0, int(state.active_enemies) - 1)
	active_enemies = maxi(0, active_enemies - 1)
	_store_state(state)

func _tick_state(state: Dictionary, delta: float) -> void:
	state.elapsed = float(state.elapsed) + delta
	state.spawn_elapsed = float(state.spawn_elapsed) + delta
	var ids := _ids(state.wave)
	if int(state.spawn_index) < ids.size() and float(state.spawn_elapsed) >= state.wave.spawn_delay:
		var slot := int(state.spawn_index)
		enemy_spawn_requested.emit(ids[slot], _spawn_point(state, slot), state.formation, slot, state.wave.stable_id)
		state.spawn_index = slot + 1
		state.active_enemies = int(state.active_enemies) + 1
		active_enemies += 1
		state.spawn_elapsed = 0.0

func _can_start_next(state: Dictionary) -> bool:
	match state.wave.next_wave_condition:
		&"spawned": return int(state.spawn_index) >= _ids(state.wave).size()
		&"elapsed": return float(state.elapsed) >= state.wave.overlap_after_seconds
		_: return bool(state.completed)

func _is_complete(state: Dictionary) -> bool:
	if int(state.spawn_index) < _ids(state.wave).size(): return false
	match state.wave.completion_rule:
		&"defeat_all": return int(state.active_enemies) == 0
		&"survive", &"timeout": return float(state.elapsed) >= state.wave.timeout
		_: return false

func _start_wave(index: int) -> void:
	if index < 0 or index >= waves.size() or not _state_for(index).is_empty(): return
	var wave := waves[index]
	var formation: FormationRuntime
	if wave.formation != null:
		formation = FormationRuntime.new()
		formation.name = "Formation_%s" % wave.stable_id
		formation.configure(wave.formation)
		formation.ordered_kill_bonus.connect(func(amount: int): formation_bonus.emit(amount))
		formation.formation_completed.connect(func(amount: int): formation_bonus.emit(amount))
		formation.position = Vector2(270, 190)
		add_child(formation)
	_states.append({"index": index, "wave": wave, "formation": formation, "active_enemies": 0, "elapsed": 0.0, "spawn_elapsed": wave.spawn_delay, "spawn_index": 0, "completed": false})
	current_index = maxi(current_index, index)
	current_wave = wave
	current_formation = formation
	wave_started.emit(wave.stable_id)

func _complete_state(state: Dictionary) -> void:
	if bool(state.completed): return
	state.completed = true
	_store_state(state)
	wave_completed.emit(state.wave.stable_id, state.wave.reward_hooks)
	if is_instance_valid(state.formation): state.formation.queue_free()

func _state_for(index: int) -> Dictionary:
	for state in _states:
		if int(state.index) == index: return state
	return {}

func _state_for_wave(wave_id: StringName) -> Dictionary:
	for state in _states:
		if not bool(state.completed) and (wave_id.is_empty() or state.wave.stable_id == wave_id) and int(state.active_enemies) > 0: return state
	return {}

func _store_state(updated: Dictionary) -> void:
	for index in _states.size():
		if int(_states[index].index) == int(updated.index):
			_states[index] = updated
			return

func _refresh_public_state() -> void:
	active_enemies = 0
	var current := _state_for(current_index)
	for state in _states: active_enemies += int(state.active_enemies)
	if current.is_empty(): return
	current_wave = current.wave
	current_formation = current.formation
	elapsed = float(current.elapsed)
	spawn_elapsed = float(current.spawn_elapsed)
	spawn_index = int(current.spawn_index)

func _clear_states() -> void:
	for state in _states:
		if is_instance_valid(state.get("formation")): state.formation.queue_free()
	_states.clear()
	current_index = -1
	current_wave = null
	current_formation = null
	active_enemies = 0

func _spawn_point(state: Dictionary, index: int) -> Vector2:
	var wave: WaveDefinition = state.wave
	if not wave.spawn_points.is_empty(): return wave.spawn_points[index % wave.spawn_points.size()]
	if wave.formation != null and index < wave.formation.slots.size(): return (state.formation.position if state.formation != null else Vector2(270, 190)) + wave.formation.slots[index]
	return Vector2(270, -40)

func _ids(wave: WaveDefinition) -> Array[StringName]:
	if wave == null: return []
	return wave.formation.member_enemy_ids if wave.formation != null else wave.enemy_ids
