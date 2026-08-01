class_name BulletConversionService
extends Node

signal flux_created(source_id: StringName, count: int)
signal flux_collected(player_id: StringName, value: int)

var pool: ProjectilePoolManager
var players: Array[Node2D] = []
var score_tracker: MissionScoreTracker
var sequence := 0

func configure(pool_manager: ProjectilePoolManager, tracker: MissionScoreTracker, participant_nodes: Array[Node2D] = []) -> void:
	pool = pool_manager
	score_tracker = tracker
	players.assign(participant_nodes)

func set_players(participant_nodes: Array[Node2D]) -> void:
	players.assign(participant_nodes)

func convert_projectiles(projectiles: Array[ProductionProjectile], source_id: StringName, radius := INF) -> int:
	var converted := 0
	for projectile in projectiles:
		if projectile == null or not projectile.can_convert() or projectile.global_position.distance_to(_source_position(source_id)) > radius: continue
		var position := projectile.global_position
		var velocity := projectile.velocity
		var value := projectile.flux_value()
		projectile.convert_to_flux()
		_spawn_flux(position, velocity, source_id, value)
		converted += 1
	if converted > 0: flux_created.emit(source_id, converted)
	return converted

func convert_active(source_id: StringName, radius := INF) -> int:
	if pool == null: return 0
	var bullets: Array[ProductionProjectile] = []
	for category in [&"enemy_bullet", &"missile", &"mine"]:
		for object in pool.get_active_objects(category):
			if object is ProductionProjectile: bullets.append(object)
	return convert_projectiles(bullets, source_id, radius)

func convert_near(center: Vector2, source_id: StringName, radius := 260.0) -> int:
	if pool == null: return 0
	var bullets: Array[ProductionProjectile] = []
	for category in [&"enemy_bullet", &"missile", &"mine"]:
		for object in pool.get_active_objects(category):
			if object is ProductionProjectile and object.global_position.distance_to(center) <= radius: bullets.append(object)
	var converted := 0
	for projectile in bullets:
		var position := projectile.global_position; var velocity := projectile.velocity; var value := projectile.flux_value()
		if projectile.can_convert(): projectile.convert_to_flux(); _spawn_flux(position, velocity, source_id, value); converted += 1
	if converted > 0: flux_created.emit(source_id, converted)
	return converted

func _spawn_flux(position: Vector2, velocity: Vector2, source_id: StringName, value: int) -> void:
	if pool == null: return
	sequence += 1
	var pickup := pool.acquire(&"pickup", {&"actor_id": StringName("flux.%d" % sequence), &"drop": {&"category": &"flux", &"amount": value, &"owner_id": source_id}, &"players": players, &"initial_velocity": velocity, &"registry": null}, Transform2D(0.0, position)) as ProductionPickup
	if pickup != null: pickup.collected.connect(_on_flux_collected, CONNECT_ONE_SHOT)

func _on_flux_collected(drop: Dictionary, player_id: StringName) -> void:
	var value := maxi(1, int(drop.get(&"amount", 1)))
	if score_tracker != null: score_tracker.record_flux(player_id, value)
	for player in players:
		if player is ProductionPlayer and player.actor_id == player_id and player.spell_runtime != null: player.spell_runtime.add_energy(value * 2.0)
	flux_collected.emit(player_id, value)

func _source_position(source_id: StringName) -> Vector2:
	for player in players:
		if player is ProductionPlayer and player.actor_id == source_id: return player.global_position
	return Vector2.ZERO
