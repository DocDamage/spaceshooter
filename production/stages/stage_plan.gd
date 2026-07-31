class_name StagePlan
extends RefCounted

var mission_id: StringName
var seed := 0
var difficulty := 50
var nodes: Array[Dictionary] = []
var main_route: Array[StringName] = []
var generation_notes := PackedStringArray()
var _definitions: Dictionary = {}

func add_node(node: Dictionary, definition: StageSegmentDefinition) -> void:
	nodes.append(node)
	_definitions[StringName(node.node_id)] = definition

func definition_for(node_id: StringName) -> StageSegmentDefinition:
	return _definitions.get(node_id)

func node_for(node_id: StringName) -> Dictionary:
	for node in nodes:
		if StringName(node.get("node_id", "")) == node_id: return node
	return {}

func checkpoint_nodes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in nodes:
		if StringName(node.get("checkpoint_kind", "none")) != &"none": result.append(node)
	return result

func to_snapshot() -> Dictionary:
	return {"mission_id": mission_id, "seed": seed, "difficulty": difficulty, "nodes": nodes.duplicate(true), "main_route": main_route.duplicate(), "generation_notes": generation_notes.duplicate()}

static func from_snapshot(data: Dictionary, database: ContentDatabase = null) -> StagePlan:
	var plan := StagePlan.new()
	plan.mission_id = StringName(data.get("mission_id", ""))
	plan.seed = int(data.get("seed", 0))
	plan.difficulty = int(data.get("difficulty", 50))
	plan.nodes.assign(data.get("nodes", []))
	plan.main_route.assign(data.get("main_route", []))
	plan.generation_notes = PackedStringArray(data.get("generation_notes", []))
	if database != null:
		for node in plan.nodes:
			var definition := database.get_definition(StringName(node.get("segment_id", "")), &"stage_segment") as StageSegmentDefinition
			if definition != null: plan._definitions[StringName(node.node_id)] = definition
	return plan

func fingerprint() -> String:
	return JSON.stringify(to_snapshot()).sha256_text()
