class_name ProjectileNetworkReplicator
extends RefCounted

signal projectile_spawned(event: Dictionary)
signal projectile_interacted(event: Dictionary)

var authority_peer_id := 1
var projectiles: Dictionary = {}
var _next_projectile_sequence := 0

func authority_spawn(request: Dictionary, requesting_peer_id: int) -> Dictionary:
	if requesting_peer_id < 1: return {"accepted": false, "reason": &"invalid_peer"}
	var owner_peer_id := int(request.get("owner_peer_id", requesting_peer_id))
	if owner_peer_id != requesting_peer_id and requesting_peer_id != authority_peer_id:
		return {"accepted": false, "reason": &"invalid_owner"}
	var direction: Vector2 = request.get("direction", Vector2.UP)
	var speed := clampf(float(request.get("speed", 0.0)), 1.0, 3000.0)
	if direction.length_squared() < 0.9 or direction.length_squared() > 1.1:
		direction = direction.normalized()
	if direction == Vector2.ZERO: return {"accepted": false, "reason": &"invalid_direction"}
	_next_projectile_sequence += 1
	var projectile_id := StringName("net_projectile.%d" % _next_projectile_sequence)
	var event := {
		"accepted": true, "projectile_id": projectile_id, "owner_peer_id": owner_peer_id,
		"owner_actor_id": StringName(request.get("owner_actor_id", "")),
		"team": StringName(request.get("team", "players")), "definition_id": StringName(request.get("definition_id", "")),
		"position": request.get("position", Vector2.ZERO), "direction": direction, "speed": speed,
		"spawn_tick": int(request.get("spawn_tick", 0)), "active": true
	}
	projectiles[projectile_id] = event.duplicate(true)
	projectile_spawned.emit(event.duplicate(true))
	return event

func authority_interaction(projectile_id: StringName, interaction: StringName, actor_id: StringName = &"", new_owner_peer_id := 0, new_owner_actor_id: StringName = &"") -> Dictionary:
	if not projectiles.has(projectile_id) or interaction not in [&"hit", &"reflect", &"absorb", &"destroy"]:
		return {"accepted": false, "reason": &"invalid_interaction"}
	var state: Dictionary = projectiles[projectile_id]
	var event := {"accepted": true, "projectile_id": projectile_id, "interaction": interaction, "actor_id": actor_id}
	match interaction:
		&"reflect":
			if new_owner_peer_id < 1 or new_owner_actor_id.is_empty(): return {"accepted": false, "reason": &"invalid_reflection_owner"}
			state.owner_peer_id = new_owner_peer_id
			state.owner_actor_id = new_owner_actor_id
			state.team = &"players"
			event.owner_peer_id = new_owner_peer_id
			event.owner_actor_id = new_owner_actor_id
			event.team = &"players"
		&"hit", &"absorb", &"destroy": state.active = false
	projectiles[projectile_id] = state
	projectile_interacted.emit(event.duplicate(true))
	return event

func apply_event(event: Dictionary) -> bool:
	var projectile_id := StringName(event.get("projectile_id", ""))
	if projectile_id.is_empty(): return false
	if event.has("direction"):
		projectiles[projectile_id] = event.duplicate(true)
		return true
	if not projectiles.has(projectile_id): return false
	var state: Dictionary = projectiles[projectile_id]
	if StringName(event.get("interaction", "")) == &"reflect":
		state.owner_peer_id = int(event.get("owner_peer_id", state.owner_peer_id))
		state.owner_actor_id = StringName(event.get("owner_actor_id", state.owner_actor_id))
		state.team = StringName(event.get("team", state.team))
	else: state.active = false
	projectiles[projectile_id] = state
	return true

func active_snapshot() -> Dictionary:
	var result := {}
	for projectile_id in projectiles:
		if bool(projectiles[projectile_id].get("active", false)): result[projectile_id] = projectiles[projectile_id].duplicate(true)
	return result
