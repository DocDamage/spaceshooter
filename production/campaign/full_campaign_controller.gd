class_name FullCampaignController
extends RefCounted

const OPERATION_IDS: Array[StringName] = [
	&"operation.frontier_shield", &"operation.2", &"operation.3",
	&"operation.4", &"operation.5", &"operation.6"
]

var database: ContentDatabase
var services: ServiceHub
var profile: ProgressionProfile
var campaign := CampaignProgression.new()
var operations: Dictionary = {}
var missions: Dictionary = {}
var nodes: Dictionary = {}

func configure(content_database: ContentDatabase, service_hub: ServiceHub, owner_profile: ProgressionProfile) -> bool:
	database = content_database
	services = service_hub
	profile = owner_profile
	if database == null or services == null or profile == null: return false
	operations.clear(); missions.clear(); nodes.clear()
	var campaign_nodes: Array[CampaignNodeDefinition] = []
	for operation_index in range(1, 7):
		var definition := database.get_definition(OPERATION_IDS[operation_index - 1], &"operation") as OperationDefinition
		if definition == null: return false
		operations[operation_index] = definition
		for local_stage in range(1, 11):
			var global_stage := (operation_index - 1) * 10 + local_stage
			var mission := database.get_definition(definition.stage_ids[local_stage - 1], &"mission") as MissionDefinition
			var node := database.get_definition(definition.campaign_node_ids[local_stage - 1], &"campaign_node") as CampaignNodeDefinition
			if mission == null or node == null: return false
			missions[global_stage] = mission
			nodes[global_stage] = node
			campaign_nodes.append(node)
	campaign.configure(campaign_nodes, profile.campaign_progress)
	return true

func operation_definition(operation_index: int) -> OperationDefinition:
	return operations.get(operation_index)

func mission_for_stage(global_stage: int) -> MissionDefinition:
	return missions.get(global_stage)

func node_for_stage(global_stage: int) -> CampaignNodeDefinition:
	return nodes.get(global_stage)

func global_stage_for_node(node_id: StringName) -> int:
	for global_stage in nodes:
		var node: CampaignNodeDefinition = nodes[global_stage]
		if node.stable_id == node_id: return int(global_stage)
	return 0

func stage_state(global_stage: int) -> StringName:
	var node := node_for_stage(global_stage)
	return campaign.node_state(node.stable_id) if node != null else &"missing"

func generate_plan(global_stage: int, seed_override := 0, difficulty := 50) -> StagePlan:
	var mission := mission_for_stage(global_stage)
	if mission == null: return null
	return StageGraphGenerator.new().generate(mission, seed_override if seed_override != 0 else mission.default_seed, difficulty)

func review_seed_set(global_stage: int) -> Array:
	if global_stage < 1 or global_stage > 60: return []
	var operation_index := ((global_stage - 1) / 10) + 1
	var local_stage := ((global_stage - 1) % 10) + 1
	return operation_definition(operation_index).review_seeds.get(local_stage, []).duplicate()

func create_session_config(global_stage: int, ship_id: StringName, loadout: Dictionary = {}, difficulty := 50, seed_override := 0) -> GameSessionConfig:
	var mission := mission_for_stage(global_stage)
	if mission == null or stage_state(global_stage) not in [&"available", &"completed"]: return null
	var config := GameSessionConfig.new()
	config.mission_definition = mission
	config.selected_profiles = [profile.profile_id]
	config.selected_ships = [ship_id]
	config.loadouts = [loadout.duplicate(true)]
	config.difficulty_profile = &"normal"
	config.stage_seed = seed_override if seed_override != 0 else mission.default_seed
	config.mode_rules = {"difficulty_rating": difficulty, "operation": ((global_stage - 1) / 10) + 1, "stage": global_stage, "campaign": true}
	return config

func create_local_coop_config(global_stage: int, selections: Array[Dictionary], difficulty := 50, seed_override := 0) -> GameSessionConfig:
	if selections.size() != 2 or StringName(selections[0].get("profile_id", "")) != profile.profile_id: return null
	var config := create_session_config(global_stage, StringName(selections[0].get("ship_id", "")), selections[0].get("loadout", {}), difficulty, seed_override)
	if config == null: return null
	var roster := LocalCoopRoster.new()
	for selection in selections:
		var joined := roster.join(int(selection.get("device_id", GameInputService.UNASSIGNED_DEVICE)), StringName(selection.get("profile_id", "")), StringName(selection.get("ship_id", "")), bool(selection.get("guest", false)))
		if not bool(joined.accepted): return null
	config.selected_profiles.clear(); config.selected_ships.clear(); config.loadouts.clear()
	for index in roster.participants.size():
		config.selected_profiles.append(StringName(roster.participants[index].profile_id))
		config.selected_ships.append(StringName(roster.participants[index].ship_id))
		config.loadouts.append(selections[index].get("loadout", {}).duplicate(true))
	config.multiplayer_configuration = {"local_players": 2, "online": false, "participants": roster.participants.duplicate(true), "lives": 3, "revive_limit": 2, "revive_seconds": 2.0, "shared_lives": false}
	config.mode_rules.cooperative_difficulty = CoopDifficultyScaler.profile(2)
	return config

