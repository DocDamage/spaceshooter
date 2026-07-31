extends SceneTree

var failures := PackedStringArray()
var services: ServiceHub
var passed_count := 0

func _init() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)

func _run() -> void:
	await process_frame
	services = root.get_node("ProductionServices") as ServiceHub
	_test_content_database()
	_test_services()
	_test_typed_events()
	await _test_session_and_mission()
	if failures.is_empty():
		print("PHASE 2 ACCEPTANCE: all %d checks passed" % passed_count)
		quit(0)
	else:
		print("PHASE 2 ACCEPTANCE: %d check(s) failed" % failures.size())
		quit(1)

func _test_content_database() -> void:
	var database: ContentDatabase = services.content_database
	_assert(database.get_content_count() >= 4, "content directories scan and index the foundation definitions plus later-phase content")
	_assert(database.get_definition(&"ship.vanguard", &"ship") is ShipDefinition, "ship resolves by stable content ID and type")
	_assert(database.get_definition(&"weapon.pulse_cannon", &"weapon") is WeaponDefinition, "weapon resolves by stable content ID and type")
	_assert(database.get_definition(&"enemy.scout", &"enemy") is EnemyDefinition, "enemy resolves by stable content ID and type")
	_assert(not database.get_content_version().is_empty(), "content version metadata is recorded")
	var first := ShipDefinition.new()
	first.stable_id = &"test.duplicate"
	var second := EnemyDefinition.new()
	second.stable_id = &"test.duplicate"
	var duplicate_database := ContentDatabase.new()
	_assert(not duplicate_database.build_index_for_test([first, second]), "duplicate content IDs fail validation")
	_assert("Duplicate content ID: test.duplicate" in duplicate_database.get_validation_errors(), "duplicate validation reports the stable ID")
	duplicate_database.free()
	var dependent := ShipDefinition.new()
	dependent.stable_id = &"test.dependent"
	dependent.dependency_ids = [&"test.missing"]
	var missing_database := ContentDatabase.new()
	_assert(not missing_database.build_index_for_test([dependent]), "missing content dependencies fail validation")
	missing_database.free()

func _test_services() -> void:
	_assert(services.is_ready, "global services initialize")
	_assert(services.get_initialization_order().size() == 12, "service initialization order is explicit")
	for service_id in services.get_initialization_order():
		_assert(services.get_service(service_id).is_initialized, "%s service has an integration-tested initialization boundary" % service_id)
	services.settings.set_setting(&"test_setting", 42)
	_assert(services.settings.get_setting(&"test_setting") == 42, "settings service reads and writes through its API")
	_assert(services.platform.supports(&"local_saves"), "platform service reports supported capabilities")
	services.localization.set_locale("en")
	_assert(services.localization.locale == "en", "localization service owns locale changes")
	_assert(services.input.get_move_vector() is Vector2, "input service exposes player movement")
	services.audio.set_master_volume(0.5)
	_assert(is_equal_approx(services.audio.master_volume, 0.5), "audio service owns volume state")
	_assert(not services.profiles.selected_profile_ids.is_empty(), "profile service exposes selected profiles")
	_assert(services.saves.status == &"idle", "save service exposes status before session save")
	services.achievements.unlock(&"achievement.phase2_test")
	_assert(services.achievements.is_unlocked(&"achievement.phase2_test"), "achievement service owns unlock state")
	_assert(services.scene_router is SceneRouterService, "scene routing remains behind a service boundary")
	services.game_flow.transition_to(&"test")
	_assert(services.game_flow.current_state == &"test", "game-flow service owns state transitions")
	_assert(services.diagnostics.get_snapshot().has("fps"), "diagnostics service exposes runtime telemetry")

func _test_typed_events() -> void:
	var event := ActorDamagedEvent.new(&"enemy.test", &"player.test", 7.0)
	_assert(event.get_event_type() == &"actor_damaged", "typed event exposes a stable event type")
	_assert(event.source_id == &"enemy.test" and event.target_id == &"player.test", "typed event carries stable source and target IDs")

func _test_session_and_mission() -> void:
	var mission_definition := services.content_database.get_definition(&"mission.architecture_test", &"mission") as MissionDefinition
	var config := GameSessionConfig.new()
	config.mission_definition = mission_definition
	config.selected_profiles = [&"profile.local_1", &"profile.local_2"]
	config.selected_ships = [&"ship.vanguard", &"ship.vanguard"]
	config.loadouts = [{"weapon_id": &"weapon.pulse_cannon"}, {"weapon_id": &"weapon.pulse_cannon"}]
	config.difficulty_profile = &"normal"
	config.stage_seed = 424242
	config.mode_rules = {"friendly_fire": false}
	config.multiplayer_configuration = {"local_players": 2, "online": false}
	var session := GameSession.new()
	_assert(session.configure(config, services), "GameSession receives complete configuration before activation")
	root.add_child(session)
	var mission := load("res://production/missions/test_mission.tscn").instantiate() as ProductionTestMission
	mission.configure(session, services.content_database)
	session.add_child(mission)
	await process_frame
	_assert(session.mission_state.status == &"active", "test mission launches from MissionDefinition")
	_assert(session.actor_registry.get_count(&"player") == 2, "a second player registers without registry code changes")
	_assert(session.actor_registry.get_count(&"enemy") == 3, "enemy actors register in the scoped registry")
	var diagnostics := services.diagnostics.get_snapshot()
	_assert(diagnostics.players == 2 and diagnostics.enemies == 3 and diagnostics.mission_seed == 424242, "diagnostics report active runtime counts and seed")
	for index in 3:
		session.register_defeat(StringName("enemy.wave_1.%d" % index), 10)
	_assert(session.completion_result.success and services.saves.status == &"saved", "completion produces result, checkpoint, rewards, and save status")
	session.queue_free()
	await process_frame
