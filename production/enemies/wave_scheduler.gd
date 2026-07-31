class_name WaveScheduler
extends Node

signal wave_started(wave_id: StringName)
signal enemy_spawn_requested(enemy_id: StringName, position: Vector2, formation: FormationRuntime, slot: int)
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

func configure(wave_definitions: Array[WaveDefinition]) -> void:
	waves.assign(wave_definitions)

func snapshot() -> Dictionary:
	return {"current_index": current_index, "active_enemies": active_enemies, "elapsed": elapsed, "spawn_elapsed": spawn_elapsed, "spawn_index": spawn_index, "running": running}

func restore(data: Dictionary) -> bool:
	var index := int(data.get("current_index", -1))
	if index < 0 or index >= waves.size(): return false
	current_index = index - 1
	_start_next()
	active_enemies = maxi(0, int(data.get("active_enemies", 0)))
	elapsed = maxf(0.0, float(data.get("elapsed", 0.0)))
	spawn_elapsed = maxf(0.0, float(data.get("spawn_elapsed", 0.0)))
	spawn_index = clampi(int(data.get("spawn_index", 0)), 0, _spawn_ids().size())
	running = bool(data.get("running", true))
	return true

func start() -> bool:
	if waves.is_empty(): return false
	current_index = -1
	_start_next()
	return true

func tick(delta: float) -> void:
	if not running or current_wave == null: return
	elapsed += delta
	spawn_elapsed += delta
	var ids := current_wave.formation.member_enemy_ids if current_wave.formation != null else current_wave.enemy_ids
	if spawn_index < ids.size() and spawn_elapsed >= current_wave.spawn_delay:
		var point := _spawn_point(spawn_index)
		enemy_spawn_requested.emit(ids[spawn_index], point, current_formation, spawn_index)
		spawn_index += 1
		active_enemies += 1
		spawn_elapsed = 0.0
	if _is_complete(ids.size()):
		wave_completed.emit(current_wave.stable_id, current_wave.reward_hooks)
		_start_next()

func notify_enemy_finished() -> void:
	active_enemies = maxi(0, active_enemies - 1)

func _is_complete(total_to_spawn: int) -> bool:
	if spawn_index < total_to_spawn: return false
	match current_wave.completion_rule:
		&"defeat_all": return active_enemies == 0
		&"survive", &"timeout": return elapsed >= current_wave.timeout
		_: return false

func _start_next() -> void:
	current_index += 1
	if current_index >= waves.size():
		running = false
		current_wave = null
		schedule_completed.emit()
		return
	current_wave = waves[current_index]
	if current_formation != null:
		current_formation.queue_free()
		current_formation = null
	if current_wave.formation != null:
		current_formation = FormationRuntime.new()
		current_formation.name = "Formation_%s" % current_wave.stable_id
		current_formation.configure(current_wave.formation)
		current_formation.ordered_kill_bonus.connect(func(amount: int): formation_bonus.emit(amount))
		current_formation.formation_completed.connect(func(amount: int): formation_bonus.emit(amount))
		current_formation.position = Vector2(270, 190)
		add_child(current_formation)
	elapsed = 0.0
	spawn_elapsed = current_wave.spawn_delay
	spawn_index = 0
	active_enemies = 0
	running = true
	wave_started.emit(current_wave.stable_id)

func _spawn_point(index: int) -> Vector2:
	if not current_wave.spawn_points.is_empty(): return current_wave.spawn_points[index % current_wave.spawn_points.size()]
	if current_wave.formation != null and index < current_wave.formation.slots.size():
		return (current_formation.position if current_formation != null else Vector2(270, 190)) + current_wave.formation.slots[index]
	return Vector2(270, -40)

func _spawn_ids() -> Array[StringName]:
	if current_wave == null: return []
	return current_wave.formation.member_enemy_ids if current_wave.formation != null else current_wave.enemy_ids
