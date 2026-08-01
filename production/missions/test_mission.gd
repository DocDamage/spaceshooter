class_name ProductionTestMission
extends Node2D

var session: GameSession
var database: ContentDatabase
var projectile_sequence := 0
var projectile_pool: ProjectilePoolManager

func configure(game_session: GameSession, content_database: ContentDatabase) -> void:
	session = game_session
	database = content_database

func _ready() -> void:
	if session == null or database == null:
		push_error("ProductionTestMission must be configured before activation")
		return
	session.current_segment = 1
	session.active_waves = 1
	projectile_pool = ProjectilePoolManager.new()
	projectile_pool.name = "ProjectilePoolManager"
	add_child(projectile_pool)
	projectile_pool.prewarm(&"player_bullet", 64)
	_spawn_players()
	_spawn_enemies()
	queue_redraw()

func _spawn_players() -> void:
	var ship := database.get_definition(session.config.selected_ships[0], &"ship") as ShipDefinition
	var weapon := database.get_definition(ship.default_weapon_id, &"weapon") as WeaponDefinition
	var local_players: int = session.config.effective_player_count()
	for player_index in local_players:
		var player := ProductionPlayer.new()
		player.configure(StringName("player.local_%d" % (player_index + 1)), player_index, ship, weapon, session.actor_registry, session.event_bus, session.services.input)
		player.position = Vector2(270.0 + (player_index * 60.0), 820.0)
		add_child(player)
		player.configure_combat(projectile_pool, [weapon])

func _spawn_enemies() -> void:
	var index := 0
	for enemy_content_id in session.config.mission_definition.enemy_ids:
		var definition := database.get_definition(enemy_content_id, &"enemy") as EnemyDefinition
		var enemy := ProductionEnemy.new()
		enemy.configure(StringName("enemy.wave_1.%d" % index), definition, session.actor_registry, session.event_bus)
		enemy.position = Vector2(150.0 + index * 120.0, 145.0 + (index % 2) * 70.0)
		enemy.defeated.connect(session.register_defeat)
		add_child(enemy)
		index += 1

func spawn_projectile(player: ProductionPlayer) -> void:
	# Legacy fallback retained for callers that have not attached WeaponRuntime yet.
	projectile_sequence += 1
	projectile_pool.acquire(&"player_bullet", {"actor_id": StringName("projectile.%s.%d" % [player.actor_id, projectile_sequence]), "source_id": player.actor_id, "source_player_id": player.actor_id, "source_ability_id": player.weapon_definition.stable_id, "damage": player.weapon_definition.damage, "speed": player.weapon_definition.projectile_speed, "team": player.faction, "direction": Vector2.UP, "registry": session.actor_registry, "event_bus": session.event_bus}, Transform2D(0.0, player.position + Vector2(0, -24)))

func _draw() -> void:
	draw_rect(Rect2(0, 0, 540, 960), Color("071328"))
	for index in range(70):
		var star := Vector2(float((index * 97) % 532 + 4), float((index * 173) % 940 + 10))
		draw_circle(star, 1.0 + float(index % 3) * 0.45, Color(0.6, 0.78, 1.0, 0.6))
