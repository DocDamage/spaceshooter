extends Node2D

const STAGE := preload("res://legacy/game/stage.gd")

var stage: MigrationStage
var title_label: Label
var status_label: Label
var hint_label: Label
var splash_timer := 1.1

func _ready() -> void:
	_build_interface()
	_show_splash()

func _process(delta: float) -> void:
	if GameServer.state == GameServer.GameState.SPLASH:
		splash_timer -= delta
		if splash_timer <= 0.0:
			_show_menu()
	elif GameServer.state == GameServer.GameState.MENU and (Input.is_action_just_pressed("game_a") or Input.is_action_just_pressed("game_start")):
		start_stage()
	elif GameServer.state in [GameServer.GameState.COMPLETE, GameServer.GameState.GAME_OVER] and Input.is_action_just_pressed("game_start"):
		_show_menu()

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	title_label = Label.new()
	title_label.position = Vector2(24, 22)
	title_label.add_theme_font_size_override("font_size", 28)
	layer.add_child(title_label)
	status_label = Label.new()
	status_label.position = Vector2(24, 66)
	status_label.add_theme_font_size_override("font_size", 19)
	layer.add_child(status_label)
	hint_label = Label.new()
	hint_label.position = Vector2(24, 880)
	hint_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(hint_label)

func _show_splash() -> void:
	GameServer.set_state(GameServer.GameState.SPLASH)
	title_label.text = "GALAX HERO"
	status_label.text = "Godot 4.7.1 migration build"
	hint_label.text = ""

func _show_menu() -> void:
	if is_instance_valid(stage):
		stage.queue_free()
		stage = null
	GameServer.reset_session()
	title_label.text = "GALAX HERO"
	status_label.text = "LEGACY COMPATIBILITY MISSION"
	hint_label.text = "A / SPACE: START    WASD / STICK: MOVE"

func start_stage() -> void:
	GameServer.set_state(GameServer.GameState.PLAYING)
	stage = STAGE.new()
	add_child(stage)
	move_child(stage, 0)
	stage.player_stats_changed.connect(_on_player_stats)
	stage.progress_changed.connect(_on_progress)
	stage.completed.connect(_on_stage_completed)
	stage.failed.connect(_on_stage_failed)
	title_label.text = "MIGRATION SORTIE"
	hint_label.text = "A / SPACE: FIRE"
	stage.player._emit_stats()
	_on_progress(stage.defeated_count, stage.spawn_points.size())

func _on_player_stats(health: int, shield: int, level: int, experience: int, next_level: int) -> void:
	status_label.text = "HP %d  SHIELD %d  LV %d  XP %d/%d  CR %d" % [health, shield, level, experience, next_level, Currency.get_main_currency()]

func _on_progress(defeated: int, total: int) -> void:
	title_label.text = "MIGRATION SORTIE  %d/%d" % [defeated, total]

func _on_stage_completed() -> void:
	GameServer.set_state(GameServer.GameState.COMPLETE)
	title_label.text = "STAGE COMPLETE"
	status_label.text = "Kills %d  Credits %d  Level %d" % [BattleServer.kills, Currency.get_main_currency(), stage.player.level]
	hint_label.text = "START / ENTER: RETURN TO MENU"

func _on_stage_failed() -> void:
	GameServer.set_state(GameServer.GameState.GAME_OVER)
	title_label.text = "SHIP DESTROYED"
	hint_label.text = "START / ENTER: RETURN TO MENU"
