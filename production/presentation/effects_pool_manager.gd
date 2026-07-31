class_name EffectsPoolManager
extends Node

const IMPORTANCE := {&"critical": 3, &"gameplay": 2, &"decorative": 1}
var maximum_active := 200
var category_budgets := {&"explosion": 40, &"impact": 70, &"shield_impact": 20, &"debris": 20, &"smoke": 20, &"trail": 20, &"damage_number": 20, &"spell": 24}
var active: Array[Node2D] = []
var free: Array[Node2D] = []

func spawn_effect(category: StringName, importance: StringName = &"decorative", at := Vector2.ZERO) -> Node2D:
	_prune()
	var count := active.filter(func(node): return node.get_meta(&"category", &"") == category).size()
	if active.size() >= maximum_active or count >= int(category_budgets.get(category, 12)):
		if IMPORTANCE.get(importance, 1) <= 1: return null
		_reclaim_lowest()
	var effect: Node2D = free.pop_back() if not free.is_empty() else Node2D.new()
	effect.position = at; effect.visible = true; effect.set_meta(&"category", category); effect.set_meta(&"importance", IMPORTANCE.get(importance, 1)); add_child(effect); active.append(effect)
	return effect

func release_effect(effect: Node2D) -> void:
	if not active.has(effect): return
	active.erase(effect); remove_child(effect); effect.visible = false; free.append(effect)

func _prune() -> void: active = active.filter(func(node): return is_instance_valid(node))

func _reclaim_lowest() -> void:
	for effect in active:
		if int(effect.get_meta(&"importance", 1)) <= 1: release_effect(effect); return
