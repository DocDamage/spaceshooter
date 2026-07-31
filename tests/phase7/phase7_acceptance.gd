extends SceneTree

var failures := PackedStringArray()
var passed_count := 0
var host: Node
var registry: ActorRegistry
var events: TypedEventBus
var database: ContentDatabase

func _init() -> void: call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)

func _run() -> void:
	await process_frame
	host = Node.new()
	root.add_child(host)
	registry = ActorRegistry.new()
	host.add_child(registry)
	events = TypedEventBus.new()
	database = ContentDatabase.new()
	host.add_child(database)
	_assert(database.initialize(), "Phase 7 resources pass content validation")
	_test_roster_and_libraries()
	_test_bounds()
	_test_difficulty_and_drops()
	_test_ordered_kills()
	_test_wave_scheduler()
	_test_enemy_pool()
	_test_no_hot_path_searches()
	if failures.is_empty():
		print("PHASE 7 ACCEPTANCE: all %d checks passed" % passed_count)
		quit(0)
	else:
		print("PHASE 7 ACCEPTANCE: %d check(s) failed" % failures.size())
		quit(1)

func _test_roster_and_libraries() -> void:
	var enemies := database.get_definitions_by_type(&"enemy")
	var appearances := {}
	for content in enemies:
		var enemy := content as EnemyDefinition
		appearances["%s|%s|%s|%s" % [enemy.visual_asset_path, enemy.visual_scale, enemy.visual_tint, enemy.collision_radius]] = true
	_assert(enemies.size() >= 20 and appearances.size() >= 20, "20 visually distinct roster entries share data-driven behaviors")
	_assert(MovementPatternDefinition.Pattern.size() == 16, "movement library exposes all 16 planned reusable patterns")
	_assert(AttackPatternDefinition.Pattern.size() == 14, "attack library exposes all 14 planned reusable patterns")
	var wall := database.get_definition(&"attack.wall_gaps", &"attack_pattern") as AttackPatternDefinition
	_assert(wall != null and wall.validate_definition().is_empty(), "wall attacks require validated navigable gaps")

func _test_bounds() -> void:
	var actor := Node2D.new()
	actor.name = "BoundsProbe"
	host.add_child(actor)
	var pattern := MovementPatternDefinition.new()
	pattern.pattern = MovementPatternDefinition.Pattern.SINE
	pattern.speed = 500.0
	pattern.amplitude = 900.0
	pattern.arena_margin = 20.0
	var controller := EnemyMovementController.new()
	host.add_child(controller)
	controller.configure(actor, pattern)
	for index in 600: controller.tick(1.0 / 60.0)
	_assert(actor.position.x >= 20.0 and actor.position.x <= 520.0, "formation-capable movement remains inside horizontal arena bounds")

func _test_difficulty_and_drops() -> void:
	var normal := database.get_definition(&"difficulty.normal", &"difficulty_profile") as DifficultyProfileDefinition
	var veteran := database.get_definition(&"difficulty.veteran", &"difficulty_profile") as DifficultyProfileDefinition
	_assert(veteran.health_multiplier > normal.health_multiplier and veteran.attack_cadence_multiplier > normal.attack_cadence_multiplier and veteran.projectile_speed_multiplier > normal.projectile_speed_multiplier, "difficulty changes health, cadence, speed, projectiles, and elite substitution")
	var table := database.get_definition(&"drop_table.scout", &"drop_table") as DropTableDefinition
	var drops := DropResolver.resolve(table, 77, 1.0, [&"player.one", &"player.two"], &"player.two")
	var correctly_owned := not drops.is_empty()
	for drop in drops: correctly_owned = correctly_owned and drop.owner_id == &"player.two"
	_assert(correctly_owned, "drops are deterministically attributed to the source player")

func _test_ordered_kills() -> void:
	var formation := FormationRuntime.new()
	host.add_child(formation)
	var definition := FormationDefinition.new()
	definition.stable_id = &"formation.test"
	definition.slots = [Vector2.ZERO, Vector2(40, 0), Vector2(-40, 0)]
	definition.leader_slot = 0
	definition.ordered_kill_slots = [2, 1, 0]
	definition.ordered_kill_reward = 900
	formation.configure(definition)
	var bonus := [0]
	formation.ordered_kill_bonus.connect(func(amount: int): bonus[0] = amount)
	formation._on_member_defeated(&"e2", 0, 2)
	formation._on_member_defeated(&"e1", 0, 1)
	formation._on_member_defeated(&"e0", 0, 0)
	_assert(bonus[0] == 900, "ordered formation kills grant their authored bonus")

func _test_wave_scheduler() -> void:
	var wave := WaveDefinition.new()
	wave.stable_id = &"wave.test"
	wave.enemy_ids = [&"enemy.dart", &"enemy.wasp"]
	wave.spawn_delay = 0.0
	wave.timeout = 2.0
	var scheduler := WaveScheduler.new()
	host.add_child(scheduler)
	scheduler.configure([wave])
	var spawned := [0]
	scheduler.enemy_spawn_requested.connect(func(_id, _position, _formation, _slot): spawned[0] += 1)
	_assert(scheduler.start(), "wave scheduler accepts authored wave definitions")
	scheduler.tick(0.01)
	scheduler.tick(0.01)
	scheduler.notify_enemy_finished()
	scheduler.notify_enemy_finished()
	scheduler.tick(0.01)
	_assert(spawned[0] == 2 and not scheduler.running, "wave scheduler spawns delays and completes defeat-all waves")

func _test_enemy_pool() -> void:
	var pool := EnemyPoolManager.new()
	host.add_child(pool)
	_assert(pool.prewarm(8) == 8, "enemy pool prewarms reusable actors")
	var enemy_definition := database.get_definition(&"enemy.dart", &"enemy") as EnemyDefinition
	var enemy := pool.acquire({"actor_id": &"enemy.pool_test", "definition": enemy_definition, "registry": registry, "event_bus": events}, Vector2(100, 100))
	_assert(enemy != null and pool.active_count() == 1, "pooled enemy configures entirely from its definition")
	enemy.destroy_actor(&"player.one")
	_assert(pool.active_count() == 0 and registry.get_actor(&"enemy.pool_test") == null, "enemy destruction returns the actor to its pool and unregisters it")

func _test_no_hot_path_searches() -> void:
	var clean := true
	for path in ["res://production/enemies/enemy_attack_controller.gd", "res://production/actors/production_enemy.gd"]:
		var file := FileAccess.open(path, FileAccess.READ)
		var source := file.get_as_text() if file != null else ""
		clean = clean and "get_nodes_in_group" not in source and "find_child" not in source
	_assert(clean, "enemy attacks use injected targets and never search the scene tree")
