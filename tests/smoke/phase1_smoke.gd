extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	var legacy_services := {
		&"LegacyAudioCenter": "res://legacy/autoload/audio_center.gd",
		&"LegacyBattleServer": "res://legacy/autoload/battle_server.gd",
		&"LegacyEnemySpawnerData": "res://legacy/autoload/enemy_spawner_data.gd",
		&"LegacyLevelServer": "res://legacy/autoload/level_server.gd",
		&"LegacyLevelGUI": "res://legacy/autoload/level_gui.gd",
		&"LegacyCurrency": "res://legacy/autoload/currency.gd",
		&"LegacyGameServer": "res://legacy/autoload/game_server.gd",
	}
	for service_name in legacy_services:
		var service: Node = load(legacy_services[service_name]).new()
		service.name = String(service_name)
		get_tree().root.add_child(service)
	var stage_script := load("res://legacy/game/stage.gd")
	var stage: MigrationStage = stage_script.new()
	add_child(stage)
	await get_tree().process_frame
	_check(stage.player != null, "player spawned")
	_check(stage.player.position == Vector2(270, 820), "player starts in expected position")
	stage.player.take_damage(20)
	_check(stage.player.health == 100 and stage.player.shield == 30, "shield absorbs damage")
	stage.player.take_damage(40)
	_check(stage.player.health == 90 and stage.player.shield == 0, "overflow damage reaches hull")
	stage.player.add_experience(60)
	_check(stage.player.level == 2, "experience produces a level-up")
	var currency = get_node("/root/LegacyCurrency")
	currency.reset()
	currency.add(10)
	_check(currency.get_main_currency() == 10, "currency increments")
	stage.complete_stage()
	_check(get_node("/root/LegacyLevelServer").completed_stages.has(MigrationStage.STAGE_ID), "stage completion recorded")
	_check(legacy_services.keys().all(func(service_name): return get_tree().root.has_node(NodePath(String(service_name)))), "legacy facades are isolated to the smoke harness")
	stage.queue_free()
	for service_name in legacy_services:
		get_node(NodePath("/root/%s" % service_name)).queue_free()
	if failures.is_empty():
		print("PHASE1_SMOKE_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("PHASE1_SMOKE_FAIL: " + failure)
		get_tree().quit(1)
