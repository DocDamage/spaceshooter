class_name OnlineSessionCoordinator
extends Node

signal outbound_message(target_peer_id: int, message: Dictionary)
signal authoritative_event_applied(message: Dictionary)
signal session_aborted(reason: StringName)

const AUTHORITY_ONLY_MESSAGES: Array[StringName] = [
	&"actor_spawn", &"actor_despawn", &"damage_confirmation", &"projectile_interaction",
	&"boss_phase", &"objective_event", &"checkpoint_snapshot", &"reward_result", &"world_snapshot"
]

var is_host := false
var local_peer_id := 0
var authority_peer_id := 1
var stage_seed := 0
var stage_graph_hash := ""
var tick := 0
var event_sequence := 0
var last_received_sequence: Dictionary = {}
var participant_peer_ids: Array[int] = []
var world_state: Dictionary = {"actors": {}, "objectives": {}, "score": 0, "boss": {}, "drops": {}}
var diagnostics := NetworkDiagnostics.new()
var projectiles := ProjectileNetworkReplicator.new()
var disconnects := OnlineDisconnectManager.new()
var predictors: Dictionary = {}
var claimed_reward_transactions: Dictionary = {}
var latest_checkpoint: Dictionary = {}
var _configured := false

func configure(peer_id: int, host: bool, seed: int, stage_graph: Dictionary, peers: Array[int]) -> bool:
	if peer_id < 1 or seed == 0 or peers.is_empty() or peer_id not in peers or 1 not in peers: return false
	local_peer_id = peer_id; is_host = host; authority_peer_id = 1; stage_seed = seed
	participant_peer_ids = peers.duplicate(); participant_peer_ids.sort()
	stage_graph_hash = NetworkProtocol.canonical_state_hash(stage_graph)
	diagnostics.authority_peer_id = authority_peer_id; diagnostics.stage_seed = seed
	projectiles.authority_peer_id = authority_peer_id
	_configured = true
	return is_host == (local_peer_id == authority_peer_id)

func register_player(peer_id: int, initial_position: Vector2, speed := 320.0, bounds := Rect2(0, 0, 540, 960)) -> bool:
	if not _configured or peer_id not in participant_peer_ids: return false
	var predictor := MovementPredictor.new(); predictor.configure(initial_position, speed, bounds); predictors[peer_id] = predictor
	world_state.actors[StringName("player.online_%d" % peer_id)] = {"peer_id": peer_id, "position": initial_position, "health": 100.0, "alive": true}
	return true

func submit_local_input(direction: Vector2, delta: float, dash := false, firing := false, paused := false) -> Dictionary:
	if not _configured or not predictors.has(local_peer_id): return {}
	var predictor: MovementPredictor = predictors[local_peer_id]
	var input_sequence := event_sequence + 1
	var input := {"sequence": input_sequence, "direction": direction, "delta": delta, "dash": dash, "firing": firing, "paused": paused}
	var predicted := predictor.predict(input)
	var message := _make(&"player_input", {"input": input, "predicted_position": predicted.position})
	if is_host: receive_message(message)
	else: _send(authority_peer_id, message)
	return predicted

func request_projectile_spawn(request: Dictionary) -> Dictionary:
	if not _configured: return {"accepted": false, "reason": &"not_configured"}
	if not is_host:
		_send(authority_peer_id, _make(&"projectile_spawn", request))
		return {"accepted": true, "pending_authority": true}
	var event := projectiles.authority_spawn(request, local_peer_id)
	if bool(event.get("accepted", false)): _broadcast_authority(&"projectile_spawn", event)
	return event

func authority_projectile_interaction(projectile_id: StringName, interaction: StringName, actor_id: StringName = &"", new_owner_peer_id := 0, new_owner_actor_id: StringName = &"") -> Dictionary:
	if not is_host: return {"accepted": false, "reason": &"not_authority"}
	var event := projectiles.authority_interaction(projectile_id, interaction, actor_id, new_owner_peer_id, new_owner_actor_id)
	if bool(event.get("accepted", false)): _broadcast_authority(&"projectile_interaction", event)
	return event

