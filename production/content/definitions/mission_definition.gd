class_name MissionDefinition
extends ContentDefinition

@export var player_ship_id: StringName
@export var enemy_ids: Array[StringName] = []
@export var default_seed := 20260731
@export var segment_count := 1
@export var campaign_id: StringName = &"campaign.main"
@export_range(1, 60, 1) var stage_number := 1
@export var environment_tags: Array[StringName] = []
@export var enemy_factions: Array[StringName] = []
@export var recipe: MissionRecipeDefinition
@export var encounter_timeline: StageEncounterTimelineDefinition
@export var miniboss_id: StringName
@export var boss_id: StringName
@export var mission_rewards: Dictionary = {}
@export var dialogue_hooks: Dictionary = {}
@export_file("*.png", "*.webp") var background_asset_path := ""
@export_file("*.mp3", "*.ogg", "*.wav") var music_asset_path := ""
@export var music_state: StringName = &"stage"

func get_content_type() -> StringName:
	return &"mission"

func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if player_ship_id.is_empty():
		errors.append("player_ship_id is required for %s" % stable_id)
	if recipe != null:
		errors.append_array(recipe.validate_definition())
	if encounter_timeline != null:
		errors.append_array(encounter_timeline.validate_definition())
		if encounter_timeline.mission_id != stable_id: errors.append("encounter_timeline mission does not match %s" % stable_id)
	if not background_asset_path.is_empty() and not ResourceLoader.exists(background_asset_path):
		errors.append("background_asset_path does not exist for %s" % stable_id)
	if not music_asset_path.is_empty() and not ResourceLoader.exists(music_asset_path):
		errors.append("music_asset_path does not exist for %s" % stable_id)
	return errors
