class_name GameSession
extends Node

signal session_started(mission_id: StringName)
signal session_completed(result: Dictionary)
signal checkpoint_updated(snapshot: Dictionary)

var config: GameSessionConfig
var services: ServiceHub
var actor_registry: ActorRegistry
var event_bus: TypedEventBus
var mission_state: Dictionary = {}
var reward_state: Dictionary = {"credits": 0, "items": []}
var objective_state: Dictionary = {"defeated": 0, "required": 0}
var checkpoint_snapshot: Dictionary = {}
var temporary_upgrade_state: Dictionary = {}
var completion_result: Dictionary = {}
var difficulty_profile: StringName = &"normal"
var stage_seed := 0
var current_segment := 0
var current_route: Array[StringName] = []
var stage_plan_snapshot: Dictionary = {}
var cleared_segment_ids: Array[StringName] = []
var next_segment_id: StringName
var route_choices: Dictionary = {}
var safe_spawn := Vector2(270, 820)
var segment_runtime_snapshot: Dictionary = {}
var secret_state: Dictionary = {}
var active_waves := 0
var session_run_id: StringName
var _configured := false
var local_coop: LocalCoopSessionManager
var online_coop: OnlineSessionCoordinator

func configure(session_config: GameSessionConfig, service_hub: ServiceHub) -> bool:
	if is_inside_tree():
		push_error("GameSession must be configured before activation")
		return false
	config = session_config
	services = service_hub
	var errors := config.validate() if config != null else PackedStringArray(["Session config is required"])
	if not errors.is_empty():
		for message in errors:
			push_error("[GameSession] %s" % message)
		return false
	actor_registry = ActorRegistry.new()
	actor_registry.name = "ActorRegistry"
	add_child(actor_registry)
	event_bus = TypedEventBus.new()
	difficulty_profile = config.difficulty_profile
	stage_seed = config.stage_seed
	session_run_id = StringName("run.%s.%d.%d" % [config.mission_definition.stable_id, Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	mission_state = {"mission_id": config.mission_definition.stable_id, "status": &"configured"}
	objective_state.required = config.mission_definition.enemy_ids.size()
	_configured = true
	if int(config.multiplayer_configuration.get("local_players", 1)) > 1:
		local_coop = LocalCoopSessionManager.new()
		local_coop.name = "LocalCoopSessionManager"
		if not local_coop.configure(config.multiplayer_configuration, services.input):
			push_error("[GameSession] Invalid local cooperative configuration")
			return false
		add_child(local_coop)
	if bool(config.multiplayer_configuration.get("online", false)):
		online_coop = OnlineSessionCoordinator.new()
		online_coop.name = "OnlineSessionCoordinator"
		var peer_ids: Array[int] = []
		peer_ids.assign(config.multiplayer_configuration.get("peer_ids", []))
		var local_peer_id := int(config.multiplayer_configuration.get("local_peer_id", 0))
		var graph: Dictionary = config.multiplayer_configuration.get("stage_graph", {})
		if not online_coop.configure(local_peer_id, local_peer_id == 1, stage_seed, graph, peer_ids):
			push_error("[GameSession] Invalid online cooperative configuration")
			return false
		add_child(online_coop)
		services.diagnostics.attach_network(online_coop.diagnostics)
	return true

func _ready() -> void:
	if not _configured:
		push_error("GameSession activated without configure()")
		return
	mission_state.status = &"active"
	services.diagnostics.attach_session(self)
	services.game_flow.transition_to(&"mission")
	session_started.emit(config.mission_definition.stable_id)

func register_defeat(actor_id: StringName, credits: int) -> void:
	objective_state.defeated += 1
	reward_state.credits += credits
	event_bus.publish(ObjectiveProgressEvent.new(actor_id, config.mission_definition.stable_id, objective_state.defeated, objective_state.required))
	event_bus.publish(RewardGrantedEvent.new(actor_id, config.selected_profiles[0], &"credits", credits))
	if objective_state.defeated >= objective_state.required:
		complete_session(true)

func create_checkpoint(checkpoint_id: StringName) -> Dictionary:
	checkpoint_snapshot = {
		"checkpoint_id": checkpoint_id,
		"mission_id": config.mission_definition.stable_id,
		"seed": stage_seed,
		"segment": current_segment,
		"route": current_route.duplicate(),
		"session_run_id": session_run_id,
		"participants": config.selected_profiles.duplicate(),
		"selected_ships": config.selected_ships.duplicate(),
		"loadouts": config.loadouts.duplicate(true),
		"difficulty_profile": difficulty_profile,
		"mission_state": mission_state.duplicate(true),
		"pending_rewards": reward_state.duplicate(true),
		"objective_state": objective_state.duplicate(true),
		"temporary_upgrades": temporary_upgrade_state.duplicate(true),
		"stage_plan": stage_plan_snapshot.duplicate(true),
		"cleared_segment_ids": cleared_segment_ids.duplicate(),
		"next_segment_id": next_segment_id,
		"route_choices": route_choices.duplicate(true),
		"safe_spawn": safe_spawn,
		"segment_runtime": segment_runtime_snapshot.duplicate(true),
		"secret_state": secret_state.duplicate(true)
	}
	if local_coop != null: checkpoint_snapshot.cooperative_state = local_coop.checkpoint_snapshot()
	if online_coop != null:
		checkpoint_snapshot.online_state = {"authority_peer_id": online_coop.authority_peer_id, "stage_graph_hash": online_coop.stage_graph_hash, "world_state": online_coop.world_state.duplicate(true), "event_sequence": online_coop.event_sequence}
		if online_coop.is_host: online_coop.authority_checkpoint(checkpoint_snapshot)
	if checkpoint_id != &"mission_complete":
		for profile_id in config.selected_profiles:
			services.saves.save_checkpoint(profile_id, checkpoint_snapshot)
	event_bus.publish(CheckpointReachedEvent.new(config.mission_definition.stable_id, checkpoint_id, checkpoint_id))
	checkpoint_updated.emit(checkpoint_snapshot)
	return checkpoint_snapshot.duplicate(true)

func restore_checkpoint(snapshot: Dictionary) -> bool:
	for key in [&"checkpoint_id", &"mission_id", &"seed", &"route", &"session_run_id", &"participants", &"objective_state", &"temporary_upgrades", &"pending_rewards"]:
		if not snapshot.has(key): return false
	if StringName(snapshot.mission_id) != config.mission_definition.stable_id: return false
	stage_seed = int(snapshot.seed)
	current_segment = maxi(0, int(snapshot.get("segment", 0)))
	current_route.assign(snapshot.route)
	session_run_id = StringName(snapshot.session_run_id)
	mission_state = snapshot.get("mission_state", {}).duplicate(true)
	mission_state.status = &"active"
	objective_state = snapshot.objective_state.duplicate(true)
	temporary_upgrade_state = snapshot.temporary_upgrades.duplicate(true)
	reward_state = snapshot.pending_rewards.duplicate(true)
	stage_plan_snapshot = snapshot.get("stage_plan", {}).duplicate(true)
	cleared_segment_ids.assign(snapshot.get("cleared_segment_ids", []))
	next_segment_id = StringName(snapshot.get("next_segment_id", ""))
	route_choices = snapshot.get("route_choices", {}).duplicate(true)
	safe_spawn = snapshot.get("safe_spawn", Vector2(270, 820))
	segment_runtime_snapshot = snapshot.get("segment_runtime", {}).duplicate(true)
	secret_state = snapshot.get("secret_state", {}).duplicate(true)
	if local_coop != null and (not snapshot.has("cooperative_state") or not local_coop.restore_checkpoint(snapshot.cooperative_state)): return false
	if online_coop != null:
		if not snapshot.has("online_state") or str(snapshot.online_state.get("stage_graph_hash", "")) != online_coop.stage_graph_hash: return false
		online_coop.world_state = snapshot.online_state.get("world_state", {}).duplicate(true)
		online_coop.event_sequence = maxi(online_coop.event_sequence, int(snapshot.online_state.get("event_sequence", 0)))
	return true

func complete_session(success: bool) -> void:
	if mission_state.get("status") == &"complete":
		return
	mission_state.status = &"complete"
	completion_result = {
		"success": success,
		"mission_id": config.mission_definition.stable_id,
		"seed": stage_seed,
		"transaction_id": StringName("reward.%s" % session_run_id),
		"completed": success,
		"base_currency": int(reward_state.get("credits", 0)),
		"base_xp": int(objective_state.get("defeated", 0)) * 100,
		"rewards": reward_state.duplicate(true),
		"objectives": objective_state.duplicate(true),
		"run_metadata": {"active_assists": _active_assists(), "accessibility_allowed": true},
		"cooperative": local_coop.checkpoint_snapshot() if local_coop != null else {}
	}
	if online_coop != null:
		completion_result.online = {"authority_peer_id": online_coop.authority_peer_id, "stage_graph_hash": online_coop.stage_graph_hash, "authoritative_score": online_coop.world_state.score, "diagnostics": online_coop.diagnostics.snapshot()}
	for profile_id in config.selected_profiles:
		services.saves.clear_checkpoint(profile_id)
	services.saves.save_snapshot(create_checkpoint(&"mission_complete"))
	services.game_flow.transition_to(&"results")
	session_completed.emit(completion_result)

func _active_assists() -> Array[StringName]:
	var assists: Array[StringName] = []
	for key in [&"auto_fire", &"simplified_patterns", &"invulnerability_assist"]:
		if bool(services.settings.get_setting(key, false)):
			assists.append(key)
	if float(services.settings.get_setting(&"aim_assistance", 0.0)) > 0.0:
		assists.append(&"aim_assistance")
	if float(services.settings.get_setting(&"game_speed_assistance", 1.0)) < 1.0:
		assists.append(&"game_speed_assistance")
	return assists
