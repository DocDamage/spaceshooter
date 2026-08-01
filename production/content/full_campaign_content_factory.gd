class_name FullCampaignContentFactory
extends RefCounted

const OPERATION_BACKGROUNDS := {
	2: "res://assets_runtime/backgrounds/background_space_blue_01_sheet.png",
	3: "res://assets_runtime/backgrounds/background_nebula_violet_sheet.png",
	4: "res://assets_runtime/backgrounds/background_warfront_amber_sheet.png",
	5: "res://assets_runtime/backgrounds/background_frontier_planets_final.png",
	6: "res://assets_runtime/backgrounds/background_convergence_gold_sheet.png"
}
const CAMPAIGN_MUSIC := "res://assets_runtime/audio/music_stage1_frontier_theme.ogg"
const SPECIALIST_SHIP_VISUALS := {
	2: "res://assets_runtime/players/ship_aegis_spear.png",
	3: "res://assets_runtime/players/ship_veil_skimmer.png",
	4: "res://assets_runtime/players/ship_banner_warden.png",
	5: "res://assets_runtime/players/ship_arsenal_talon.png",
	6: "res://assets_runtime/players/ship_convergence_star.png"
}

const OPERATION_NAMES := {
	2: "Spearhead Doctrine", 3: "The Shattered Veil", 4: "War of Three Banners",
	5: "The Last Arsenal", 6: "Convergence"
}
const THEMES := {
	2: "Specialized ships break advanced formations under sustained missile pressure.",
	3: "Alien technology, projectile conversion, anomalies, and secret routes reshape the war.",
	4: "Three factions collide amid complex objectives, system damage, and environmental weapons.",
	5: "Elite fleets and returning war machines test endgame builds and campaign consequences.",
	6: "The final invasion combines every campaign mechanic and resolves the pilot's decisions."
}
const ENVIRONMENTS := {
	2: [&"formation_grid", &"missile_front", &"fleet_yards"],
	3: [&"alien_ruins", &"anomaly", &"phase_space"],
	4: [&"contested_system", &"orbital_weapon", &"damaged_station"],
	5: [&"elite_bastion", &"graveyard", &"endgame_front"],
	6: [&"invasion_core", &"homeworld", &"convergence_rift"]
}
const FACTIONS := {
	2: [&"faction.alien_vanguard", &"faction.raiders"],
	3: [&"faction.alien_vanguard", &"faction.ancient_machine"],
	4: [&"faction.human_defense", &"faction.raiders", &"faction.alien_vanguard"],
	5: [&"faction.alien_vanguard", &"faction.elite_legion"],
	6: [&"faction.human_defense", &"faction.raiders", &"faction.alien_vanguard", &"faction.elite_legion"]
}
const MECHANICS := {
	2: [&"advanced_formations", &"ship_specialization", &"missile_lock_pressure", &"equipment_set_identity", &"wingman_intercepts", &"formation_rotation", &"countermeasure_timing", &"specialist_routes", &"combined_wings", &"doctrine_finale"],
	3: [&"alien_salvage", &"projectile_conversion", &"anomaly_drift", &"secret_route_scan", &"phase_hazards", &"branch_commitment", &"conversion_chains", &"unstable_environment", &"veil_breach", &"alien_technology_finale"],
	4: [&"mixed_factions", &"objective_priority", &"system_damage", &"orbital_weaponry", &"faction_reputation", &"multi_objective_defense", &"repair_under_fire", &"weapon_capture", &"three_way_battle", &"faction_war_finale"],
	5: [&"elite_screen", &"returning_miniboss", &"endgame_build_check", &"high_tier_equipment", &"operation_consequence", &"elite_gauntlet", &"variant_counterplay", &"loadout_mastery", &"arsenal_siege", &"endgame_finale"],
	6: [&"final_invasion", &"combined_formations", &"combined_anomalies", &"combined_objectives", &"fleet_decision", &"major_boss_sequence", &"allied_consequence", &"final_approach", &"last_decision", &"campaign_resolution"]
}
const ENEMY_ROSTERS := {
	2: [&"enemy.dart", &"enemy.hunter", &"enemy.interceptor", &"enemy.lancer", &"enemy.harrier"],
	3: [&"enemy.phantom", &"enemy.stalker", &"enemy.sentinel", &"enemy.reaver", &"enemy.guardian"],
	4: [&"enemy.corsair", &"enemy.raider", &"enemy.marauder", &"enemy.commander", &"enemy.bomber"],
	5: [&"enemy.guardian", &"enemy.commander", &"enemy.talon", &"enemy.striker", &"enemy.reaver"],
	6: [&"enemy.wasp", &"enemy.viper", &"enemy.phantom", &"enemy.commander", &"enemy.guardian", &"enemy.reaver"]
}
const OPERATION_SEGMENTS := {
	2: [&"formation_combat", &"turret_corridor", &"escort", &"standard_combat", &"survival"],
	3: [&"hazard_field", &"asteroid_field", &"debris_field", &"sabotage", &"branch"],
	4: [&"rescue", &"escort", &"sabotage", &"turret_corridor", &"survival"],
	5: [&"elite_encounter", &"survival", &"formation_combat", &"turret_corridor", &"hazard_field"],
	6: [&"formation_combat", &"hazard_field", &"rescue", &"elite_encounter", &"survival"]
}

