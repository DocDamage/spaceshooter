class_name MigrationEnemy
extends Area2D

signal defeated(experience: int, credits: int)

const PROJECTILE := preload("res://legacy/game/projectile.gd")
var health := 50
var speed := 80.0
var fire_timer := 1.25

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	position.y += speed * delta
	position.x += sin(position.y * 0.015) * 35.0 * delta
	fire_timer -= delta
	if fire_timer <= 0.0 and position.y > 20.0 and position.y < 700.0:
		fire_timer = 1.5
		var shot := PROJECTILE.new()
		get_parent().add_child(shot)
		shot.setup(position + Vector2(0, 22), Vector2.DOWN, 260.0, false, 20)
	if position.y > 1020.0:
		# Keep the small migration wave finishable if an enemy slips past once.
		position.y = -30.0

func take_damage(amount: int) -> void:
	health -= amount
	LegacyServiceLocator.require(self, &"LegacyBattleServer").damage_dealt += amount
	if health <= 0:
		defeated.emit(35, 10)
		queue_free()

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(0, 22), Vector2(22, -15), Vector2(0, -8), Vector2(-22, -15)]), Color("ff627e"))
	draw_circle(Vector2.ZERO, 5.0, Color("ffcf67"))
