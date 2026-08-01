extends Node2D

var player: ProductionPlayer
var input_service: GameInputService
var registry: ActorRegistry
var event_bus: TypedEventBus
var trace := PackedVector2Array()
var tick_count := 0
var projectile_count := 0
var readout: Label

@export var normal_speed := 320.0
@export_range(0.45, 0.52, 0.01) var focus_ratio := 0.5
@export_range(3.5, 5.0, 0.1) var hitbox_radius := 4.5
@export_range(24.0, 32.0, 1.0) var graze_radius := 28.0

func _ready() -> void:
	input_service = get_node_or_null("/root/ProductionServices").input as GameInputService
	registry = ActorRegistry.new(); add_child(registry)
	event_bus = TypedEventBus.new()
	var ship := ShipDefinition.new()
	ship.normal_speed = normal_speed; ship.focus_speed = normal_speed * focus_ratio; ship.hitbox_radius = hitbox_radius; ship.graze_radius = graze_radius
	var weapon := WeaponDefinition.new()
	weapon.cooldown_seconds = 0.1
	player = ProductionPlayer.new()
	player.configure(&"lab.pilot", 0, ship, weapon, registry, event_bus, input_service)
	player.position = Vector2(270.0, 760.0)
	add_child(player)
	readout = Label.new()
	readout.position = Vector2(16, 16)
	readout.add_theme_font_size_override("font_size", 16)
	add_child(readout)
	input_service.assign_device(0, GameInputService.DEVICE_KEYBOARD_MOUSE)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if player == null:
		return
	tick_count += 1
	trace.append(player.position)
	if trace.size() > 120:
		trace.remove_at(0)
	var metrics := player.arcade_metrics()
	readout.text = "SHIP FEEL LAB\nWASD / D-pad / left stick: move\nZ / A: Rapid Shot   X / X: Focus Beam\nV / B: Overdrive   Shift / RB: Bomb buffer\nR: reset trace\n\nProfile: %.0f / %.0f / %.1f\nTick: %d  Fire events: %d\nInput: %s\nVelocity: %s  Speed: %.1f\nHitbox: %.1f  Graze: %.1f" % [normal_speed, normal_speed * focus_ratio, hitbox_radius, tick_count, projectile_count, input_service.get_move_vector(0), metrics.velocity, metrics.velocity.length(), metrics.hitbox_radius, metrics.graze_radius]
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		input_service.assign_device(0, event.device)
	elif event is InputEventKey and event.pressed:
		input_service.assign_device(0, GameInputService.DEVICE_KEYBOARD_MOUSE)
		if event.physical_keycode == KEY_R:
			player.position = Vector2(270.0, 760.0)
			trace.clear()

func spawn_projectile(_source: ProductionPlayer) -> void:
	projectile_count += 1

func _draw() -> void:
	for x in range(0, 541, 54):
		draw_line(Vector2(x, 0), Vector2(x, 960), Color(0.2, 0.45, 0.6, 0.16))
	for y in range(0, 961, 48):
		draw_line(Vector2(0, y), Vector2(540, y), Color(0.2, 0.45, 0.6, 0.16))
	if trace.size() > 1:
		draw_polyline(trace, Color(0.35, 0.95, 1.0, 0.55), 1.5)