static func build() -> Array[ContentDefinition]:
	var result: Array[ContentDefinition] = []
	result.append_array(_progression_definitions())
	var segments := _segment_library()
	var miniboss_template := load("res://production/content/data/boss/operation1_minibosses.tres") as BossDefinition
	var boss_template := load("res://production/content/data/boss/xenarch_command_carrier.tres") as BossDefinition
	for operation_index in range(2, 7):
		var operation := _operation(operation_index)
		result.append(operation)
		for local_stage in range(1, 11):
			var global_stage := (operation_index - 1) * 10 + local_stage
			var recipe := _stage_recipe(operation_index, local_stage, segments)
			result.append(recipe)

			var miniboss := miniboss_template.duplicate(true) as BossDefinition
			miniboss.stable_id = _miniboss_id(operation_index, local_stage)
			miniboss.display_name = "%s %s" % [FullCampaignNarrativeFactory.stage_title(operation_index, local_stage, MECHANICS[operation_index][local_stage - 1]), "Warden"]
			miniboss.content_version = "18.1"
			miniboss.maximum_health = 900.0 + global_stage * 55.0
			miniboss.armor = 3.0 + operation_index
			miniboss.shield_capacity = 100.0 + global_stage * 18.0
			miniboss.arena_profile = {"attack_identity": MECHANICS[operation_index][local_stage - 1], "operation": operation_index, "stage": local_stage, "safe_entry": Vector2(270, 860)}
			miniboss.visual_tint = FullCampaignNarrativeFactory.operation_color(operation_index).lightened(float(local_stage % 3) * 0.08)
			miniboss.visual_scale = 1.0 + operation_index * 0.04
			miniboss.collision_radius = 34.0 + operation_index * 2.0
			miniboss.phases.assign(_boss_phases(operation_index, local_stage, false))
			result.append(miniboss)

			var finale_boss: BossDefinition
			if local_stage == 10:
				finale_boss = boss_template.duplicate(true) as BossDefinition
				finale_boss.stable_id = _boss_id(operation_index)
				finale_boss.display_name = "%s Command" % OPERATION_NAMES[operation_index]
				finale_boss.content_version = "18.1"
				finale_boss.maximum_health = 6500.0 + operation_index * 1800.0
				finale_boss.armor = 10.0 + operation_index * 2.0
				finale_boss.shield_capacity = 1400.0 + operation_index * 500.0
				finale_boss.arena_profile = {"attack_identity": MECHANICS[operation_index][9], "operation": operation_index, "major_sequence": operation_index == 6, "safe_entry": Vector2(270, 860)}
				finale_boss.visual_tint = FullCampaignNarrativeFactory.operation_color(operation_index)
				finale_boss.visual_scale = 1.2 + operation_index * 0.06
				finale_boss.collision_radius = 72.0 + operation_index * 4.0
				finale_boss.phases.assign(_boss_phases(operation_index, local_stage, true))
				result.append(finale_boss)

			var mission := MissionDefinition.new()
			mission.stable_id = _mission_id(operation_index, local_stage)
			mission.display_name = recipe.display_name
			mission.content_version = "21.0"
			mission.player_ship_id = &"ship.vanguard"
			mission.enemy_ids.assign(ENEMY_ROSTERS[operation_index])
			mission.default_seed = 180000 + operation_index * 1000 + local_stage * 10 + 1
			mission.segment_count = recipe.required_sequence.size()
			mission.stage_number = global_stage
			mission.environment_tags.assign(ENVIRONMENTS[operation_index])
			mission.enemy_factions.assign(FACTIONS[operation_index])
			mission.background_asset_path = OPERATION_BACKGROUNDS[operation_index]
			mission.music_asset_path = CAMPAIGN_MUSIC
			mission.music_state = StringName("operation_%d_stage" % operation_index)
			mission.recipe = recipe
			mission.miniboss_id = miniboss.stable_id
			mission.boss_id = finale_boss.stable_id if finale_boss != null else &""
			mission.mission_rewards = {"xp": 600 + global_stage * 55, "credits": 700 + global_stage * 85, "tier": operation_index, "unlock": _unlock_id(operation_index, local_stage)}
			if local_stage in [2, 6, 9]: mission.mission_rewards.equipment_id = _equipment_id(operation_index, local_stage)
			mission.dialogue_hooks = {"briefing": _dialogue_id(operation_index, local_stage, &"briefing"), "results": _dialogue_id(operation_index, local_stage, &"results")}
			result.append(FullCampaignNarrativeFactory.dialogue_definition(operation_index, local_stage, &"briefing", MECHANICS[operation_index][local_stage - 1], _dialogue_id(operation_index, local_stage, &"briefing")))
			result.append(FullCampaignNarrativeFactory.dialogue_definition(operation_index, local_stage, &"results", MECHANICS[operation_index][local_stage - 1], _dialogue_id(operation_index, local_stage, &"results")))
			result.append(mission)

			var node := CampaignNodeDefinition.new()
			node.stable_id = _node_id(operation_index, local_stage)
			node.display_name = mission.display_name
			node.content_version = "18.1"
			node.operation_index = operation_index
			node.stage_index = local_stage
			node.mission_id = mission.stable_id
			node.prerequisite_node_ids.append(_node_id(operation_index, local_stage - 1) if local_stage > 1 else _node_id(operation_index - 1, 10))
			node.boss_node = local_stage == 10
			node.practice_boss_ids.append(miniboss.stable_id)
			if finale_boss != null: node.practice_boss_ids.append(finale_boss.stable_id)
			node.reward_preview = mission.mission_rewards.duplicate(true)
			node.map_position = Vector2(100 + local_stage * 110, 150 + (operation_index - 1) * 135)
			result.append(node)
	return result

