class_name StageGraphGenerator
extends RefCounted

func generate(mission: MissionDefinition, seed_value: int, difficulty := 50) -> StagePlan:
	if mission == null or mission.recipe == null: return null
	var recipe := mission.recipe
	if not recipe.validate_definition().is_empty() or difficulty < recipe.minimum_difficulty or difficulty > recipe.maximum_difficulty: return null
	if mission.encounter_timeline != null:
		return _generate_timeline(mission, seed_value, difficulty)
	var streams := SeededRandomStreams.new(seed_value)
	var selection := streams.stream(&"segment_selection")
	var sequence: Array[StageSegmentDefinition] = []
	sequence.assign(recipe.required_sequence)
	var counts := {}
	for segment in sequence: counts[segment.stable_id] = int(counts.get(segment.stable_id, 0)) + 1
	while sequence.size() < recipe.minimum_segment_count:
		var candidates: Array[StageSegmentDefinition] = []
		for segment in recipe.optional_pool:
			if segment != null and segment.supports_difficulty(difficulty) and int(counts.get(segment.stable_id, 0)) < recipe.repetition_limit:
				candidates.append(segment)
		if candidates.is_empty(): return null
		var picked := candidates[selection.randi_range(0, candidates.size() - 1)]
		var insertion := _compatible_insertion(sequence, picked, selection)
		if insertion < 0: return null
		sequence.insert(insertion, picked)
		counts[picked.stable_id] = int(counts.get(picked.stable_id, 0)) + 1
	if sequence.size() > recipe.maximum_segment_count: return null
	var plan := StagePlan.new()
	plan.mission_id = mission.stable_id
	plan.seed = seed_value
	plan.difficulty = difficulty
	var node_seed_stream := streams.stream(&"node_seeds")
	for index in sequence.size():
		var definition := sequence[index]
		var node_id := StringName("node.%02d.%s" % [index, definition.stable_id])
		var node := _node_data(node_id, definition, node_seed_stream.randi())
		plan.add_node(node, definition)
		plan.main_route.append(node_id)
	for index in plan.main_route.size() - 1:
		plan.nodes[index].next_ids.append(plan.main_route[index + 1])
	_add_branches(plan, recipe, streams.stream(&"branches"), node_seed_stream)
	plan.generation_notes.append("Generated %d nodes from deterministic seed %d" % [plan.nodes.size(), seed_value])
	return plan

func _generate_timeline(mission: MissionDefinition, seed_value: int, difficulty: int) -> StagePlan:
	var timeline := mission.encounter_timeline
	if timeline == null or not timeline.validate_definition().is_empty(): return null
	var plan := StagePlan.new()
	plan.mission_id = mission.stable_id
	plan.seed = seed_value
	plan.difficulty = difficulty
	var ids := {}
	var primary_index := 0
	var branch_index := 0
	for beat in timeline.beats:
		if beat == null or beat.segment == null: return null
		var node_id := StringName("node.%02d.%s" % [primary_index, beat.segment.stable_id]) if beat.primary_route else StringName("branch.%02d.%s" % [branch_index, beat.segment.stable_id])
		if beat.primary_route: primary_index += 1
		else: branch_index += 1
		if ids.has(beat.stable_id): return null
		ids[beat.stable_id] = node_id
		var node := _node_data(node_id, beat.segment, _timeline_node_seed(seed_value, beat.stable_id))
		var beat_snapshot := beat.snapshot(seed_value)
		for key in beat_snapshot: node[key] = beat_snapshot[key]
		node["timeline_id"] = timeline.stable_id
		plan.add_node(node, beat.segment)
	for beat in timeline.beats:
		var node := plan.node_for(ids[beat.stable_id])
		for next_beat_id in beat.next_beat_ids:
			node.next_ids.append(ids[next_beat_id])
	for beat in timeline.ordered_primary_beats(): plan.main_route.append(ids[beat.stable_id])
	plan.generation_notes.append("Authored timeline %s with %d beats and bounded seed variants" % [timeline.stable_id, timeline.beats.size()])
	return plan

func _timeline_node_seed(seed_value: int, beat_id: StringName) -> int:
	return seed_value ^ hash(String(beat_id))

func _compatible_insertion(sequence: Array[StageSegmentDefinition], candidate: StageSegmentDefinition, random: RandomNumberGenerator) -> int:
	var positions: Array[int] = []
	for index in range(1, sequence.size()):
		if sequence[index - 1].connects_to(candidate) and candidate.connects_to(sequence[index]): positions.append(index)
	if positions.is_empty(): return -1
	return positions[random.randi_range(0, positions.size() - 1)]

func _add_branches(plan: StagePlan, recipe: MissionRecipeDefinition, random: RandomNumberGenerator, node_seeds: RandomNumberGenerator) -> void:
	if recipe.branch_count <= 0: return
	var anchors: Array[int] = []
	for index in range(1, plan.main_route.size() - 2):
		var definition := plan.definition_for(plan.main_route[index])
		if definition != null and definition.category == "branch": anchors.append(index)
	if anchors.is_empty():
		for index in range(1, maxi(1, plan.main_route.size() - 3)): anchors.append(index)
	for branch_index in mini(recipe.branch_count, anchors.size()):
		var anchor_index := anchors[branch_index]
		var anchor_id := plan.main_route[anchor_index]
		var reconnect_id := plan.main_route[anchor_index + 1]
		var compatible: Array[StageSegmentDefinition] = []
		var anchor_definition := plan.definition_for(anchor_id)
		var reconnect_definition := plan.definition_for(reconnect_id)
		for candidate in recipe.branch_pool:
			if candidate != null and anchor_definition.connects_to(candidate) and (candidate.can_terminate_branch or candidate.connects_to(reconnect_definition)):
				compatible.append(candidate)
		if compatible.is_empty(): continue
		var definition := compatible[random.randi_range(0, compatible.size() - 1)]
		var node_id := StringName("branch.%02d.%s" % [branch_index, definition.stable_id])
		var node := _node_data(node_id, definition, node_seeds.randi())
		if not definition.can_terminate_branch: node.next_ids.append(reconnect_id)
		plan.add_node(node, definition)
		var anchor_node := plan.node_for(anchor_id)
		anchor_node.next_ids.append(node_id)

func _node_data(node_id: StringName, definition: StageSegmentDefinition, node_seed: int) -> Dictionary:
	var objective_ids: Array[StringName] = []
	for objective in definition.objectives: objective_ids.append(objective.stable_id)
	return {"node_id": node_id, "segment_id": definition.stable_id, "category": StringName(definition.category), "seed": node_seed, "next_ids": Array([], TYPE_STRING_NAME, &"", null), "checkpoint_kind": StringName(definition.checkpoint_kind), "safe_spawn": definition.safe_spawn_points[0] if not definition.safe_spawn_points.is_empty() else Vector2(270, 820), "objective_ids": objective_ids, "estimated_projectiles": definition.estimated_projectile_budget, "can_terminate": definition.can_terminate_branch}
