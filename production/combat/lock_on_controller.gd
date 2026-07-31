class_name LockOnController
extends Node2D

signal target_locked(target_id: StringName)
signal target_lost(target_id: StringName)

var owner_actor: Node2D
var registry: ActorRegistry
var target_categories: Array[StringName] = [&"enemy", &"boss"]
var lock_time := 0.25
var maximum_targets := 1
var acquisition_radius := 650.0
var aim_assist := 0.0
var classic_mode := true
var current_targets: Array[Node2D] = []
var _lock_progress: Dictionary = {}

func configure(actor: Node2D, session_registry: ActorRegistry) -> void:
	owner_actor = actor
	registry = session_registry

func update_lock(delta: float, aim_direction := Vector2.UP) -> void:
	_prune_targets()
	var candidates := _rank_candidates(aim_direction)
	for candidate in candidates:
		if candidate in current_targets:
			continue
		var id: StringName = candidate.actor_id
		_lock_progress[id] = float(_lock_progress.get(id, 0.0)) + delta
		if _lock_progress[id] >= maxf(0.0, lock_time * (1.0 - aim_assist)) and current_targets.size() < maximum_targets:
			current_targets.append(candidate)
			target_locked.emit(id)
		if current_targets.size() >= maximum_targets:
			break

func cycle_target(direction := 1) -> Node2D:
	var candidates := _rank_candidates(Vector2.UP)
	if candidates.is_empty():
		return null
	var current_index := candidates.find(current_targets[0]) if not current_targets.is_empty() else -1
	var next: Node2D = candidates[posmod(current_index + direction, candidates.size())]
	clear_targets()
	current_targets.append(next)
	target_locked.emit(next.actor_id)
	return next

func primary_target() -> Node2D:
	_prune_targets()
	return current_targets[0] if not current_targets.is_empty() else null

func clear_targets() -> void:
	for target in current_targets:
		if is_instance_valid(target):
			target_lost.emit(target.actor_id)
	current_targets.clear()
	_lock_progress.clear()

func _prune_targets() -> void:
	for index in range(current_targets.size() - 1, -1, -1):
		var target := current_targets[index]
		if not is_instance_valid(target) or not target.is_inside_tree() or (target is BaseActor2D and not target.active):
			var id: StringName = target.actor_id if is_instance_valid(target) else &""
			current_targets.remove_at(index)
			target_lost.emit(id)

func _rank_candidates(aim_direction: Vector2) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if registry == null or owner_actor == null:
		return result
	for category in target_categories:
		for actor in registry.get_actors(category):
			if actor is Node2D and actor != owner_actor and owner_actor.global_position.distance_to(actor.global_position) <= acquisition_radius:
				result.append(actor)
	var forward := Vector2.UP if classic_mode or aim_direction.length_squared() == 0.0 else aim_direction.normalized()
	result.sort_custom(func(a: Node2D, b: Node2D):
		var a_delta := owner_actor.global_position.direction_to(a.global_position)
		var b_delta := owner_actor.global_position.direction_to(b.global_position)
		var a_score := absf(forward.angle_to(a_delta)) * (1.0 - aim_assist) + owner_actor.global_position.distance_to(a.global_position) / acquisition_radius
		var b_score := absf(forward.angle_to(b_delta)) * (1.0 - aim_assist) + owner_actor.global_position.distance_to(b.global_position) / acquisition_radius
		return a_score < b_score)
	return result

func _draw() -> void:
	for target in current_targets:
		if is_instance_valid(target):
			var local := to_local(target.global_position)
			draw_arc(local, 18.0, 0.0, TAU, 24, Color("ffe26d"), 2.0)
