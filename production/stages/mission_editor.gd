class_name MissionEditor
extends RefCounted

var mission := MissionDefinition.new()
var recipe := MissionRecipeDefinition.new()
var preview_seeds: Array[int] = []

func create_mission(stable_id: StringName, display_name: String, campaign_id: StringName, stage_number: int) -> MissionDefinition:
	mission = MissionDefinition.new()
	mission.stable_id = stable_id
	mission.display_name = display_name
	mission.campaign_id = campaign_id
	mission.stage_number = clampi(stage_number, 1, 60)
	recipe = MissionRecipeDefinition.new()
	recipe.stable_id = StringName("recipe.%s" % String(stable_id).trim_prefix("mission."))
	recipe.display_name = "%s Recipe" % display_name
	mission.recipe = recipe
	return mission

func assign_environment(tags: Array[StringName]) -> void: mission.environment_tags = tags.duplicate()
func assign_factions(factions: Array[StringName]) -> void: mission.enemy_factions = factions.duplicate()
func assign_bosses(miniboss_id: StringName, boss_id: StringName) -> void: mission.miniboss_id = miniboss_id; mission.boss_id = boss_id
func define_rewards(rewards: Dictionary) -> void: mission.mission_rewards = rewards.duplicate(true)
func define_dialogue_hooks(hooks: Dictionary) -> void: mission.dialogue_hooks = hooks.duplicate(true)

func generate_preview_seeds(count := 3, base_seed := 1) -> Array[int]:
	preview_seeds.clear()
	for offset in clampi(count, 1, 20): preview_seeds.append(base_seed + offset)
	return preview_seeds.duplicate()

func validate() -> PackedStringArray:
	var errors := mission.validate_definition()
	errors.append_array(recipe.validate_definition())
	return errors

func save_resources(mission_path: String, recipe_path: String) -> Error:
	if not validate().is_empty(): return ERR_INVALID_DATA
	var recipe_error := ResourceSaver.save(recipe, recipe_path)
	if recipe_error != OK: return recipe_error
	return ResourceSaver.save(mission, mission_path)
