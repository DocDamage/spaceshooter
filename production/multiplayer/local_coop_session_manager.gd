class_name LocalCoopSessionManager
extends Node

signal player_downed(slot_id: StringName)
signal player_revived(slot_id: StringName)
signal team_defeated
signal connection_paused(slot_id: StringName)

var roster := LocalCoopRoster.new()
var player_states: Dictionary = {}
var actors: Dictionary = {}
var input_service: GameInputService
var shared_lives := false
var starting_lives := 3
var revive_limit := 2
var revive_seconds := 2.0
var team_chain := 0
var command_indicators: Dictionary = {}

func configure(configuration: Dictionary, service: GameInputService) -> bool:
	input_service = service
	shared_lives = bool(configuration.get("shared_lives", false))
	starting_lives = maxi(1, int(configuration.get("lives", 3)))
	revive_limit = maxi(0, int(configuration.get("revive_limit", 2)))
	revive_seconds = maxf(0.25, float(configuration.get("revive_seconds", 2.0)))
	roster.allow_duplicate_ships = bool(configuration.get("allow_duplicate_ships", false))
	var supplied: Array = configuration.get("participants", [])
	if supplied.is_empty(): return false
	for entry in supplied:
		var joined := roster.join(int(entry.device_id), StringName(entry.profile_id), StringName(entry.ship_id), bool(entry.get("guest", false)))
		if not bool(joined.accepted): return false
	roster.lock()
	for participant in roster.participants:
		var state := CoopPlayerState.new()
		state.configure(participant, starting_lives, revive_limit, revive_seconds)
		player_states[participant.slot_id] = state
		if input_service != null: input_service.assign_device(player_states.size() - 1, int(participant.device_id))
	if input_service != null and not input_service.controller_connection_changed.is_connected(_on_controller_connection_changed):
		input_service.controller_connection_changed.connect(_on_controller_connection_changed)
	return true

func attach_actor(slot_id: StringName, actor: ProductionPlayer) -> bool:
	if not player_states.has(slot_id) or actor == null: return false
	actors[slot_id] = actor
	actor.coop_manager = self
	actor.coop_slot_id = slot_id
	return true

func handle_player_defeat(slot_id: StringName) -> bool:
	var state: CoopPlayerState = player_states.get(slot_id)
	if state == null: return false
	var teammate_available := player_states.values().any(func(other): return other != state and not other.eliminated)
	if shared_lives and not teammate_available:
		var team_lives := 0
		for member in player_states.values(): team_lives += member.lives
		if team_lives > 1:
			state.lives = 1
			teammate_available = true
	if not state.down(teammate_available):
		if all_players_eliminated(): team_defeated.emit()
		return false
	player_downed.emit(slot_id)
	return true

func advance_revive(reviver_slot: StringName, target_slot: StringName, delta: float) -> bool:
	var reviver: CoopPlayerState = player_states.get(reviver_slot)
	var target: CoopPlayerState = player_states.get(target_slot)
	if reviver == null or target == null or reviver.downed or reviver.eliminated: return false
	if not target.advance_revive(delta): return false
	var actor: ProductionPlayer = actors.get(target_slot)
	if actor != null: actor.revive_from_coop(0.40)
	player_revived.emit(target_slot)
	return true

func all_players_eliminated() -> bool:
	return not player_states.is_empty() and player_states.values().all(func(state): return state.eliminated)

func checkpoint_snapshot() -> Dictionary:
	var states := {}
	for slot_id in player_states: states[slot_id] = player_states[slot_id].snapshot()
	return {"roster": roster.snapshot(), "player_states": states, "shared_lives": shared_lives}

func restore_checkpoint(snapshot: Dictionary) -> bool:
	if not snapshot.has("roster") or not snapshot.has("player_states"): return false
	if not roster.restore(snapshot.roster): return false
	for slot_id in player_states:
		if not snapshot.player_states.has(slot_id) or not player_states[slot_id].restore(snapshot.player_states[slot_id]): return false
	return true

func difficulty_profile(active_ai_wingmen := 0) -> Dictionary:
	return CoopDifficultyScaler.profile(roster.participants.size(), active_ai_wingmen)

func set_team_chain(value: int) -> void:
	team_chain = maxi(0, value)

func set_command_indicator(slot_id: StringName, command: StringName) -> void:
	if player_states.has(slot_id): command_indicators[slot_id] = command

func _on_controller_connection_changed(device_id: int, connected: bool) -> void:
	if connected: return
	var slot_id := roster.mark_device_disconnected(device_id)
	if not slot_id.is_empty(): connection_paused.emit(slot_id)