static func _progression_definitions() -> Array[ContentDefinition]:
	var result: Array[ContentDefinition] = []
	for operation_index in range(2, 7):
		var ship := ShipDefinition.new()
		ship.stable_id = _ship_id(operation_index)
		ship.display_name = ["Aegis Spear", "Veil Skimmer", "Banner Warden", "Arsenal Talon", "Convergence Star"][operation_index - 2]
		ship.content_version = "18.2"
		ship.visual_asset_path = SPECIALIST_SHIP_VISUALS[operation_index]
		ship.visual_scale = 0.72
		ship.max_health = 90 + operation_index * 14
		ship.move_speed = 350.0 - operation_index * 8.0
		ship.armor = 3.0 + operation_index * 1.5
		ship.shield_capacity = 35.0 + operation_index * 14.0
		ship.shield_recharge_rate = 11.0 + operation_index
		ship.default_weapon_id = &"weapon.pulse_cannon"
		result.append(ship)
		for stage in [2, 6, 9]:
			var equipment := EquipmentDefinition.new()
			equipment.stable_id = _equipment_id(operation_index, stage)
			equipment.display_name = "%s %s" % [OPERATION_NAMES[operation_index], {2: "Targeting Set", 6: "Defense Set", 9: "Mastery Set"}[stage]]
			equipment.content_version = "18.2"
			equipment.slot = {2: &"weapon_system", 6: &"core", 9: &"thrusters"}[stage]
			equipment.rarity = mini(EquipmentDefinition.Rarity.LEGENDARY, operation_index - 1)
			var scale := float(operation_index) * (1.0 + float(stage) * 0.04)
			equipment.modifiers = {&"damage": snappedf(0.025 * scale, 0.001), &"shield": snappedf(4.0 * scale, 0.1), &"move_speed": snappedf(2.0 * scale, 0.1)}
			equipment.set_id = StringName("equipment_set.operation%d" % operation_index)
			equipment.set_bonus_required = 2
			equipment.set_bonus = {&"damage": snappedf(0.04 * operation_index, 0.001), &"shield": 8.0 * operation_index}
			equipment.allowed_ship_ids.assign([&"ship.vanguard", &"ship.bastion", &"ship.lancer", ship.stable_id])
			equipment.sell_value = 250 * operation_index + 40 * stage
			equipment.dismantle_value = int(equipment.sell_value / 2)
			equipment.duplicate_policy = &"convert"
			result.append(equipment)
	return result

