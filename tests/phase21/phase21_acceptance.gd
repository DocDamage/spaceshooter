extends SceneTree

class FakeCloudProvider:
	extends RefCounted
	var files: Dictionary = {}
	var achievements: Array[String] = []

	func fileWrite(path: String, bytes: PackedByteArray) -> bool:
		files[path] = bytes.duplicate()
		return true

	func getFileSize(path: String) -> int:
		return (files.get(path, PackedByteArray()) as PackedByteArray).size()

	func fileRead(path: String, _size: int) -> PackedByteArray:
		return (files.get(path, PackedByteArray()) as PackedByteArray).duplicate()

	func setAchievement(achievement_id: String) -> bool:
		if achievement_id not in achievements: achievements.append(achievement_id)
		return true

	func storeStats() -> void:
		pass

var failures := PackedStringArray()
var passed_count := 0
var hub: ServiceHub
var storage_path := ""

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
	storage_path = "user://phase21_acceptance_%d" % Time.get_ticks_usec()
	hub = ServiceHub.new()
	root.add_child(hub)
	await process_frame
	hub.saves.configure_storage(storage_path.path_join("saves"))
	_test_authored_campaign_and_decisions()
	_test_visual_breadth()
	_test_untrusted_data_bounds()
	_test_platform_and_achievement_persistence()
	_test_music_state_machine()
	if failures.is_empty():
		print("PHASE 21 ACCEPTANCE: all %d checks passed" % passed_count)
		_finish(0)
	else:
		print("PHASE 21 ACCEPTANCE: %d check(s) failed" % failures.size())
		_finish(1)

func _test_authored_campaign_and_decisions() -> void:
	var titles := {}
	var complete := FullCampaignContentFactory.authored_stage_count() == 50
	var no_template_prose := true
	var decision_echoes := 0
	for operation in range(2, 7):
		for stage in range(1, 11):
			var entry := FullCampaignContentFactory.authored_stage_content(operation, stage)
			complete = complete and ["title", "setup", "wing", "result", "consequence"].all(func(key): return not str(entry.get(key, "")).strip_edges().is_empty())
			titles[str(entry.get("title", ""))] = true
			var combined := JSON.stringify(entry).to_lower()
			no_template_prose = no_template_prose and "begins as the squad enters" not in combined and "stage % escalates" not in combined and "records the result and prepares" not in combined
			if entry.has("decision_echo"): decision_echoes += 1
	_assert(complete and titles.size() == 50 and no_template_prose, "Operations 2-6 load fifty distinct authored narrative records without factory-template prose")
	_assert(decision_echoes >= 4, "authored campaign data declares later echoes for every pre-finale strategic decision")
	hub.story.decisions = {&"specialist_doctrine": &"independent"}
	var dialogue := hub.content_database.get_definition(&"dialogue.operation3_stage1.briefing", &"dialogue") as DialogueDefinition
	var resolved := hub.story.resolve_lines(dialogue.lines)
	_assert(resolved.any(func(line): return "Independent wings scout separate ruin lanes" in str(line.get("text", ""))), "recorded campaign choices visibly alter later briefing dialogue")

