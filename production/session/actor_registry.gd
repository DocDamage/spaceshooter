class_name ActorRegistry
extends Node

signal actor_registered(actor_id: StringName, category: StringName, actor: Node)
signal actor_unregistered(actor_id: StringName, category: StringName)

const VALID_CATEGORIES := [&"player", &"wingman", &"enemy", &"miniboss", &"boss", &"projectile", &"pickup", &"hazard", &"objective"]

var _actors: Dictionary = {}
var _category_ids: Dictionary = {}

func register_actor(actor_id: StringName, category: StringName, actor: Node) -> bool:
	if actor_id.is_empty() or actor == null:
		push_error("Actor registration requires stable ID and node")
		return false
	if category not in VALID_CATEGORIES:
		push_error("Unknown actor category: %s" % category)
		return false
	if _actors.has(actor_id):
		push_error("Duplicate actor ID: %s" % actor_id)
		return false
	_actors[actor_id] = actor
	if not _category_ids.has(category):
		_category_ids[category] = []
	_category_ids[category].append(actor_id)
	var exit_callback := _on_actor_tree_exiting.bind(actor_id)
	if not actor.tree_exiting.is_connected(exit_callback):
		actor.tree_exiting.connect(exit_callback, CONNECT_ONE_SHOT)
	actor_registered.emit(actor_id, category, actor)
	return true

func unregister_actor(actor_id: StringName) -> void:
	if not _actors.has(actor_id):
		return
	var category := get_category(actor_id)
	_actors.erase(actor_id)
	if _category_ids.has(category):
		_category_ids[category].erase(actor_id)
	actor_unregistered.emit(actor_id, category)

func get_actor(actor_id: StringName) -> Node:
	var actor: Node = _actors.get(actor_id)
	return actor if is_instance_valid(actor) else null

func get_actors(category: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for actor_id in _category_ids.get(category, []):
		var actor := get_actor(actor_id)
		if actor != null:
			result.append(actor)
	return result

func get_category(actor_id: StringName) -> StringName:
	for category in _category_ids:
		if actor_id in _category_ids[category]:
			return category
	return &""

func get_count(category: StringName) -> int:
	return get_actors(category).size()

func get_counts() -> Dictionary:
	var counts := {}
	for category in VALID_CATEGORIES:
		counts[category] = get_count(category)
	return counts

func _on_actor_tree_exiting(actor_id: StringName) -> void:
	unregister_actor(actor_id)