func authority_damage(actor_id: StringName, amount: float, source_actor_id: StringName, network_sequence_id: int) -> Dictionary:
	if not is_host or not world_state.actors.has(actor_id): return {"accepted": false, "reason": &"not_authority_or_actor_missing"}
	var actor: Dictionary = world_state.actors[actor_id]
	var applied := minf(maxf(0.0, amount), float(actor.get("health", 0.0)))
	actor.health = float(actor.get("health", 0.0)) - applied; actor.alive = actor.health > 0.0
	world_state.actors[actor_id] = actor
	var payload := {"accepted": true, "actor_id": actor_id, "source_actor_id": source_actor_id, "amount": applied, "health": actor.health, "alive": actor.alive, "network_sequence_id": network_sequence_id}
	_broadcast_authority(&"damage_confirmation", payload)
	return payload

func authority_set_boss_phase(boss_id: StringName, phase_index: int, phase_id: StringName) -> bool:
	if not is_host: return false
	world_state.boss = {"boss_id": boss_id, "phase_index": phase_index, "phase_id": phase_id}
	_broadcast_authority(&"boss_phase", world_state.boss)
	return true

func authority_objective(objective_id: StringName, value: Variant) -> bool:
	if not is_host: return false
	world_state.objectives[objective_id] = value
	_broadcast_authority(&"objective_event", {"objective_id": objective_id, "value": value})
	return true

func authority_add_score(amount: int, reason: StringName) -> int:
	if not is_host: return int(world_state.score)
	world_state.score = maxi(0, int(world_state.score) + amount)
	_broadcast_authority(&"objective_event", {"objective_id": &"authoritative_score", "value": world_state.score, "reason": reason})
	return int(world_state.score)

func authority_checkpoint(snapshot: Dictionary) -> bool:
	if not is_host or snapshot.is_empty(): return false
	latest_checkpoint = snapshot.duplicate(true)
	latest_checkpoint["network"] = {"authority_peer_id": authority_peer_id, "stage_seed": stage_seed, "stage_graph_hash": stage_graph_hash, "tick": tick, "event_sequence": event_sequence, "world_hash": NetworkProtocol.canonical_state_hash(world_state)}
	_broadcast_authority(&"checkpoint_snapshot", latest_checkpoint)
	return true

func authority_reward_result(transaction_id: StringName, rewards: Dictionary, eligible_peer_ids: Array[int]) -> Dictionary:
	if not is_host or transaction_id.is_empty(): return {"accepted": false, "reason": &"not_authority_or_invalid"}
	if claimed_reward_transactions.has(transaction_id): return {"accepted": false, "duplicate": true, "transaction_id": transaction_id}
	claimed_reward_transactions[transaction_id] = true
	var eligible: Array[int] = []
	for peer_id in eligible_peer_ids:
		if peer_id in participant_peer_ids and peer_id not in eligible: eligible.append(peer_id)
	var result := {"accepted": true, "transaction_id": transaction_id, "rewards": rewards.duplicate(true), "eligible_peer_ids": eligible}
	_broadcast_authority(&"reward_result", result)
	return result

func receive_message(message: Dictionary) -> bool:
	if not NetworkProtocol.validate_message(message).is_empty(): return false
	var sender := int(message.sender_peer_id); var sequence := int(message.sequence); var message_type := StringName(message.type)
	if sender not in participant_peer_ids or sequence <= int(last_received_sequence.get(sender, 0)): return false
	if message_type in AUTHORITY_ONLY_MESSAGES and sender != authority_peer_id: return false
	last_received_sequence[sender] = sequence
	diagnostics.record_received(sequence)
	var payload: Dictionary = message.payload
	if is_host:
		match message_type:
			&"player_input": _authority_apply_input(sender, payload)
			&"projectile_spawn":
				var event := projectiles.authority_spawn(payload, sender)
				if bool(event.get("accepted", false)): _broadcast_authority(&"projectile_spawn", event)
			&"reconnect_request": pass
			_: return false
	else:
		match message_type:
			&"world_snapshot": _apply_world_snapshot(payload)
			&"projectile_spawn", &"projectile_interaction": projectiles.apply_event(payload)
			&"boss_phase": world_state.boss = payload.duplicate(true)
			&"objective_event": world_state.objectives[StringName(payload.get("objective_id", ""))] = payload.get("value")
			&"damage_confirmation":
				var actor_id := StringName(payload.get("actor_id", "")); if world_state.actors.has(actor_id): world_state.actors[actor_id].merge({"health": payload.get("health", 0.0), "alive": payload.get("alive", false)}, true)
			&"checkpoint_snapshot": latest_checkpoint = payload.duplicate(true)
			&"reward_result":
				var transaction_id := StringName(payload.get("transaction_id", "")); if not transaction_id.is_empty(): claimed_reward_transactions[transaction_id] = true
			&"actor_spawn": world_state.actors[StringName(payload.get("actor_id", ""))] = payload.duplicate(true)
			&"actor_despawn": world_state.actors.erase(StringName(payload.get("actor_id", "")))
			&"menu_state": pass
			_: return false
	authoritative_event_applied.emit(message.duplicate(true))
	return true

