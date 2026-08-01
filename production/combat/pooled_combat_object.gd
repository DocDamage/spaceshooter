class_name PooledCombatObject
extends Area2D

signal returned_to_pool(object: PooledCombatObject)

var pool_category: StringName
var pool_active := false
var pool_generation := 0
var _configured := false

func configure_pool_object(category: StringName, configuration: Dictionary = {}) -> void:
	pool_category = category
	_configured = not category.is_empty()

func activate_from_pool(spawn_transform := Transform2D.IDENTITY) -> bool:
	if not _configured or pool_active:
		return false
	pool_active = true
	pool_generation += 1
	transform = spawn_transform
	visible = true
	monitoring = true
	monitorable = true
	process_mode = Node.PROCESS_MODE_INHERIT
	return true

func reset_pool_object() -> void:
	position = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE

func deactivate_to_pool() -> void:
	if not pool_active:
		return
	pool_active = false
	monitoring = false
	monitorable = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	reset_pool_object()
	returned_to_pool.emit(self)

func validate_reset() -> PackedStringArray:
	var errors := PackedStringArray()
	if pool_active:
		errors.append("object is still active")
	if visible or monitoring or monitorable:
		errors.append("inactive object remains visible or monitoring")
	if position != Vector2.ZERO or rotation != 0.0 or scale != Vector2.ONE or modulate != Color.WHITE:
		errors.append("transform or presentation state was not reset")
	return errors
