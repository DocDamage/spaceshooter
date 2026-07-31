class_name StageValidator
extends RefCounted

static func validate(plan: StagePlan, mission: MissionDefinition, local_players := 1) -> Dictionary:
	var report := {"errors": PackedStringArray(), "warnings": PackedStringArray(), "information": PackedStringArray(), "valid": false}
	if plan == null or mission == null or mission.recipe == null:
		report.errors.append("A generated plan, mission, and recipe are required")
		return report
	if plan.nodes.is_empty() or plan.main_route.is_empty(): report.errors.append("Stage graph is empty")
	var ids := {}
	for node in plan.nodes:
		var node_id := StringName(node.get("node_id", ""))
		if node_id.is_empty() or ids.has(node_id): report.errors.append("Stage graph contains an empty or duplicate node ID")
		ids[node_id] = node
		var definition := plan.definition_for(node_id)
		if definition == null:
			report.errors.append("%s has no loaded segment definition" % node_id)
		else:
			report.errors.append_array(definition.validate_definition())
			if local_players > 1 and not _supports_local_players(definition, local_players): report.errors.append("%s cannot safely spawn %d local players" % [definition.stable_id, local_players])
	for node in plan.nodes:
		for next_id in node.get("next_ids", []):
			if not ids.has(next_id): report.errors.append("%s points to missing node %s" % [node.node_id, next_id])
			else:
				var first := plan.definition_for(StringName(node.node_id))
				var second := plan.definition_for(StringName(next_id))
				if first != null and second != null and not first.connects_to(second): report.errors.append("Connector mismatch: %s -> %s" % [first.stable_id, second.stable_id])
	_validate_main_route(plan, mission, report)
	_validate_reachability(plan, mission, report)
	report.information.append("%d nodes; estimated peak projectile budget %d" % [plan.nodes.size(), _projectile_peak(plan)])
	report.valid = report.errors.is_empty()
	return report

static func _validate_main_route(plan: StagePlan, mission: MissionDefinition, report: Dictionary) -> void:
	var recipe := mission.recipe
	var categories := PackedStringArray()
	var checkpoints := PackedStringArray()
	for node_id in plan.main_route:
		var node := plan.node_for(node_id)
		categories.append(String(node.get("category", "")))
		var checkpoint := StringName(node.get("checkpoint_kind", "none"))
		if checkpoint != &"none": checkpoints.append(String(checkpoint))
	if categories.is_empty() or categories[0] != "opening": report.errors.append("Main route must begin with an opening segment")
	var required_encounter := "boss" if not mission.boss_id.is_empty() else "miniboss"
	if required_encounter not in categories: report.errors.append("Main route does not reach its required %s encounter" % required_encounter)
	if categories[categories.size() - 1] != "exit": report.errors.append("Main route must end at an exit")
	var cursor := 0
	for required in recipe.required_checkpoint_order:
		var found := checkpoints.find(String(required), cursor)
		if found < 0: report.errors.append("Required checkpoint is missing or out of order: %s" % required)
		else: cursor = found + 1

static func _validate_reachability(plan: StagePlan, mission: MissionDefinition, report: Dictionary) -> void:
	if plan.main_route.is_empty(): return
	var required_encounter := &"boss" if not mission.boss_id.is_empty() else &"miniboss"
	var stack: Array[Dictionary] = [{"id": plan.main_route[0], "seen_encounter": false}]
	var visited := {}
	while not stack.is_empty():
		var state: Dictionary = stack.pop_back()
		var node := plan.node_for(StringName(state.id))
		if node.is_empty(): continue
		var seen_encounter: bool = state.seen_encounter or StringName(node.get("category", "")) == required_encounter
		var visit_key := "%s:%s" % [state.id, seen_encounter]
		if visited.has(visit_key): continue
		visited[visit_key] = true
		var next_ids: Array = node.get("next_ids", [])
		if next_ids.is_empty():
			if not bool(node.get("can_terminate", false)) and (StringName(node.get("category", "")) != &"exit" or not seen_encounter): report.errors.append("Route terminates before %s and exit at %s" % [required_encounter, state.id])
			continue
		for next_id in next_ids: stack.append({"id": next_id, "seen_encounter": seen_encounter})

static func _supports_local_players(definition: StageSegmentDefinition, local_players: int) -> bool:
	if definition.safe_spawn_points.is_empty(): return false
	var spacing_required := float(local_players - 1) * 44.0 + 40.0
	return definition.multiplayer_clearance.size.x >= spacing_required and definition.multiplayer_clearance.has_point(definition.safe_spawn_points[0])

static func _projectile_peak(plan: StagePlan) -> int:
	var peak := 0
	for node in plan.nodes: peak = maxi(peak, int(node.get("estimated_projectiles", 0)))
	return peak
