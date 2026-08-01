class_name ProgressionProfile
extends Resource

const MAX_STAT_RANK := 50
const MAX_ABILITY_LEVEL := 10

@export var profile_id: StringName = &"profile.local_1"
@export var display_name := "Pilot 1"
@export var playtime_seconds := 0
@export var campaign_progress: Dictionary = {}
@export var last_played_stage: StringName = &""
@export var new_game_plus_cycle := 0
@export var profile_settings: Dictionary = {}
@export_range(1, 99) var level := 1
@export var current_experience := 0
@export var statistic_points := 0
@export var skill_points := 0
@export var currency := 0
@export var narrative_selection: StringName = &"neutral"
@export var unlocked_content: Array[StringName] = []
@export var allocated_stats: Dictionary = {}
@export var inventory: Array[Dictionary] = []
@export var equipped: Dictionary = {}
@export var loadout_presets: Dictionary = {}
@export var weapon_levels: Dictionary = {}
@export var spell_levels: Dictionary = {}
@export var skill_trees: Dictionary = {}
@export var claimed_reward_ids: Array[StringName] = []
@export var story_state: Dictionary = {}
@export var codex_unlocks: Array[StringName] = []
@export var unlocked_pilot_ids: Array[StringName] = []
@export var selected_pilot_id: StringName
var _next_item_sequence := 1
var retained_unknown_data: Dictionary = {}

func add_experience(amount: int) -> Dictionary:
	var result := {"levels_gained": 0, "stat_points_gained": 0, "skill_points_gained": 0}
	if amount <= 0 or level >= ExperienceCurve.MAX_LEVEL: return result
	current_experience += amount
	while level < ExperienceCurve.MAX_LEVEL:
		var needed := ExperienceCurve.xp_to_next(level)
		if current_experience < needed: break
		current_experience -= needed
		level += 1
		statistic_points += 2
		skill_points += 1
		result.levels_gained += 1
		result.stat_points_gained += 2
		result.skill_points_gained += 1
	if level >= ExperienceCurve.MAX_LEVEL: current_experience = 0
	return result

func allocate_stat(stat: StringName, amount := 1) -> bool:
	if amount <= 0 or statistic_points < amount: return false
	var current := int(allocated_stats.get(stat, 0))
	if current + amount > MAX_STAT_RANK: return false
	allocated_stats[stat] = current + amount
	statistic_points -= amount
	return true

func upgrade_ability(content_id: StringName, is_spell: bool, cost: int) -> bool:
	if cost < 0 or currency < cost: return false
	var levels: Dictionary = spell_levels if is_spell else weapon_levels
	var current := int(levels.get(content_id, 1))
	if current >= MAX_ABILITY_LEVEL: return false
	currency -= cost
	levels[content_id] = current + 1
	return true

func unlock(content_id: StringName) -> void:
	if content_id not in unlocked_content: unlocked_content.append(content_id)

func next_item_instance_id() -> StringName:
	var result := StringName("item.%s.%d" % [profile_id, _next_item_sequence])
	_next_item_sequence += 1
	return result

func to_snapshot() -> Dictionary:
	var snapshot := retained_unknown_data.duplicate(true)
	snapshot.merge({"schema_version": 9, "profile_id": profile_id, "display_name": display_name,
		"playtime_seconds": playtime_seconds, "campaign_progress": campaign_progress.duplicate(true),
		"last_played_stage": last_played_stage, "new_game_plus_cycle": new_game_plus_cycle,
		"profile_settings": profile_settings.duplicate(true), "level": level, "current_experience": current_experience,
		"statistic_points": statistic_points, "skill_points": skill_points, "currency": currency,
		"narrative_selection": narrative_selection, "unlocked_content": unlocked_content.duplicate(),
		"allocated_stats": allocated_stats.duplicate(true), "inventory": inventory.duplicate(true), "equipped": equipped.duplicate(true),
		"loadout_presets": loadout_presets.duplicate(true), "weapon_levels": weapon_levels.duplicate(true),
		"spell_levels": spell_levels.duplicate(true), "skill_trees": skill_trees.duplicate(true),
		"claimed_reward_ids": claimed_reward_ids.duplicate(), "story_state": story_state.duplicate(true),
		"codex_unlocks": codex_unlocks.duplicate(), "unlocked_pilot_ids": unlocked_pilot_ids.duplicate(), "selected_pilot_id": selected_pilot_id,
		"next_item_sequence": _next_item_sequence}, true)
	return snapshot

static func from_snapshot(data: Dictionary) -> ProgressionProfile:
	var profile := ProgressionProfile.new()
	profile.profile_id = StringName(data.get("profile_id", "profile.local_1")); profile.display_name = String(data.get("display_name", "Pilot"))
	profile.playtime_seconds = maxi(0, int(data.get("playtime_seconds", 0))); profile.campaign_progress = data.get("campaign_progress", {}).duplicate(true)
	profile.last_played_stage = StringName(data.get("last_played_stage", "")); profile.new_game_plus_cycle = maxi(0, int(data.get("new_game_plus_cycle", 0)))
	profile.profile_settings = data.get("profile_settings", {}).duplicate(true); profile.level = clampi(int(data.get("level", 1)), 1, 99)
	profile.current_experience = maxi(0, int(data.get("current_experience", 0))); profile.statistic_points = maxi(0, int(data.get("statistic_points", 0)))
	profile.skill_points = maxi(0, int(data.get("skill_points", 0))); profile.currency = maxi(0, int(data.get("currency", 0)))
	profile.narrative_selection = StringName(data.get("narrative_selection", "neutral")); profile.unlocked_content.assign(data.get("unlocked_content", []))
	profile.allocated_stats = data.get("allocated_stats", {}).duplicate(true); profile.inventory.assign(data.get("inventory", [])); profile.equipped = data.get("equipped", {}).duplicate(true)
	profile.loadout_presets = data.get("loadout_presets", {}).duplicate(true); profile.weapon_levels = data.get("weapon_levels", {}).duplicate(true)
	profile.spell_levels = data.get("spell_levels", {}).duplicate(true); profile.skill_trees = data.get("skill_trees", {}).duplicate(true)
	profile.claimed_reward_ids.assign(data.get("claimed_reward_ids", [])); profile._next_item_sequence = maxi(1, int(data.get("next_item_sequence", 1)))
	profile.story_state = data.get("story_state", {}).duplicate(true); profile.codex_unlocks.assign(data.get("codex_unlocks", []))
	profile.unlocked_pilot_ids.assign(data.get("unlocked_pilot_ids", [])); profile.selected_pilot_id = StringName(data.get("selected_pilot_id", ""))
	profile.retained_unknown_data = data.duplicate(true)
	for known in ["schema_version", "profile_id", "display_name", "playtime_seconds", "campaign_progress", "last_played_stage", "new_game_plus_cycle", "profile_settings", "level", "current_experience", "statistic_points", "skill_points", "currency", "narrative_selection", "unlocked_content", "allocated_stats", "inventory", "equipped", "loadout_presets", "weapon_levels", "spell_levels", "skill_trees", "claimed_reward_ids", "story_state", "codex_unlocks", "unlocked_pilot_ids", "selected_pilot_id", "next_item_sequence"]:
		profile.retained_unknown_data.erase(known)
	return profile
