class_name MigrationProjectile
extends Area2D

var velocity := Vector2.ZERO
var damage := 10
var friendly := true

func setup(start_position: Vector2, direction: Vector2, speed: float, is_friendly: bool, hit_damage: int) -> void:
	position = start_position
	velocity = direction.normalized() * speed
	friendly = is_friendly
	damage = hit_damage
	collision_layer = 2 if friendly else 8
	collision_mask = 4 if friendly else 1
	queue_redraw()

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	position += velocity * delta
	if position.y < -80.0 or position.y > 1040.0 or position.x < -80.0 or position.x > 620.0:
		queue_free()

func _draw() -> void:
	var color := Color("62e7ff") if friendly else Color("ff5678")
	draw_circle(Vector2.ZERO, 5.0, color)
	draw_line(Vector2(0, 8), Vector2(0, -8), color, 3.0)

func _on_area_entered(area: Area2D) -> void:
	if friendly and area.has_method("take_damage") and area.is_in_group("enemies"):
		area.take_damage(damage)
		queue_free()
	elif not friendly and area.has_method("take_damage") and area.is_in_group("players"):
		area.take_damage(damage)
		queue_free()

