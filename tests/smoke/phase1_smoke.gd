extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
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
	Currency.reset()
	Currency.add(10)
	_check(Currency.get_main_currency() == 10, "currency increments")
	stage.complete_stage()
	_check(LevelServer.completed_stages.has(MigrationStage.STAGE_ID), "stage completion recorded")
	_check(GameServer != null and AudioCenter != null and BattleServer != null and EnemySpawnerData != null and LevelGUI != null, "legacy autoload facades available")
	stage.queue_free()
	if failures.is_empty():
		print("PHASE1_SMOKE_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("PHASE1_SMOKE_FAIL: " + failure)
		get_tree().quit(1)
