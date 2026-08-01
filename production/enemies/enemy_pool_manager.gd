class_name EnemyPoolManager
extends Node2D

signal enemy_defeated(enemy: ProductionEnemy, actor_id: StringName, credits: int)
signal enemy_rewards(enemy: ProductionEnemy, source_player_id: StringName, score: int, experience: int, drops: Array[Dictionary])
signal enemy_escaped(enemy: ProductionEnemy, actor_id: StringName)
signal enemy_fired(enemy: ProductionEnemy, pattern_id: StringName, projectile_count: int)
signal enemy_damaged(enemy: ProductionEnemy, packet: DamagePacket, result: DamageResult)

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
		enemy.defeated.connect(func(actor_id: StringName, credits: int): enemy_defeated.emit(enemy, actor_id, credits))
		enemy.rewards_attributed.connect(func(source_player_id: StringName, score: int, experience: int, drops: Array[Dictionary]): enemy_rewards.emit(enemy, source_player_id, score, experience, drops))
		enemy.escaped.connect(func(actor_id: StringName): enemy_escaped.emit(enemy, actor_id))
		enemy.attack_controller.pattern_fired.connect(func(pattern_id: StringName, projectile_count: int): enemy_fired.emit(enemy, pattern_id, projectile_count))
		enemy.damage_resolved.connect(func(packet: DamagePacket, result: DamageResult): enemy_damaged.emit(enemy, packet, result))
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
	enemy.source_player_ids.assign(configuration.get("source_player_ids", []))
	enemy.stage_seed = int(configuration.get("stage_seed", 0))
	enemy.attack_controller.player_count = maxi(1, int(configuration.get("player_count", 1)))
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

func active_enemies() -> Array[ProductionEnemy]:
	var result: Array[ProductionEnemy] = []
	for enemy in _active:
		if is_instance_valid(enemy) and enemy.active: result.append(enemy)
	return result

func _on_despawned(_id: StringName, enemy: ProductionEnemy) -> void:
	_active.erase(enemy)
	enemy.reset_for_pool()
	if enemy not in _available: _available.append(enemy)
