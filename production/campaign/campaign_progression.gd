class_name CampaignProgression
extends RefCounted

var nodes: Dictionary = {}
var completed: Dictionary = {}
var ranks: Dictionary = {}
var story_flags: Dictionary = {}
var decisions: Dictionary = {}
var boss_practice: Array[StringName] = []
var new_game_plus_cycle := 0

func configure(definitions: Array[CampaignNodeDefinition], state: Dictionary = {}) -> void:
	nodes.clear()
	for definition in definitions: nodes[definition.stable_id] = definition
	restore(state)

func node_state(node_id: StringName) -> StringName:
	var node: CampaignNodeDefinition = nodes.get(node_id)
	if node == null: return &"missing"
	if completed.has(node_id): return &"completed"
	if node.secret and not _requirements_match(node.prerequisite_flags): return &"secret"
	if not _requirements_match(node.prerequisite_flags) or not _requirements_match(node.decision_requirements): return &"locked"
	for prerequisite in node.prerequisite_node_ids:
		if not completed.has(prerequisite): return &"locked"
	if not node.new_game_plus_variant.is_empty() and new_game_plus_cycle < 1: return &"locked"
	return &"available"

func complete_stage(node_id: StringName, rank: StringName, decision_updates: Dictionary = {}, allow_decision_overwrite := false) -> bool:
	if node_state(node_id) not in [&"available", &"completed"]: return false
	completed[node_id] = true
	ranks[node_id] = rank
	for key in decision_updates:
		if not decisions.has(key) or allow_decision_overwrite: decisions[key] = decision_updates[key]
	var node: CampaignNodeDefinition = nodes[node_id]
	if node.boss_node and node_id not in boss_practice: boss_practice.append(node_id)
	for boss_id in node.practice_boss_ids:
		if boss_id not in boss_practice: boss_practice.append(boss_id)
	return true

func set_story_flag(flag: StringName, value: Variant = true) -> void:
	story_flags[flag] = value

func operation_unlocked(operation_index: int) -> bool:
	return nodes.values().any(func(node): return node.operation_index == operation_index and node_state(node.stable_id) != &"locked")

func snapshot() -> Dictionary:
	return {"completed": completed.duplicate(true), "ranks": ranks.duplicate(true), "story_flags": story_flags.duplicate(true), "decisions": decisions.duplicate(true), "boss_practice": boss_practice.duplicate(), "new_game_plus_cycle": new_game_plus_cycle}

func restore(state: Dictionary) -> void:
	completed = state.get("completed", {}).duplicate(true); ranks = state.get("ranks", {}).duplicate(true)
	story_flags = state.get("story_flags", {}).duplicate(true); decisions = state.get("decisions", {}).duplicate(true)
	boss_practice.assign(state.get("boss_practice", [])); new_game_plus_cycle = maxi(0, int(state.get("new_game_plus_cycle", new_game_plus_cycle)))

func _requirements_match(requirements: Dictionary) -> bool:
	for key in requirements:
		var source := decisions if decisions.has(key) else story_flags
		if source.get(key) != requirements[key]: return false
	return true