func create_online_coop_config(global_stage: int, selections: Array[Dictionary], local_peer_id: int, difficulty := 50, seed_override := 0) -> GameSessionConfig:
	if selections.size() != 2 or local_peer_id not in [1, 2]: return null
	if StringName(selections[0].get("profile_id", "")) != profile.profile_id: return null
	var config := create_session_config(global_stage, StringName(selections[0].get("ship_id", "")), selections[0].get("loadout", {}), difficulty, seed_override)
	if config == null: return null
	var plan := generate_plan(global_stage, config.stage_seed, difficulty)
	if plan == null or not StageValidator.validate(plan, config.mission_definition, 2).valid: return null
	config.selected_profiles.clear(); config.selected_ships.clear(); config.loadouts.clear()
	var participants: Array[Dictionary] = []
	for index in selections.size():
		var selection: Dictionary = selections[index]
		var peer_id := index + 1
		var profile_id := StringName(selection.get("profile_id", ""))
		var ship_id := StringName(selection.get("ship_id", ""))
		if profile_id.is_empty() or ship_id.is_empty(): return null
		config.selected_profiles.append(profile_id); config.selected_ships.append(ship_id); config.loadouts.append(selection.get("loadout", {}).duplicate(true))
		participants.append({"peer_id": peer_id, "slot_id": StringName("player_slot.%d" % peer_id), "actor_id": StringName("player.online_%d" % peer_id), "profile_id": profile_id, "ship_id": ship_id, "loadout": selection.get("loadout", {}).duplicate(true), "connected": true, "is_host": peer_id == 1})
	var stage_graph := plan.to_snapshot()
	config.multiplayer_configuration = {"local_players": 1, "online": true, "local_peer_id": local_peer_id, "authority_peer_id": 1, "peer_ids": [1, 2], "participants": participants, "stage_seed": config.stage_seed, "stage_graph": stage_graph, "stage_graph_hash": NetworkProtocol.canonical_state_hash(stage_graph), "host_migration": false, "reconnect_window_seconds": 30}
	config.mode_rules.cooperative_difficulty = CoopDifficultyScaler.profile(2)
	config.mode_rules.online_rollout = &"campaign"
	return config

func create_online_mode_config(global_stage: int, mode_id: StringName, selections: Array[Dictionary], local_peer_id: int, difficulty := 50, seed_override := 0) -> GameSessionConfig:
	if mode_id not in [&"boss_practice", &"arcade"]: return null
	var config := create_online_coop_config(global_stage, selections, local_peer_id, difficulty, seed_override)
	if config == null: return null
	config.mode_rules.campaign = false
	config.mode_rules.mode_id = mode_id
	config.mode_rules.online_rollout = mode_id
	config.mode_rules.disable_campaign_rewards = mode_id == &"boss_practice"
	config.mode_rules.practice = mode_id == &"boss_practice"
	return config

func create_mode_reuse_config(global_stage: int, mode_id: StringName, seed_override := 0) -> GameSessionConfig:
	var config := create_session_config(global_stage, &"ship.vanguard", {}, 50, seed_override)
	if config == null: return null
	config.mode_rules.campaign = false
	config.mode_rules.mode_id = mode_id
	config.mode_rules.disable_campaign_rewards = true
	return config

func new_game_plus_preview_config(global_stage: int, seed_override := 0) -> GameSessionConfig:
	if global_stage < 1 or global_stage > 60: return null
	var mission := mission_for_stage(global_stage)
	var config := GameSessionConfig.new()
	config.mission_definition = mission
	config.selected_profiles = [profile.profile_id]
	config.selected_ships = [&"ship.vanguard"]
	config.loadouts = [{}]
	config.difficulty_profile = &"hard"
	config.stage_seed = seed_override if seed_override != 0 else mission.default_seed
	config.mode_rules = {"new_game_plus_preview": true, "difficulty_rating": 75, "campaign_rewards": false, "stage": global_stage}
	return config

