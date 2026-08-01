class_name StageOneVerticalSlice
extends RefCounted

const MISSION_ID := &"mission.stage1_vertical_slice"
const CAMPAIGN_NODE_ID := &"campaign_node.operation1_stage1"
const EQUIPMENT_REWARD_ID := &"equipment.reactor_matrix"

var database: ContentDatabase
var services: ServiceHub
var profile: ProgressionProfile
var mission: MissionDefinition
var campaign := CampaignProgression.new()
var tutorial := TutorialDirector.new()
var metrics := VerticalSliceMetrics.new()
var selected_pilot_id: StringName
var selected_ship_id: StringName
var selected_loadout: Dictionary = {}
var difficulty := 50
var seed := 0

func configure(content_database: ContentDatabase, service_hub: ServiceHub, owner_profile: ProgressionProfile) -> bool:
	database = content_database; services = service_hub; profile = owner_profile
	mission = database.get_definition(MISSION_ID, &"mission") as MissionDefinition if database != null else null
	var node := database.get_definition(CAMPAIGN_NODE_ID, &"campaign_node") as CampaignNodeDefinition if database != null else null
	if mission == null or node == null or services == null or profile == null: return false
	campaign.configure([node], profile.campaign_progress)
	tutorial.configure(services.input, services.settings, true)
	return true

func select_configuration(pilot_id: StringName, ship_id: StringName, loadout: Dictionary, difficulty_rating: int, stage_seed := 0) -> bool:
	if database.get_definition(pilot_id, &"pilot") == null or database.get_definition(ship_id, &"ship") == null: return false
	if difficulty_rating < 0 or difficulty_rating > 100: return false
	selected_pilot_id = pilot_id; selected_ship_id = ship_id; selected_loadout = loadout.duplicate(true); difficulty = difficulty_rating
	seed = stage_seed if stage_seed != 0 else mission.default_seed
	return true

func generate_plan() -> StagePlan:
	if selected_ship_id.is_empty(): return null
	var started := Time.get_ticks_usec()
	var plan := StageGraphGenerator.new().generate(mission, seed, difficulty)
	metrics.samples.generation_ms = float(Time.get_ticks_usec() - started) / 1000.0
	return plan

func create_session_config() -> GameSessionConfig:
	if selected_ship_id.is_empty(): return null
	var config := GameSessionConfig.new(); config.mission_definition = mission
	config.selected_profiles = [profile.profile_id]; config.selected_ships = [selected_ship_id]; config.loadouts = [selected_loadout.duplicate(true)]
	config.difficulty_profile = &"normal"; config.stage_seed = seed; config.mode_rules = {"difficulty_rating": difficulty, "tutorial_enabled": tutorial.enabled, "pilot_id": selected_pilot_id}
	return config

func failure_options(checkpoint: Dictionary, lives_remaining: int) -> Array[StringName]:
	var options: Array[StringName] = [&"restart", &"abandon"]
	if lives_remaining > 0: options.push_front(&"continue")
	if not checkpoint.is_empty(): options.push_front(&"resume_checkpoint")
	if lives_remaining <= 0: options.append(&"game_over")
	return options

func record_temporary_upgrade(upgrade_id: StringName, stacks := 1) -> Dictionary:
	return {"upgrade_id": upgrade_id, "stacks": maxi(1, stacks), "persistent": false}

func complete(result: Dictionary) -> Dictionary:
	var transaction_id := StringName(result.get("transaction_id", ""))
	if transaction_id.is_empty(): return {"claimed": false, "error": &"missing_transaction"}
	var calculated := RewardCalculator.calculate(result)
	var claimed := RewardCalculator.claim(profile, transaction_id, calculated)
	if not claimed: return {"claimed": false, "duplicate": true, "rewards": calculated}
	var equipment := database.get_definition(EQUIPMENT_REWARD_ID, &"equipment") as EquipmentDefinition
	var item_result := InventoryManager.new(profile, [equipment]).acquire(equipment)
	campaign.complete_stage(CAMPAIGN_NODE_ID, StringName(result.get("rank", "C")), result.get("decisions", {}))
	profile.campaign_progress = campaign.snapshot(); profile.last_played_stage = MISSION_ID; profile.selected_pilot_id = selected_pilot_id; profile.unlock(&"mode.boss_practice")
	var started := Time.get_ticks_usec(); var save_error := services.profiles.persist_profile(profile.profile_id); metrics.samples.results_save_ms = float(Time.get_ticks_usec() - started) / 1000.0
	return {"claimed": true, "rewards": calculated, "equipment": item_result, "boss_practice_unlocked": CAMPAIGN_NODE_ID in campaign.boss_practice, "save_error": save_error}

func loadout_comparison(candidate: Dictionary) -> Dictionary:
	var keys := {}
	for equipped_key in selected_loadout:
		keys[equipped_key] = true
	for candidate_key in candidate:
		keys[candidate_key] = true
	var result := {}
	for comparison_key in keys:
		result[comparison_key] = {"equipped": selected_loadout.get(comparison_key), "candidate": candidate.get(comparison_key), "changed": selected_loadout.get(comparison_key) != candidate.get(comparison_key)}
	return result

func can_replay() -> bool:
	return campaign.node_state(CAMPAIGN_NODE_ID) == &"completed"
