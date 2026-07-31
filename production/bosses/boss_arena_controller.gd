class_name BossArenaController
extends Node2D

signal arena_locked
signal arena_cleared
signal hazard_requested(hazard_id: StringName, position: Vector2)
signal player_respawn_requested(player_id: StringName, position: Vector2)
signal camera_framing_requested(framing: Dictionary)

var profile: Dictionary = {}
var bounds := Rect2(0, 0, 540, 960)
var safe_entry := Vector2(270, 820)
var locked := false
var active_hazards: Array[StringName] = []
var local_players_inside: Array[StringName] = []
var expected_player_count := 1

func configure(arena_profile: Dictionary, players := 1) -> void:
	profile = arena_profile.duplicate(true)
	bounds = profile.get("bounds", bounds)
	safe_entry = profile.get("safe_entry", safe_entry)
	expected_player_count = maxi(1, players)

func enter_player(player_id: StringName) -> bool:
	if player_id.is_empty(): return false
	if player_id not in local_players_inside: local_players_inside.append(player_id)
	if not locked and local_players_inside.size() >= expected_player_count:
		locked = true
		arena_locked.emit()
	return true

func apply_phase_behavior(behavior: Dictionary) -> void:
	profile.merge(behavior, true)
	if behavior.has("bounds"): bounds = behavior.bounds
	if behavior.has("camera"): camera_framing_requested.emit(behavior.camera)
	for hazard_id in behavior.get("hazards", []):
		var id := StringName(hazard_id)
		if id not in active_hazards: active_hazards.append(id); hazard_requested.emit(id, bounds.get_center())

func respawn_player(player_id: StringName) -> Vector2:
	player_respawn_requested.emit(player_id, safe_entry)
	return safe_entry

func clamp_position(world_position: Vector2, margin := 0.0) -> Vector2:
	return Vector2(clampf(world_position.x, bounds.position.x + margin, bounds.end.x - margin), clampf(world_position.y, bounds.position.y + margin, bounds.end.y - margin))

func clear_arena() -> void:
	locked = false
	active_hazards.clear()
	arena_cleared.emit()