static func _boss_phases(operation_index: int, local_stage: int, finale: bool) -> Array[BossPhaseDefinition]:
	var result: Array[BossPhaseDefinition] = []
	var phase_count := 3 if finale else 1
	for phase_index in range(phase_count):
		var pattern := AttackPatternDefinition.new()
		pattern.stable_id = StringName("attack.operation%d_stage%d_phase%d" % [operation_index, local_stage, phase_index + 1])
		pattern.display_name = "%s Pattern %d" % [FullCampaignNarrativeFactory.stage_title(operation_index, local_stage, MECHANICS[operation_index][local_stage - 1]), phase_index + 1]
		pattern.content_version = "18.2"
		pattern.pattern = (operation_index * 7 + local_stage * 3 + phase_index * 5) % (AttackPatternDefinition.Pattern.WALL_WITH_GAPS + 1)
		pattern.projectile_count = 3 + operation_index + phase_index * 2
		pattern.burst_count = 1 + int(local_stage >= 6) + phase_index
		pattern.spread_degrees = 18.0 + local_stage * 2.0 + phase_index * 12.0
		pattern.projectile_speed = 190.0 + operation_index * 18.0 + local_stage * 2.0
		pattern.damage = 5.0 + operation_index * 1.5 + phase_index * 2.0
		pattern.cooldown = maxf(0.55, 1.65 - operation_index * 0.08 - phase_index * 0.12)
		pattern.gap_count = 2 + phase_index
		pattern.gap_width = 76.0 - phase_index * 6.0
		pattern.telegraph_seconds = maxf(0.2, 0.55 - operation_index * 0.04)
		var deck := AttackDeckDefinition.new()
		deck.stable_id = StringName("attack_deck.operation%d_stage%d_phase%d" % [operation_index, local_stage, phase_index + 1])
		deck.display_name = "%s Deck %d" % [FullCampaignNarrativeFactory.stage_title(operation_index, local_stage, MECHANICS[operation_index][local_stage - 1]), phase_index + 1]
		deck.content_version = "18.2"
		deck.attack_patterns.append(pattern)
		deck.selection_mode = &"distance" if phase_index == 1 else (&"random" if phase_index == 2 else &"sequential")
		var phase := BossPhaseDefinition.new()
		phase.stable_id = StringName("boss_phase.operation%d_stage%d_phase%d" % [operation_index, local_stage, phase_index + 1])
		phase.display_name = "%s Phase %d" % [FullCampaignNarrativeFactory.stage_title(operation_index, local_stage, MECHANICS[operation_index][local_stage - 1]), phase_index + 1]
		phase.content_version = "18.2"
		phase.health_threshold = [1.0, 0.66, 0.33][phase_index]
		phase.attack_decks.append(deck)
		phase.arena_behavior = {"mechanic": MECHANICS[operation_index][local_stage - 1], "phase": phase_index + 1, "combined_sequence": finale and operation_index == 6}
		phase.music_state = StringName("operation%d_phase%d" % [operation_index, phase_index + 1])
		phase.enrage_after = 75.0 - operation_index * 4.0
		result.append(phase)
	return result

