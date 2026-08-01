extends Node2D

var registry: ActorRegistry
var events: TypedEventBus

func _ready() -> void:
	registry = ActorRegistry.new()
	add_child(registry)
	events = TypedEventBus.new()
	_spawn_target(&"actor_test.armored", Vector2(210, 300), 12.0, 50.0)
	_spawn_target(&"actor_test.shielded", Vector2(330, 300), 2.0, 100.0)
	queue_redraw()

func _spawn_target(id: StringName, location: Vector2, armor: float, shield: float) -> void:
	var actor := BaseActor2D.new()
	actor.configure_actor(id, &"enemy", &"test_targets", registry, events)
	actor.health_component.configure(100.0)
	actor.armor_component.configure(armor)
	actor.shield_component.configure(shield, 1.0, 20.0)
	actor.position = location
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 28.0
	collision.shape = shape
	actor.add_child(collision)
	add_child(actor)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 540, 960), Color("071328"))
	draw_string(ThemeDB.fallback_font, Vector2(105, 120), "PHASE 5 ACTOR FOUNDATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("6de6ff"))
	draw_string(ThemeDB.fallback_font, Vector2(125, 180), "Armored target      Shielded target", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_circle(Vector2(210, 300), 34.0, Color("ff8c69"))
	draw_circle(Vector2(330, 300), 42.0, Color(0.25, 0.8, 1.0, 0.35))
	draw_circle(Vector2(330, 300), 30.0, Color("ff8c69"))
