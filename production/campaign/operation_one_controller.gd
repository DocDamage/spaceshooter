class_name OperationOneController
extends RefCounted

const OPERATION_ID := &"operation.frontier_shield"

var database: ContentDatabase
var services: ServiceHub
var profile: ProgressionProfile
var definition: OperationDefinition
var campaign := CampaignProgression.new()
var missions: Dictionary = {}
var nodes: Dictionary = {}

func configure(content_database: ContentDatabase, service_hub: ServiceHub, owner_profile: ProgressionProfile) -> bool:
	database = content_database
	services = service_hub
	profile = owner_profile
	definition = database.get_definition(OPERATION_ID, &"operation") as OperationDefinition if database != null else null
	if definition == null or services == null or profile == null: return false
	var node_definitions: Array[CampaignNodeDefinition] = []
	for index in definition.stage_ids.size():
		var mission := database.get_definition(definition.stage_ids[index], &"mission") as MissionDefinition
		var node := database.get_definition(definition.campaign_node_ids[index], &"campaign_node") as CampaignNodeDefinition
		if mission == null or node == null: return false
		missions[mission.stage_number] = mission
		nodes[mission.stage_number] = node
		node_definitions.append(node)
	campaign.configure(node_definitions, profile.campaign_progress)
	return true

func mission_for_stage(stage_number: int) -> MissionDefinition:
	return missions.get(stage_number)

func generate_plan(stage_number: int, seed_override := 0, difficulty := 50) -> StagePlan:
	var mission := mission_for_stage(stage_number)
	if mission == null: return null
	return StageGraphGenerator.new().generate(mission, seed_override if seed_override != 0 else mission.default_seed, difficulty)

func create_session_config(stage_number: int, ship_id: StringName, loadout: Dictionary = {}, difficulty := 50, seed_override := 0) -> GameSessionConfig:
	var mission := mission_for_stage(stage_number)
	if mission == null or campaign.node_state(nodes[stage_number].stable_id) not in [&"available", &"completed"]: return null
	var config := GameSessionConfig.new()
	config.mission_definition = mission
	config.selected_profiles = [profile.profile_id]
	config.selected_ships = [ship_id]
	config.loadouts = [loadout.duplicate(true)]
	config.difficulty_profile = &"normal"
	config.stage_seed = seed_override if seed_override != 0 else mission.default_seed
	config.mode_rules = {"difficulty_rating": difficulty, "operation": 1, "stage": stage_number}
	return config

func create_local_coop_config(stage_number: int, selections: Array[Dictionary], difficulty := 50, seed_override := 0) -> GameSessionConfig:
	if selections.size() != 2: return null
	var host_profile_id := StringName(selections[0].get("profile_id", ""))
	if host_profile_id != profile.profile_id: return null
	var config := create_session_config(stage_number, StringName(selections[0].get("ship_id", "")), selections[0].get("loadout", {}), difficulty, seed_override)
	if config == null: return null
	var roster := LocalCoopRoster.new()
	for selection in selections:
		var joined := roster.join(int(selection.get("device_id", GameInputService.UNASSIGNED_DEVICE)), StringName(selection.get("profile_id", "")), StringName(selection.get("ship_id", "")), bool(selection.get("guest", false)))
		if not bool(joined.accepted): return null
	config.selected_profiles.clear(); config.selected_ships.clear(); config.loadouts.clear()
	for participant_index in roster.participants.size():
		config.selected_profiles.append(StringName(roster.participants[participant_index].profile_id))
		config.selected_ships.append(StringName(roster.participants[participant_index].ship_id))
		config.loadouts.append(selections[participant_index].get("loadout", {}).duplicate(true))
	config.multiplayer_configuration = {"local_players": 2, "online": false, "participants": roster.participants.duplicate(true), "lives": 3, "revive_limit": 2, "revive_seconds": 2.0, "shared_lives": false}
	config.mode_rules.cooperative_difficulty = CoopDifficultyScaler.profile(2)
	return config

func complete_local_coop_stage(stage_number: int, result: Dictionary, selections: Array[Dictionary]) -> Dictionary:
	var host_result := complete_stage(stage_number, result)
	if not bool(host_result.get("claimed", false)): return host_result
	var calculated: Dictionary = host_result.rewards
	var companion_claims: Array[StringName] = []
	for selection in selections:
		if bool(selection.get("guest", false)): continue
		var profile_id := StringName(selection.get("profile_id", ""))
		if profile_id == profile.profile_id: continue
		var companion := services.profiles.get_progression_profile(profile_id, false)
		var companion_transaction := StringName("%s.%s" % [StringName(result.get("transaction_id", "")), profile_id])
		if companion != null and RewardCalculator.claim(companion, companion_transaction, calculated):
			services.profiles.persist_profile(profile_id)
			companion_claims.append(profile_id)
	host_result.companion_claims = companion_claims
	host_result.host_progression = true
	return host_result

func complete_stage(stage_number: int, result: Dictionary) -> Dictionary:
	var mission := mission_for_stage(stage_number)
	var node: CampaignNodeDefinition = nodes.get(stage_number)
	var transaction_id := StringName(result.get("transaction_id", ""))
	if mission == null or node == null or transaction_id.is_empty(): return {"claimed": false, "error": &"invalid_completion"}
	if campaign.node_state(node.stable_id) not in [&"available", &"completed"]: return {"claimed": false, "error": &"stage_locked"}
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
	campaign.complete_stage(node.stable_id, StringName(result.get("rank", "C")), result.get("decisions", {}))
	for unlock_id in definition.unlocks_by_stage.get(stage_number, []): profile.unlock(StringName(unlock_id))
	if stage_number == 10:
		profile.unlock(&"campaign.operation2")
		campaign.set_story_flag(&"operation1_complete", true)
	profile.campaign_progress = campaign.snapshot()
	profile.last_played_stage = mission.stable_id
	var save_error := services.profiles.persist_profile(profile.profile_id)
	return {"claimed": true, "rewards": calculated, "equipment": equipment_result, "practice_ids": node.practice_boss_ids.duplicate(), "next_stage_available": stage_number == 10 or campaign.node_state(nodes[stage_number + 1].stable_id) == &"available", "save_error": save_error}

func review_seed_set(stage_number: int) -> Array:
	return definition.review_seeds.get(stage_number, []).duplicate()

func economy_checkpoint(stage_number: int) -> Dictionary:
	return definition.economy_targets.get(stage_number, {}).duplicate(true)

func operation_complete() -> bool:
	return bool(campaign.story_flags.get(&"operation1_complete", false)) and profile.unlocked_content.has(&"campaign.operation2")