static func _segment_library() -> Dictionary:
	var result := {}
	for segment_name in ["opening", "standard_combat", "formation_combat", "hazard_field", "turret_corridor", "asteroid_field", "debris_field", "elite_encounter", "rescue", "escort", "sabotage", "survival", "branch", "secret", "checkpoint", "miniboss", "pre_boss", "boss", "exit"]:
		result[StringName(segment_name)] = load("res://production/content/data/segment/%s.tres" % segment_name) as StageSegmentDefinition
	return result

static func _stage_recipe(operation_index: int, local_stage: int, segments: Dictionary) -> MissionRecipeDefinition:
	var recipe := MissionRecipeDefinition.new()
	recipe.stable_id = _recipe_id(operation_index, local_stage)
	recipe.display_name = "%d-%d %s" % [operation_index, local_stage, FullCampaignNarrativeFactory.stage_title(operation_index, local_stage, MECHANICS[operation_index][local_stage - 1])]
	recipe.content_version = "18.2"
	var cycle: Array = OPERATION_SEGMENTS[operation_index]
	var identity: Array[StageSegmentDefinition] = []
	var direction := -1 if local_stage > 5 else 1
	for offset in range(5): identity.append(segments[cycle[posmod(local_stage - 1 + offset * direction, cycle.size())]])
	var use_branches := local_stage in [3, 5, 8, 9] or operation_index == 3
	var authored: Array[StageSegmentDefinition] = [segments[&"opening"], identity[0], segments[&"branch"] if use_branches else identity[1], identity[2], segments[&"checkpoint"], segments[&"miniboss"], identity[3], identity[4], segments[&"pre_boss"]]
	if local_stage == 10:
		authored = [segments[&"opening"], identity[0], identity[1], segments[&"branch"], identity[2], segments[&"checkpoint"], segments[&"miniboss"], identity[3], identity[4], segments[&"pre_boss"], segments[&"boss"]]
		recipe.branch_count = 1
	else:
		recipe.branch_count = 2 if use_branches else 0
	authored.append(segments[&"exit"])
	recipe.required_sequence.assign(authored)
	recipe.branch_pool.assign([segments[&"secret"], segments[&"sabotage"], segments[&"rescue"]])
	recipe.minimum_segment_count = authored.size()
	recipe.maximum_segment_count = authored.size()
	recipe.repetition_limit = 2
	recipe.allowed_factions.assign(FACTIONS[operation_index])
	recipe.allow_secrets = use_branches or local_stage == 10
	return recipe

