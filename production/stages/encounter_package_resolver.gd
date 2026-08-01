class_name EncounterPackageResolver
extends RefCounted

## Produces a per-node encounter package without mutating the shared content library.
## The graph stays authored and stable while enemy identity/count vary deterministically.
const BASE_FORMATION := preload("res://production/content/data/formation/arrowhead.tres")

static func resolve(source: StageSegmentDefinition, mission: MissionDefinition, node_id: StringName, stage_seed: int, difficulty_rating: int, player_count: int) -> StageSegmentDefinition:
	if source == null: return null
	var resolved := source.duplicate(true) as StageSegmentDefinition
	if resolved == null or mission == null or mission.enemy_ids.is_empty(): return resolved
	resolved.stable_id = StringName("%s@%s" % [source.stable_id, node_id])
	var node_seed := stage_seed ^ hash(String(node_id)) ^ hash(String(source.stable_id))
	var roster := mission.enemy_ids.duplicate()
	var pressure_bonus := clampi(int(floor(float(difficulty_rating) / 35.0)) + maxi(0, player_count - 1), 0, 4)
	resolved.minimum_duration = maxf(resolved.minimum_duration, _minimum_duration(StringName(resolved.category)))
	var source_waves: Array[WaveDefinition] = []
	source_waves.assign(resolved.waves)
	var package_size := _package_size(StringName(resolved.category), difficulty_rating)
	if source_waves.is_empty() and package_size > 0:
		var seed_wave := WaveDefinition.new()
		seed_wave.stable_id = StringName("wave.%s.runtime" % resolved.category)
		seed_wave.display_name = "%s pressure wave" % resolved.display_name
		seed_wave.formation = BASE_FORMATION
		seed_wave.spawn_delay = 0.15
		seed_wave.timeout = 35.0
		seed_wave.reward_hooks = [{"category": &"score", "amount": 150}]
		source_waves.append(seed_wave)
	var rebuilt_waves: Array[WaveDefinition] = []
	for wave_index in package_size:
		var wave := source_waves[wave_index % source_waves.size()].duplicate(true) as WaveDefinition
		if wave == null: continue
		wave.stable_id = StringName("%s.%s.variant_%d" % [wave.stable_id, node_id, abs(node_seed + wave_index) % 997])
		wave.display_name = "%s %d" % [wave.display_name, wave_index + 1]
		wave.spawn_delay = maxf(0.08, wave.spawn_delay - float(pressure_bonus) * 0.01)
		if wave.formation != null:
			var formation := wave.formation.duplicate(true) as FormationDefinition
			var member_count := clampi(4 + (wave_index % 3) + maxi(0, player_count - 1) + (1 if difficulty_rating >= 75 else 0), 4, 8)
			formation.stable_id = StringName("%s.%s.%d" % [formation.stable_id, node_id, wave_index])
			formation.display_name = "%s / %s" % [formation.display_name, _pattern_name(wave_index + node_seed)]
			formation.slots = _formation_slots(member_count, wave_index + node_seed)
			formation.member_enemy_ids = _select_roster(roster, member_count, node_seed + wave_index * 37)
			formation.leader_slot = 0
			formation.ordered_kill_slots.clear()
			for slot in member_count: formation.ordered_kill_slots.push_front(slot)
			formation.escape_seconds = maxf(15.0, 17.0 + float(pressure_bonus) + float(wave_index % 2))
			formation.multiplayer_spacing = 12.0
			wave.formation = formation
		elif not wave.enemy_ids.is_empty():
			var count := wave.enemy_ids.size() + mini(pressure_bonus, 2)
			wave.enemy_ids = _select_roster(roster, count, node_seed + wave_index * 37)
		wave.reward_hooks = wave.reward_hooks.duplicate(true)
		wave.reward_hooks.append({"category": &"score", "amount": 100 + wave_index * 25 + pressure_bonus * 25})
		rebuilt_waves.append(wave)
	resolved.waves = rebuilt_waves
	var rebuilt_objectives: Array[ObjectiveDefinition] = []
	for source_objective in resolved.objectives:
		if source_objective == null: continue
		var objective := source_objective.duplicate(true) as ObjectiveDefinition
		objective.stable_id = StringName("%s@%s" % [source_objective.stable_id, node_id])
		rebuilt_objectives.append(objective)
	resolved.objectives = rebuilt_objectives
	return resolved

static func _package_size(category: StringName, difficulty_rating: int) -> int:
	var base := 0
	match category:
		&"standard_combat", &"formation_combat": base = 3
		&"elite_encounter": base = 4
		&"rescue", &"escort", &"sabotage", &"hazard_field", &"turret_corridor", &"asteroid_field", &"debris_field": base = 2
		&"pre_boss": base = 2
	return base + (1 if base > 0 and difficulty_rating >= 90 else 0)

static func _minimum_duration(category: StringName) -> float:
	match category:
		&"opening", &"exit": return 6.0
		&"branch", &"checkpoint": return 5.0
		&"standard_combat": return 35.0
		&"formation_combat": return 42.0
		&"rescue", &"escort", &"sabotage": return 32.0
		&"miniboss": return 25.0
		&"elite_encounter": return 50.0
		&"hazard_field", &"turret_corridor", &"asteroid_field", &"debris_field": return 32.0
		&"pre_boss": return 28.0
		&"boss": return 45.0
	return 0.0

static func _formation_slots(count: int, seed_value: int) -> Array[Vector2]:
	var slots: Array[Vector2] = []
	var pattern := posmod(seed_value, 4)
	for index in count:
		var centered := float(index) - float(count - 1) * 0.5
		match pattern:
			0:
				var row := int((index + 1) / 2)
				var side := 0.0 if index == 0 else (-1.0 if index % 2 == 1 else 1.0)
				slots.append(Vector2(side * row * 58.0, -row * 45.0))
			1: slots.append(Vector2(centered * 52.0, -absf(centered) * 12.0))
			2: slots.append(Vector2(centered * 46.0, -float(index) * 30.0))
			_: slots.append(Vector2(centered * 48.0, -80.0 + absf(centered) * 32.0))
	return slots

static func _pattern_name(seed_value: int) -> String:
	return ["arrowhead", "battle line", "echelon", "diamond"][posmod(seed_value, 4)]

static func _select_roster(roster: Array[StringName], count: int, seed_value: int) -> Array[StringName]:
	var selected: Array[StringName] = []
	if roster.is_empty(): return selected
	var start := posmod(seed_value, roster.size())
	var stride := 1 + posmod(seed_value / maxi(1, roster.size()), maxi(1, roster.size() - 1))
	for index in count:
		selected.append(roster[(start + index * stride) % roster.size()])
	return selected
