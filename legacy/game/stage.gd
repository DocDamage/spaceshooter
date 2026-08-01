class_name MigrationStage
extends Node2D

signal player_stats_changed(health: int, shield: int, level: int, experience: int, next_level: int)
signal progress_changed(defeated: int, total: int)
signal completed
signal failed

const PLAYER := preload("res://legacy/game/player.gd")
const ENEMY := preload("res://legacy/game/enemy.gd")
const STAGE_ID := &"legacy_migration_stage"

var player: MigrationPlayer
var spawn_points: Array[Vector2] = []
var spawned := 0
var defeated_count := 0
var spawn_timer := 0.5
var stage_finished := false

func _ready() -> void:
	LegacyServiceLocator.require(self, &"LegacyBattleServer").reset_battle()
	LegacyServiceLocator.require(self, &"LegacyLevelServer").begin_stage(STAGE_ID)
	spawn_points = LegacyServiceLocator.require(self, &"LegacyEnemySpawnerData").get_legacy_wave()
	player = PLAYER.new()
	add_child(player)
	player.position = Vector2(270, 820)
	player.stats_changed.connect(player_stats_changed.emit)
	player.died.connect(_on_player_died)
	player._emit_stats()
	progress_changed.emit(0, spawn_points.size())
	queue_redraw()

func _process(delta: float) -> void:
	if stage_finished or spawned >= spawn_points.size():
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_enemy(spawn_points[spawned])
		spawned += 1
		spawn_timer = 0.85

func _spawn_enemy(spawn_position: Vector2) -> void:
	var enemy := ENEMY.new()
	add_child(enemy)
	enemy.position = spawn_position
	enemy.defeated.connect(_on_enemy_defeated)

func _on_enemy_defeated(xp: int, credits: int) -> void:
	defeated_count += 1
	LegacyServiceLocator.require(self, &"LegacyBattleServer").register_enemy_defeat(xp, credits)
	LegacyServiceLocator.require(self, &"LegacyCurrency").add(credits)
	if is_instance_valid(player):
		player.add_experience(xp)
	progress_changed.emit(defeated_count, spawn_points.size())
	if defeated_count >= spawn_points.size():
		complete_stage()

func complete_stage() -> void:
	if stage_finished:
		return
	stage_finished = true
	LegacyServiceLocator.require(self, &"LegacyLevelServer").complete_stage(STAGE_ID)
	completed.emit()

func _on_player_died() -> void:
	if stage_finished:
		return
	stage_finished = true
	failed.emit()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 540, 960), Color("071328"))
	for index in range(70):
		var star := Vector2(float((index * 97) % 532 + 4), float((index * 173) % 940 + 10))
		var radius := 1.0 + float(index % 3) * 0.45
		draw_circle(star, radius, Color(0.6, 0.78, 1.0, 0.6))
