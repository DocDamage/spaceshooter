class_name CampaignMapModel
extends RefCounted

signal selection_changed(node_id: StringName)

var progression: CampaignProgression
var visible_node_ids: Array[StringName] = []
var selected_index := 0

func configure(campaign: CampaignProgression) -> void:
	progression = campaign
	refresh()

func refresh() -> void:
	visible_node_ids.clear()
	if progression == null: return
	var definitions: Array = progression.nodes.values()
	definitions.sort_custom(func(a, b): return a.operation_index < b.operation_index or (a.operation_index == b.operation_index and a.stage_index < b.stage_index))
	for node in definitions:
		if progression.node_state(node.stable_id) != &"secret": visible_node_ids.append(node.stable_id)
	selected_index = clampi(selected_index, 0, maxi(0, visible_node_ids.size() - 1))

func navigate(direction: int) -> StringName:
	if visible_node_ids.is_empty(): return &""
	selected_index = wrapi(selected_index + signi(direction), 0, visible_node_ids.size())
	selection_changed.emit(visible_node_ids[selected_index])
	return visible_node_ids[selected_index]

func selected_node() -> Dictionary:
	if progression == null or visible_node_ids.is_empty(): return {}
	var node_id := visible_node_ids[selected_index]
	var definition: CampaignNodeDefinition = progression.nodes[node_id]
	return {"node_id": node_id, "operation": definition.operation_index, "stage": definition.stage_index, "state": progression.node_state(node_id), "rank": progression.ranks.get(node_id, &""), "boss_practice": node_id in progression.boss_practice, "current_objective": definition.display_name, "reward_preview": definition.reward_preview.duplicate(true), "map_position": definition.map_position}
