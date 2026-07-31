class_name ModeStagePlanAdapter
extends RefCounted

static func adapt(source: StagePlan, mode_id: StringName) -> StagePlan:
	if source == null or mode_id not in [&"boss_practice", &"boss_rush", &"survival", &"endless", &"training"]: return source
	var categories: Array[StringName] = []
	match mode_id:
		&"boss_practice": categories = [&"boss"]
		&"boss_rush": categories = [&"miniboss", &"boss"]
		&"survival", &"endless": categories = [&"standard_combat", &"formation_combat", &"elite_encounter", &"hazard_field", &"survival"]
		&"training": categories = [&"standard_combat", &"formation_combat"]
	var selected: Array[StringName] = []
	for node_id in source.main_route:
		var category := StringName(source.node_for(node_id).get("category", ""))
		if category in categories: selected.append(node_id)
	if mode_id in [&"boss_practice", &"training"] and selected.size() > 1: selected = [selected[-1] if mode_id == &"boss_practice" else selected[0]]
	if selected.is_empty(): return source
	var result := StagePlan.new()
	result.mission_id = source.mission_id; result.seed = source.seed; result.difficulty = source.difficulty
	result.generation_notes = source.generation_notes.duplicate(); result.generation_notes.append("Mode adapter: %s" % mode_id)
	for index in selected.size():
		var node_id := selected[index]
		var node := source.node_for(node_id).duplicate(true)
		node.next_ids = [selected[index + 1]] if index + 1 < selected.size() else []
		node.can_terminate = index + 1 == selected.size()
		result.add_node(node, source.definition_for(node_id))
		result.main_route.append(node_id)
	return result
