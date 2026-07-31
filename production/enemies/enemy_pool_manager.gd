class_name EnemyPoolManager
extends Node2D

var hard_limit := 200
var _available: Array[ProductionEnemy] = []
var _active: Array[ProductionEnemy] = []

func prewarm(count: int) -> int:
	var created := 0
	while _available.size() + _active.size() < mini(count, hard_limit):
		var enemy := ProductionEnemy.new()
		enemy.pooled = true
		enemy.visible = false
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(enemy)
		_available.append(enemy)
		created += 1
	return created

func acquire(configuration: Dictionary, spawn_position: Vector2) -> ProductionEnemy:
	if _available.is_empty():
		if _active.size() >= hard_limit: return null
		prewarm(_active.size() + 1)
	var enemy: ProductionEnemy = _available.pop_back()
	enemy.reset_for_pool()
	enemy.configure(configuration.actor_id, configuration.definition, configuration.registry, configuration.event_bus, configuration.get("target"), configuration.get("projectile_pool"), configuration.get("difficulty"), true)
	enemy.position = spawn_position
	enemy.despawned.connect(_on_despawned.bind(enemy), CONNECT_ONE_SHOT)
	if not enemy.spawn_actor():
		_available.append(enemy)
		return null
	_active.append(enemy)
	return enemy

func release_all() -> void:
	for enemy in _active.duplicate(): enemy.despawn_actor()

func active_count() -> int:
	return _active.size()

func _on_despawned(_id: StringName, enemy: ProductionEnemy) -> void:
	_active.erase(enemy)
	enemy.reset_for_pool()
	if enemy not in _available: _available.append(enemy)