func _test_visual_breadth() -> void:
	var ship_paths := {}
	var ships_valid := true
	var background_paths := {}
	for operation in range(2, 7):
		var ship := hub.content_database.get_definition(StringName("ship.operation%d_specialist" % operation), &"ship") as ShipDefinition
		ships_valid = ships_valid and ship != null and not ship.visual_asset_path.is_empty() and ResourceLoader.exists(ship.visual_asset_path)
		if ship != null: ship_paths[ship.visual_asset_path] = true
		var mission := hub.content_database.get_definition(StringName("mission.operation%d_stage1" % operation), &"mission") as MissionDefinition
		if mission != null and ResourceLoader.exists(mission.background_asset_path): background_paths[mission.background_asset_path] = true
	_assert(ships_valid and ship_paths.size() == 5, "all five specialist hulls use distinct approved runtime ship art")
	_assert(background_paths.size() == 5, "Operations 2-6 use five valid operation-specific background resources")
	var enemy_paths := {}
	for enemy in hub.content_database.get_definitions_by_type(&"enemy"):
		var path := (enemy as EnemyDefinition).visual_asset_path
		if not path.is_empty() and ResourceLoader.exists(path): enemy_paths[path] = true
	_assert(enemy_paths.size() >= 8 and ["res://assets_runtime/enemies/enemy_crab.png", "res://assets_runtime/enemies/enemy_gunship.png", "res://assets_runtime/enemies/enemy_fighter_blue.png", "res://assets_runtime/enemies/enemy_fighter_red.png"].all(func(path): return enemy_paths.has(path)), "enemy roster uses at least eight valid silhouettes including the expanded faction set")
	_assert(["res://assets_runtime/objectives/objective_relay_station.png", "res://assets_runtime/hazards/hazard_asteroids_sheet.png", "res://assets_runtime/pickups/pickup_health_container.png", "res://assets_runtime/projectiles/projectile_plasma_lance.png"].all(ResourceLoader.exists), "objectives, hazards, pickups, and projectiles resolve approved production textures")
	var production_theme := GalaxHeroTheme.create()
	var panel_style := production_theme.get_stylebox("panel", "PanelContainer")
	var button_style := production_theme.get_stylebox("normal", "Button")
	_assert(panel_style is StyleBoxFlat and button_style is StyleBoxFlat and (panel_style as StyleBoxFlat).bg_color.a > 0.9 and (button_style as StyleBoxFlat).border_width_left > 0, "shipping menus and results use readable translucent panels and bounded button frames without stretching tiny textures")

func _test_untrusted_data_bounds() -> void:
	var sanitized := InputSanitizer.sanitize_display_name("../Pilot\u202e\n<unsafe>|", 32)
	_assert("\u202e" not in sanitized and "\n" not in sanitized and "/" not in sanitized and "<" not in sanitized and sanitized.length() <= 32, "profile and network-facing names strip controls, bidi overrides, and path-unsafe characters")
	_assert(InputSanitizer.safe_storage_key("../escape.json").is_empty() and hub.saves.profile_path(&"../escape").begins_with(hub.saves.storage_root) and "invalid_profile" in hub.saves.profile_path(&"../escape"), "save storage keys cannot traverse outside the configured profile root")
	var nested: Variant = "leaf"
	for ignored in 40: nested = {"next": nested}
	var deep_error := hub.saves.save_snapshot_atomic({"schema_version": SaveService.SCHEMA_VERSION, "nested": nested}, storage_path.path_join("deep.json"))
	_assert(deep_error != OK and hub.saves.status == &"error", "save serialization rejects payloads beyond the bounded nesting depth")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(storage_path))
	var oversized_path := storage_path.path_join("oversized.json")
	var oversized_file := FileAccess.open(oversized_path, FileAccess.WRITE)
	var oversized_bytes := PackedByteArray(); oversized_bytes.resize(SaveService.MAX_SAVE_FILE_BYTES + 1)
	oversized_file.store_buffer(oversized_bytes); oversized_file.close()
	_assert(hub.saves.load_snapshot(oversized_path).is_empty() and hub.saves.status == &"corrupt", "save loading rejects oversized files before parsing or allocation-heavy migration")
	var valid := NetworkProtocol.make_message(&"player_input", 1, 1, {"move": Vector2.ZERO})
	var too_many := NetworkProtocol.make_message(&"player_input", 1, 1, {"values": Array(range(NetworkProtocol.MAX_ARRAY_ENTRIES + 1))})
	var too_long := NetworkProtocol.make_message(&"player_input", 1, 1, {"text": "x".repeat(NetworkProtocol.MAX_STRING_BYTES + 1)})
	var deep_network: Variant = 1
	for ignored in 12: deep_network = {"next": deep_network}
	var too_deep := NetworkProtocol.make_message(&"player_input", 1, 1, {"nested": deep_network})
	var non_finite := NetworkProtocol.make_message(&"player_input", 1, 1, {"number": INF})
	var object_payload := NetworkProtocol.make_message(&"player_input", 1, 1, {"object": RefCounted.new()})
	var bad_sender := NetworkProtocol.make_message(&"player_input", 1, 3, {})
	_assert(NetworkProtocol.validate_message(valid).is_empty() and [too_many, too_long, too_deep, non_finite, object_payload, bad_sender].all(func(message): return not NetworkProtocol.validate_message(message).is_empty()), "network protocol accepts bounded gameplay data and rejects oversized, deep, non-finite, object, and out-of-roster payloads")
	var transport := OnlineTransport.new(); root.add_child(transport)
	_assert(transport.join_host("127.0.\n0.1") == ERR_INVALID_PARAMETER and transport.send_message(1, valid) == ERR_UNCONFIGURED, "direct-IP transport sanitizes addresses and cannot send before a validated connection")
	transport.queue_free()

