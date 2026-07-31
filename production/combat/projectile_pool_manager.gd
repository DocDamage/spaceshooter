class_name ProjectilePoolManager
extends Node2D

const CATEGORIES := [&"player_bullet", &"enemy_bullet", &"missile", &"mine", &"pickup", &"impact", &"explosion", &"damage_popup"]

var initial_capacity := 32
var hard_limit_per_category := 2500
var _available: Dictionary = {}
var _active: Dictionary = {}
var _factories: Dictionary = {}
var _sequence := 0

func _ready() -> void:
	for category in CATEGORIES:
		_ensure_category(category)

func register_factory(category: StringName, factory: Callable) -> bool:
	if category not in CATEGORIES or not factory.is_valid():
		return false
	_factories[category] = factory
	_ensure_category(category)
	return true

func prewarm(category: StringName, count: int) -> int:
	if category not in CATEGORIES:
		return 0
	_ensure_category(category)
	var created := 0
	for index in range(maxi(0, count - get_total_count(category))):
		if _create_object(category) != null:
			created += 1
	return created

func acquire(category: StringName, configuration: Dictionary = {}, spawn_transform := Transform2D.IDENTITY) -> PooledCombatObject:
	if category not in CATEGORIES:
		push_error("Unknown pool category: %s" % category)
		return null
	_ensure_category(category)
	var object: PooledCombatObject
	if _available[category].is_empty():
		if get_total_count(category) >= hard_limit_per_category:
			return null
		object = _create_object(category)
		_available[category].erase(object)
	else:
		object = _available[category].pop_back()
	if object == null:
		return null
	object.configure_pool_object(category, configuration)
	if object.has_method("configure_from_pool"):
		object.configure_from_pool(configuration)
	if not object.activate_from_pool(spawn_transform):
		return null
	_active[category].append(object)
	return object

func release(object: PooledCombatObject) -> bool:
	if object == null or object.pool_category not in CATEGORIES or not object.pool_active:
		return false
	object.deactivate_to_pool()
	return true

func release_all(category: StringName = &"") -> void:
	var categories: Array = CATEGORIES if category.is_empty() else [category]
	for selected in categories:
		for object in _active.get(selected, []).duplicate():
			if is_instance_valid(object):
				object.deactivate_to_pool()

func get_active_count(category: StringName = &"") -> int:
	if not category.is_empty():
		return _active.get(category, []).size()
	var total := 0
	for selected in CATEGORIES:
		total += _active.get(selected, []).size()
	return total

func get_total_count(category: StringName) -> int:
	return _active.get(category, []).size() + _available.get(category, []).size()

func validate_inactive_objects() -> PackedStringArray:
	var errors := PackedStringArray()
	for category in CATEGORIES:
		for object in _available.get(category, []):
			for message in object.validate_reset():
				errors.append("%s: %s" % [category, message])
	return errors

func _ensure_category(category: StringName) -> void:
	if not _available.has(category):
		_available[category] = []
		_active[category] = []

func _create_object(category: StringName) -> PooledCombatObject:
	var object: PooledCombatObject
	if _factories.has(category):
		object = _factories[category].call() as PooledCombatObject
	elif category in [&"player_bullet", &"enemy_bullet", &"missile", &"mine"]:
		object = ProductionProjectile.new()
	else:
		object = PooledCombatObject.new()
	if object == null:
		return null
	_sequence += 1
	object.name = "Pooled_%s_%d" % [category, _sequence]
	object.configure_pool_object(category)
	object.visible = false
	object.monitoring = false
	object.monitorable = false
	object.process_mode = Node.PROCESS_MODE_DISABLED
	object.returned_to_pool.connect(_on_returned_to_pool)
	add_child(object)
	_available[category].append(object)
	return object

func _on_returned_to_pool(object: PooledCombatObject) -> void:
	var category := object.pool_category
	_active.get(category, []).erase(object)
	if object not in _available.get(category, []):
		_available[category].append(object)
