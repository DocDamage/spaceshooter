class_name MigrationPlayer
extends Area2D

signal stats_changed(health: int, shield: int, level: int, experience: int, next_level: int)
signal died

const PROJECTILE := preload("res://legacy/game/projectile.gd")
const BOUNDS := Rect2(28, 70, 484, 850)

@export var move_speed := 310.0
@export var max_health := 100
@export var max_shield := 50

var health := 100
var shield := 50
var level := 1
var experience := 0
var fire_cooldown := 0.0

func _ready() -> void:
	add_to_group("players")
	collision_layer = 1
	collision_mask = 8
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)
	_emit_stats()

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("game_left", "game_right", "game_up", "game_down")
	position += direction * move_speed * delta
	position = Vector2(clampf(position.x, BOUNDS.position.x, BOUNDS.end.x), clampf(position.y, BOUNDS.position.y, BOUNDS.end.y))
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if Input.is_action_pressed("game_a"):
		fire()

func fire() -> void:
	if fire_cooldown > 0.0 or not is_inside_tree():
		return
	fire_cooldown = 0.14
	var shot := PROJECTILE.new()
	get_parent().add_child(shot)
	shot.setup(position + Vector2(0, -24), Vector2.UP, 660.0, true, 25)
	LegacyServiceLocator.require(self, &"LegacyAudioCenter").play(&"pulse_beam")

func take_damage(amount: int) -> void:
	var absorbed := mini(shield, amount)
	shield -= absorbed
	var remainder := amount - absorbed
	health = maxi(0, health - remainder)
	LegacyServiceLocator.require(self, &"LegacyBattleServer").register_player_damage(amount, absorbed)
	_emit_stats()
	queue_redraw()
	if health == 0:
		died.emit()

func add_experience(amount: int) -> void:
	experience += maxi(0, amount)
	while experience >= experience_to_next_level():
		experience -= experience_to_next_level()
		level += 1
		max_health += 10
		health = max_health
	_emit_stats()

func experience_to_next_level() -> int:
	return 50 + (level - 1) * 25

func _emit_stats() -> void:
	stats_changed.emit(health, shield, level, experience, experience_to_next_level())

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(0, -25), Vector2(18, 20), Vector2(0, 12), Vector2(-18, 20)]), Color("75d5ff"))
	draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
	if shield > 0:
		draw_arc(Vector2.ZERO, 25.0, 0, TAU, 40, Color(0.3, 0.85, 1.0, 0.45), 3.0)