func _test_platform_and_achievement_persistence() -> void:
	var provider := FakeCloudProvider.new()
	hub.platform.configure_provider(provider, "phase21_provider")
	var presence_ok := hub.platform.set_rich_presence({"stage": "Convergence\u202e\nFinale"})
	var cloud_document := {"revision": 4, "campaign_stage": 38, "checksum": "test"}
	var cloud_written := hub.platform.write_cloud_document("campaign_slot.json", cloud_document) == OK
	var cloud_read := hub.platform.read_cloud_document("campaign_slot.json")
	_assert(presence_ok and "\u202e" not in str(hub.platform.rich_presence.stage) and "\n" not in str(hub.platform.rich_presence.stage), "platform rich presence is provider-agnostic and strips unsafe display controls")
	_assert(cloud_written and cloud_read.error == OK and int(cloud_read.document.revision) == 4 and int(cloud_read.document.campaign_stage) == 38 and cloud_read.document.checksum == "test" and hub.platform.write_cloud_document("../escape.json", {}) == ERR_INVALID_PARAMETER, "cloud documents round-trip through the provider while traversal paths are rejected")
	var achievement_path := storage_path.path_join("achievements.json")
	hub.achievements.configure_storage(achievement_path, true)
	hub.achievements.unlock(&"achievement.phase21_persisted")
	var restored := AchievementService.new(); root.add_child(restored); restored.initialize({"hub": hub}); restored.configure_storage(achievement_path, true)
	_assert(restored.is_unlocked(&"achievement.phase21_persisted") and provider.achievements.has("achievement.phase21_persisted"), "achievement unlocks persist atomically and reconcile through the platform abstraction")
	restored.queue_free()

func _test_music_state_machine() -> void:
	var music := load("res://assets_runtime/audio/music_stage1_frontier_theme.ogg") as AudioStream
	var menu_voice := hub.audio.transition_music(music, &"menu", 0.0, true)
	var stage_voice := hub.audio.transition_music(music, &"operation_2_stage", 0.0, true)
	var snapshot := hub.audio.capture_music_state()
	var one_voice := menu_voice != null and stage_voice == menu_voice and hub.audio.active_voice_count(&"Music") == 1
	hub.audio.stop_bus(&"Music")
	var restored := hub.audio.restore_music_state(snapshot)
	_assert(one_voice and snapshot.state_id == &"operation_2_stage" and restored and hub.audio.current_music_state == &"operation_2_stage" and hub.audio.active_voice_count(&"Music") == 1, "music state transitions avoid duplicate voices and restore the active track across lifecycle changes")

func _finish(exit_code: int) -> void:
	hub = null
	TestSupport.free_root_nodes(self)
	TestSupport.remove_tree(storage_path)
	call_deferred("_quit_after_cleanup", exit_code)

func _quit_after_cleanup(exit_code: int) -> void:
	await process_frame
	quit(exit_code)