static func _operation(index: int) -> OperationDefinition:
	var operation := OperationDefinition.new()
	operation.stable_id = StringName("operation.%d" % index)
	operation.display_name = "Operation %d: %s" % [index, OPERATION_NAMES[index]]
	operation.content_version = "18.1"
	operation.operation_index = index
	operation.theme = THEMES[index]
	operation.environment_tags.assign(ENVIRONMENTS[index])
	operation.faction_ids.assign(FACTIONS[index])
	operation.enemy_roster_ids.assign(ENEMY_ROSTERS[index])
	for stage in range(1, 11):
		operation.stage_ids.append(_mission_id(index, stage))
		operation.campaign_node_ids.append(_node_id(index, stage))
		operation.miniboss_ids.append(_miniboss_id(index, stage))
		operation.stage_mechanics[stage] = MECHANICS[index][stage - 1]
		operation.story_beats[stage] = FullCampaignNarrativeFactory.story_beat(index, stage, MECHANICS[index][stage - 1])
		var unlocks: Array[StringName] = [_unlock_id(index, stage)]
		if stage in [2, 6, 9]: unlocks.append(_equipment_id(index, stage))
		if stage == 4: unlocks.append(_spell_id(index))
		if stage == 8: unlocks.append(_ship_id(index))
		if stage == 10: unlocks.append(StringName("operation%d.complete" % index))
		operation.unlocks_by_stage[stage] = unlocks
		operation.review_seeds[stage] = [180000 + index * 1000 + stage * 10 + 1, 180000 + index * 1000 + stage * 10 + 2, 180000 + index * 1000 + stage * 10 + 3]
	operation.economy_targets = {3: {"expected_level": index * 9 + 3, "currency_min": index * 2500, "currency_max": index * 15000}, 6: {"expected_level": index * 9 + 6, "currency_min": index * 4000, "currency_max": index * 21000}, 10: {"expected_level": index * 10 + 1, "currency_min": index * 6500, "currency_max": index * 30000}}
	operation.segment_usage_targets = {&"opening": 10, &"checkpoint": 10, &"miniboss": 10, &"pre_boss": 10, &"boss": 1, &"branch": 4, &"secret": 4}
	operation.operation_boss_id = _boss_id(index)
	operation.secret_route_stages.assign([3, 5, 8, 9])
	operation.validation_plan = {"profiles": [&"fresh", &"expected_level", &"new_game_plus_preview", &"local_coop", &"accessibility"], "checkpoint_matrix": true, "seed_batch_size": 3, "mode_reuse": true, "performance_budget_usec": 50000}
	operation.production_batches = {"proof": [1, 2, 3], "mid": [4, 5, 6, 7], "finale": [8, 9, 10]}
	operation.next_operation_node_id = _node_id(index + 1, 1) if index < 6 else &"campaign.postgame"
	return operation

static func authored_stage_content(operation: int, stage: int) -> Dictionary: return FullCampaignNarrativeFactory.authored_stage_content(operation, stage)
static func authored_stage_count() -> int: return FullCampaignNarrativeFactory.authored_stage_count()

static func _mission_id(operation: int, stage: int) -> StringName: return StringName("mission.operation%d_stage%d" % [operation, stage])
static func _recipe_id(operation: int, stage: int) -> StringName: return StringName("recipe.operation%d_stage%d" % [operation, stage])
static func _node_id(operation: int, stage: int) -> StringName: return StringName("campaign_node.operation%d_stage%d" % [operation, stage])
static func _miniboss_id(operation: int, stage: int) -> StringName: return StringName("boss.operation%d_stage%d_miniboss" % [operation, stage])
static func _boss_id(operation: int) -> StringName: return StringName("boss.operation%d_finale" % operation)
static func _unlock_id(operation: int, stage: int) -> StringName: return StringName("campaign.unlock.o%d.s%d" % [operation, stage])
static func _dialogue_id(operation: int, stage: int, kind: StringName) -> StringName: return StringName("dialogue.operation%d_stage%d.%s" % [operation, stage, kind])
static func _ship_id(operation: int) -> StringName: return StringName("ship.operation%d_specialist" % operation)
static func _equipment_id(operation: int, stage: int) -> StringName: return StringName("equipment.operation%d_stage%d_set" % [operation, stage])
static func _spell_id(operation: int) -> StringName: return [&"spell.storm", &"spell.warp", &"spell.gravity", &"spell.solar", &"spell.void"][operation - 2]
