class_name SkillTreeManager
extends RefCounted

var profile: ProgressionProfile
var nodes: Dictionary = {}

func _init(owner_profile: ProgressionProfile, definitions: Array[SkillNodeDefinition] = []) -> void:
	profile = owner_profile
	for node in definitions:
		if node != null: nodes[node.stable_id] = node

func can_purchase(node_id: StringName) -> bool:
	var node: SkillNodeDefinition = nodes.get(node_id)
	if node == null or profile.level < node.required_level or profile.skill_points < node.cost: return false
	if not node.required_unlock.is_empty() and node.required_unlock not in profile.unlocked_content: return false
	if int(profile.skill_trees.get(node_id, 0)) >= node.maximum_rank: return false
	if not node.prerequisite_id.is_empty() and int(profile.skill_trees.get(node.prerequisite_id, 0)) < node.prerequisite_rank: return false
	if not node.exclusive_group.is_empty():
		for purchased_id in profile.skill_trees:
			var purchased: SkillNodeDefinition = nodes.get(purchased_id)
			if purchased != null and purchased.exclusive_group == node.exclusive_group and purchased_id != node_id and int(profile.skill_trees[purchased_id]) > 0: return false
	return true

func purchase(node_id: StringName) -> bool:
	if not can_purchase(node_id): return false
	var node: SkillNodeDefinition = nodes[node_id]
	profile.skill_points -= node.cost
	profile.skill_trees[node_id] = int(profile.skill_trees.get(node_id, 0)) + 1
	return true

func total_spent() -> int:
	var total := 0
	for node_id in profile.skill_trees:
		var node: SkillNodeDefinition = nodes.get(node_id)
		if node != null: total += int(profile.skill_trees[node_id]) * node.cost
	return total

func respec(confirmed: bool, training := false, fee := 0) -> Dictionary:
	if not confirmed: return {"success": false, "refund": 0}
	if not training and (fee < 0 or profile.currency < fee): return {"success": false, "refund": 0}
	var refund := total_spent()
	var snapshot := profile.to_snapshot()
	if not training: profile.currency -= fee
	profile.skill_points += refund
	profile.skill_trees.clear()
	if profile.skill_points < 0:
		var restored := ProgressionProfile.from_snapshot(snapshot)
		profile.skill_points = restored.skill_points; profile.currency = restored.currency; profile.skill_trees = restored.skill_trees
		return {"success": false, "refund": 0}
	return {"success": true, "refund": refund, "loadouts_require_refresh": true}

func respec_and_save(confirmed: bool, save_service: SaveService, training := false, fee := 0, path := "user://profile_v8.json") -> Dictionary:
	if save_service == null: return {"success": false, "refund": 0}
	var before := profile.to_snapshot()
	var result := respec(confirmed, training, fee)
	if not result.success: return result
	var error := save_service.save_snapshot_atomic(profile.to_snapshot(), path)
	if error != OK:
		profile.skill_points = int(before.skill_points); profile.currency = int(before.currency); profile.skill_trees = before.skill_trees.duplicate(true)
		return {"success": false, "refund": 0, "error": error}
	return result

func effect_modifiers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node_id in profile.skill_trees:
		var node: SkillNodeDefinition = nodes.get(node_id)
		for rank in int(profile.skill_trees[node_id]):
			if node != null: result.append(node.effects)
	return result
