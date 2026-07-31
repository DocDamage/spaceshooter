extends SceneTree

var failures := PackedStringArray()
var passed_count := 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)

func _run() -> void:
	await process_frame
	var hub := root.get_node("ProductionServices") as ServiceHub
	var database := hub.content_database
	_check(database.get_content_count() >= 4, "content directories scan and index the foundation definitions plus later-phase content")
	_check(database.get_definition(&"ship.vanguard", &"ship") is ShipDefinition, "ship resolves by stable content ID and type")
	_check(database.get_definition(&"weapon.pulse_cannon", &"weapon") is WeaponDefinition, "weapon resolves by stable content ID and type")
	_check(database.get_definition(&"enemy.scout", &"enemy") is EnemyDefinition, "enemy resolves by stable content ID and type")
	_check(not database.get_content_version().is_empty(), "content version metadata is recorded")

	var first := ShipDefinition.new(); first.stable_id = &"test.duplicate"
	var second := EnemyDefinition.new(); second.stable_id = &"test.duplicate"
	var duplicate_database := ContentDatabase.new()
	_check(not duplicate_database.build_index_for_test([first, second]), "duplicate content IDs fail validation")
	_check("Duplicate content ID: test.duplicate" in duplicate_database.get_validation_errors(), "duplicate validation reports the stable ID")
	duplicate_database.free()
	var dependent := ShipDefinition.new(); dependent.stable_id = &"test.dependent"; dependent.dependency_ids = [&"test.missing"]
	var missing_database := ContentDatabase.new()
	_check(not missing_database.build_index_for_test([dependent]), "missing content dependencies fail validation")
	missing_database.free()

	_check(hub.is_ready, "global services initialize")
	_check(hub.get_initialization_order().size() == 12, "service initialization order is explicit")
	for service_id in hub.get_initialization_order():
		_check(hub.get_service(service_id).is_initialized, "%s service has an integration-tested initialization boundary" % service_id)
	hub.settings.set_setting(&"test_setting", 42)
	_check(hub.settings.get_setting(&"test_setting") == 42, "settings service reads and writes through its API")
	_check(hub.platform.supports(&"local_saves"), "platform service reports supported capabilities")
	hub.localization.set_locale("en")
	_check(hub.localization.locale == "en", "localization service owns locale changes")
	_check(hub.input.get_move_vector() is Vector2, "input service exposes player movement")
	hub.audio.set_master_volume(0.5)
	_check(is_equal_approx(hub.audio.master_volume, 0.5), "audio service owns volume state")
	_check(not hub.profiles.selected_profile_ids.is_empty(), "profile service exposes selected profiles")
	_check(hub.saves.status == &"idle", "save service exposes status before session save")
	hub.achievements.unlock(&"achievement.phase2_test")
	_check(hub.achievements.is_unlocked(&"achievement.phase2_test"), "achievement service owns unlock state")
	_check(hub.scene_router is SceneRouterService, "scene routing remains behind a service boundary")
	hub.game_flow.transition_to(&"test")
	_check(hub.game_flow.current_state == &"test", "game-flow service owns state transitions")
	_check(hub.diagnostics.get_snapshot().has("fps"), "diagnostics service exposes runtime telemetry")

	var event := ActorDamagedEvent.new(&"enemy.test", &"player.test", 7.0)
	_check(event.get_event_type() == &"actor_damaged", "typed event exposes a stable event type")
	_check(event.source_id == &"enemy.test" and event.target_id == &"player.test", "typed event carries stable source and target IDs")

	var mission_definition := database.get_definition(&"mission.architecture_test", &"mission") as MissionDefinition
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
	_check(session.configure(config, hub), "GameSession receives complete configuration before activation")
	root.add_child(session)
	var mission := load("res://production/missions/test_mission.tscn").instantiate() as ProductionTestMission
	mission.configure(session, database)
	session.add_child(mission)
	await process_frame
	_check(session.mission_state.status == &"active", "test mission launches from MissionDefinition")
	_check(session.actor_registry.get_count(&"player") == 2, "a second player registers without registry code changes")
	_check(session.actor_registry.get_count(&"enemy") == 3, "enemy actors register in the scoped registry")
	var diagnostics := hub.diagnostics.get_snapshot()
	_check(diagnostics.players == 2 and diagnostics.enemies == 3 and diagnostics.mission_seed == 424242, "diagnostics report active runtime counts and seed")
	for index in 3: session.register_defeat(StringName("enemy.wave_1.%d" % index), 10)
	_check(session.completion_result.success and hub.saves.status == &"saved", "completion produces result, checkpoint, rewards, and save status")
	session.queue_free()
	await process_frame

	var exit_code := 0 if failures.is_empty() else 1
	if failures.is_empty(): print("PHASE 2 ACCEPTANCE: all %d checks passed" % passed_count)
	else: print("PHASE 2 ACCEPTANCE: %d check(s) failed" % failures.size())
	mission = null; session = null; config = null; mission_definition = null; database = null; hub = null
	TestSupport.free_root_nodes(self)
	call_deferred("_quit_after_cleanup", exit_code)

func _quit_after_cleanup(exit_code: int) -> void:
	await process_frame
	quit(exit_code)