func complete_stage(global_stage: int, result: Dictionary) -> Dictionary:
	var mission := mission_for_stage(global_stage)
	var node := node_for_stage(global_stage)
	var transaction_id := StringName(result.get("transaction_id", ""))
	if mission == null or node == null or transaction_id.is_empty(): return {"claimed": false, "error": &"invalid_completion"}
	if stage_state(global_stage) not in [&"available", &"completed"]: return {"claimed": false, "error": &"stage_locked"}
	var reward_input := result.duplicate(true)
	reward_input.base_xp = int(result.get("base_xp", mission.mission_rewards.get("xp", 0)))
	reward_input.base_currency = int(result.get("base_currency", mission.mission_rewards.get("credits", 0)))
	var calculated := RewardCalculator.calculate(reward_input)
	if not RewardCalculator.claim(profile, transaction_id, calculated): return {"claimed": false, "duplicate": true, "rewards": calculated}
	var equipment_result := {"accepted": false, "reason": &"none"}
	var equipment_id := StringName(mission.mission_rewards.get("equipment_id", ""))
	if not equipment_id.is_empty():
		var equipment := database.get_definition(equipment_id, &"equipment") as EquipmentDefinition
		if equipment != null: equipment_result = InventoryManager.new(profile, [equipment]).acquire(equipment)
	if not campaign.complete_stage(node.stable_id, StringName(result.get("rank", "C")), result.get("decisions", {})):
		return {"claimed": false, "error": &"progression_rejected"}
	var operation_index := ((global_stage - 1) / 10) + 1
	var local_stage := ((global_stage - 1) % 10) + 1
	for unlock_id in operation_definition(operation_index).unlocks_by_stage.get(local_stage, []): profile.unlock(StringName(unlock_id))
	var declared_unlock := StringName(mission.mission_rewards.get("unlock", ""))
	if not declared_unlock.is_empty(): profile.unlock(declared_unlock)
	if local_stage == 10:
		campaign.set_story_flag(StringName("operation%d_complete" % operation_index), true)
		if operation_index < 6: profile.unlock(StringName("campaign.operation%d" % (operation_index + 1)))
		else:
			profile.unlock(&"campaign.complete")
			profile.unlock(&"campaign.postgame")
			profile.unlock(&"mode.new_game_plus")
			campaign.set_story_flag(&"campaign_resolved", true)
	profile.campaign_progress = campaign.snapshot()
	profile.last_played_stage = mission.stable_id
	var save_error := services.profiles.persist_profile(profile.profile_id)
	return {"claimed": true, "rewards": calculated, "equipment": equipment_result, "practice_ids": node.practice_boss_ids.duplicate(), "next_stage_available": global_stage == 60 or stage_state(global_stage + 1) == &"available", "operation_complete": local_stage == 10, "campaign_complete": global_stage == 60, "save_error": save_error}

func complete_local_coop_stage(global_stage: int, result: Dictionary, selections: Array[Dictionary]) -> Dictionary:
	var host_result := complete_stage(global_stage, result)
	if not bool(host_result.get("claimed", false)): return host_result
	var companion_claims: Array[StringName] = []
	for selection in selections:
		if bool(selection.get("guest", false)): continue
		var profile_id := StringName(selection.get("profile_id", ""))
		if profile_id == profile.profile_id: continue
		var companion := services.profiles.get_progression_profile(profile_id, false)
		var companion_transaction := StringName("%s.%s" % [StringName(result.get("transaction_id", "")), profile_id])
		if companion != null and RewardCalculator.claim(companion, companion_transaction, host_result.rewards):
			services.profiles.persist_profile(profile_id)
			companion_claims.append(profile_id)
	host_result.companion_claims = companion_claims
	host_result.host_progression = true
	return host_result

func operation_complete(operation_index: int) -> bool:
	return bool(campaign.story_flags.get(StringName("operation%d_complete" % operation_index), false))

func campaign_complete() -> bool:
	return bool(campaign.story_flags.get(&"campaign_resolved", false)) and campaign.completed.size() == 60

func record_campaign_decision(decision_id: StringName, value: Variant) -> bool:
	if decision_id.is_empty() or campaign.decisions.has(decision_id): return false
	campaign.decisions[decision_id] = value
	profile.campaign_progress = campaign.snapshot()
	return services.profiles.persist_profile(profile.profile_id) == OK

func progression_review() -> Array[Dictionary]:
	var review: Array[Dictionary] = []
	for operation_index in range(1, 7):
		var definition := operation_definition(operation_index)
		review.append({"operation": operation_index, "entry_level": 1 if operation_index == 1 else (operation_index - 1) * 10, "exit_level": operation_index * 10, "equipment_tier": operation_index, "weapon_level_target": mini(10, operation_index + 2), "spell_level_target": mini(10, operation_index + 1), "economy_gates": definition.economy_targets.duplicate(true), "required_grind_runs": 0, "story_beats": definition.story_beats.size(), "unlock_beats": definition.unlocks_by_stage.size()})
	return review