func create_world_snapshot() -> Dictionary:
	if not is_host: return {}
	tick += 1
	var state_hash := NetworkProtocol.canonical_state_hash(world_state)
	diagnostics.store_local_hash(tick, state_hash)
	return {"tick": tick, "stage_seed": stage_seed, "stage_graph_hash": stage_graph_hash, "state": world_state.duplicate(true), "state_hash": state_hash, "acknowledged_inputs": last_received_sequence.duplicate(true), "authority_timestamp_ms": Time.get_ticks_msec()}

func broadcast_world_snapshot() -> Dictionary:
	var snapshot := create_world_snapshot()
	if not snapshot.is_empty(): _broadcast_authority(&"world_snapshot", snapshot)
	return snapshot

func handle_disconnect(peer_id: int, checkpoint: Dictionary, now_ms: int) -> Dictionary:
	if not is_host and peer_id == authority_peer_id:
		session_aborted.emit(&"host_disconnected")
		return {"mission_abort": true, "save_checkpoint": not checkpoint.is_empty()}
	var result := disconnects.handle_disconnect(peer_id, peer_id == authority_peer_id, checkpoint, now_ms)
	if bool(result.mission_abort): session_aborted.emit(&"host_disconnected")
	return result

func handle_reconnect(peer_id: int, now_ms: int) -> Dictionary:
	return disconnects.reconnect(peer_id, now_ms)

func authority_domains() -> Array[StringName]: return NetworkProtocol.HOST_AUTHORITY_DOMAINS.duplicate()

func _authority_apply_input(peer_id: int, payload: Dictionary) -> void:
	if not predictors.has(peer_id): return
	var predictor: MovementPredictor = predictors[peer_id]
	var input: Dictionary = payload.get("input", {})
	var state := predictor.predict(input)
	var actor_id := StringName("player.online_%d" % peer_id)
	if world_state.actors.has(actor_id): world_state.actors[actor_id].position = state.position

func _apply_world_snapshot(payload: Dictionary) -> void:
	if int(payload.get("stage_seed", 0)) != stage_seed or str(payload.get("stage_graph_hash", "")) != stage_graph_hash:
		diagnostics.desync_warning_count += 1
		return
	world_state = payload.get("state", {}).duplicate(true)
	var snapshot_tick := int(payload.get("tick", 0)); var authority_hash := str(payload.get("state_hash", ""))
	diagnostics.verify_authority_hash(snapshot_tick, authority_hash)
	diagnostics.record_snapshot(float(Time.get_ticks_msec() - int(payload.get("authority_timestamp_ms", Time.get_ticks_msec()))))
	var acknowledgements: Dictionary = payload.get("acknowledged_inputs", {})
	if predictors.has(local_peer_id):
		var actor_id := StringName("player.online_%d" % local_peer_id)
		var actor: Dictionary = world_state.actors.get(actor_id, {})
		var authoritative := {"position": actor.get("position", Vector2.ZERO), "velocity": Vector2.ZERO, "dash_active": false, "paused": false}
		var result: Dictionary = predictors[local_peer_id].reconcile(authoritative, int(acknowledgements.get(local_peer_id, 0)))
		if bool(result.corrected): diagnostics.record_correction()

func _make(message_type: StringName, payload: Dictionary) -> Dictionary:
	event_sequence += 1
	return NetworkProtocol.make_message(message_type, event_sequence, local_peer_id, payload, tick)

func _send(target_peer_id: int, message: Dictionary) -> void:
	diagnostics.record_sent(); outbound_message.emit(target_peer_id, message.duplicate(true))

func _broadcast_authority(message_type: StringName, payload: Dictionary) -> void:
	if not is_host: return
	var message := _make(message_type, payload)
	for peer_id in participant_peer_ids:
		if peer_id != local_peer_id: _send(peer_id, message)
