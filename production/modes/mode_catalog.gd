class_name ModeCatalog
extends RefCounted

static func all() -> Dictionary:
	var result := {}
	for definition in [_arcade(), _score_attack(), _boss_rush(), _boss_practice(), _survival(false), _survival(true), _time_attack(), _challenge(false), _challenge(true), _mutator(), _training()]:
		result[definition.mode_id] = definition
	return result

static func get_mode(mode_id: StringName) -> ModeDefinition:
	return all().get(mode_id)

static func _arcade() -> ModeDefinition:
	var mode := ModeDefinition.new(&"arcade", "Arcade")
	mode.allowed_loadouts = &"fixed_or_selected"; mode.continue_limit = 2
	mode.multiplayer_allowed = true; mode.rewards_enabled = true
	mode.rules = {"stage_sequence": true, "chain_emphasis": true, "earned_continue_score": 250000}
	return mode

static func _score_attack() -> ModeDefinition:
	var mode := ModeDefinition.new(&"score_attack", "Score Attack")
	mode.allowed_loadouts = &"standardized_optional"; mode.starting_lives = 1
	mode.stage_selection = &"single_stage_or_route"; mode.seed_policy = &"player"
	mode.rules = {"timer": true, "score_breakdown": true, "quick_restart": true, "record_assists": true}
	return mode

static func _boss_rush() -> ModeDefinition:
	var mode := ModeDefinition.new(&"boss_rush", "Boss Rush")
	mode.starting_lives = 3; mode.multiplayer_allowed = true; mode.stage_selection = &"unlocked_bosses"
	mode.rules = {"recovery_between_bosses": 0.35, "score": true, "timer": true}
	return mode

static func _boss_practice() -> ModeDefinition:
	var mode := ModeDefinition.new(&"boss_practice", "Boss Practice")
	mode.progression_source = &"none"; mode.starting_lives = 0; mode.continue_limit = -1
	mode.score_enabled = false; mode.rewards_enabled = false; mode.leaderboard_eligible = false
	mode.stage_selection = &"unlocked_bosses"; mode.difficulty_policy = &"unrestricted"; mode.seed_policy = &"fixed"; mode.multiplayer_allowed = true
	mode.rules = {"practice": true, "recovery_between_bosses": 1.0}
	return mode

static func _survival(endless: bool) -> ModeDefinition:
	var id: StringName = &"endless" if endless else &"survival"
	var mode := ModeDefinition.new(id, "Endless" if endless else "Survival")
	mode.starting_lives = 1; mode.seed_policy = &"player"; mode.stage_selection = &"generated"
	mode.rules = {"endless": endless, "survival_segments": 12, "difficulty_per_segment": 3, "wave_scaling": 0.08, "segment_scaling": 0.12, "difficulty_cap": 3.0, "maximum_active_enemies": 96, "maximum_active_projectiles": 1800}
	return mode

static func _time_attack() -> ModeDefinition:
	var mode := ModeDefinition.new(&"time_attack", "Time Attack")
	mode.allowed_loadouts = &"standardized_or_player"; mode.checkpoints_enabled = false
	mode.rules = {"timer": true, "death_penalty_seconds": 10.0, "boss_split_timing": true}
	return mode

static func _challenge(weekly: bool) -> ModeDefinition:
	var id: StringName = &"weekly_challenge" if weekly else &"daily_challenge"
	var mode := ModeDefinition.new(id, "Weekly Challenge" if weekly else "Daily Challenge")
	mode.allowed_loadouts = &"standardized"; mode.starting_lives = 1; mode.continue_limit = 0
	mode.seed_policy = &"weekly" if weekly else &"daily"; mode.stage_selection = &"challenge"; mode.multiplayer_allowed = true
	mode.rules = {"challenge_period": &"weekly" if weekly else &"daily", "record_assists": true}
	return mode

static func _mutator() -> ModeDefinition:
	var mode := ModeDefinition.new(&"mutator", "Mutator Run")
	mode.allowed_loadouts = &"player"; mode.seed_policy = &"player"; mode.stage_selection = &"single_stage"; mode.multiplayer_allowed = true
	mode.rules = {"selectable_mutators": [&"aggressive_enemies", &"fragile_shields", &"dense_formations", &"limited_spells", &"accelerated_projectiles"]}
	return mode

static func _training() -> ModeDefinition:
	var mode := ModeDefinition.new(&"training", "Training")
	mode.progression_source = &"none"; mode.starting_lives = 0; mode.continue_limit = -1
	mode.score_enabled = false; mode.rewards_enabled = false; mode.leaderboard_eligible = false
	mode.stage_selection = &"practice"; mode.difficulty_policy = &"unrestricted"; mode.seed_policy = &"fixed"
	return mode
