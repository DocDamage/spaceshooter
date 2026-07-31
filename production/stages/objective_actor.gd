class_name ObjectiveActor
extends BaseActor2D

signal objective_actor_resolved(objective_id: StringName, succeeded: bool, actor_index: int)

var objective_definition: ObjectiveDefinition
var actor_index := 0
var objective_controller: ObjectiveController
var players: Array[Node2D] = []
var elapsed := 0.0
var _resolved := false

func configure_objective(definition: ObjectiveDefinition, index: int, controller: ObjectiveController, context: Dictionary) -> void:
	objective_definition = definition
	actor_index = index
	objective_controller = controller
	players.assign(context.get("players", []))
	var hostile := definition.objective_type in ["sabotage", "destroy_marked"]
	configure_actor(StringName("objective.%s.%d" % [definition.stable_id, index]), &"objective", &"enemies" if hostile else &"neutral", context.get("registry") as ActorRegistry, context.get("event_bus") as TypedEventBus)
	health_component.configure(220.0 if hostile else 140.0)
	armor_component.configure(6.0 if hostile else 2.0)
	hurtbox_component.configure(30.0)
	position = Vector2(270.0 + (float(index) - float(definition.target_count - 1) * 0.5) * 90.0, 220.0 if hostile else 310.0)

func _ready() -> void:
	super()
	collision_layer = 4
	collision_mask = 2
	var collision := CollisionShape2D.new(); var shape := CircleShape2D.new(); shape.radius = 30.0; collision.shape = shape; add_child(collision)
	queue_redraw()

func _physics_process(delta: float) -> void:
	super(delta)
	if not active or _resolved or objective_definition == null: return
	elapsed += delta
	match objective_definition.objective_type:
		"rescue", "collect":
			position.y += 78.0 * delta
			if _player_within(92.0): _resolve(true)
			elif position.y > 1010.0: _resolve(false)
		"escort", "protect":
			position.y = minf(730.0, position.y + 34.0 * delta)
			if elapsed >= maxf(10.0, objective_definition.duration_seconds): _resolve(true)

func receive_damage(packet: DamagePacket) -> DamageResult:
	if faction == &"neutral" and packet.source_player_id != &"" and objective_controller != null:
		objective_controller.notify_neutral_damage()
	return super(packet)

func destroy_actor(source_actor_id: StringName) -> void:
	if _resolved: return
	_resolve(faction == &"enemies")
	super(source_actor_id)

func snapshot() -> Dictionary:
	return {"objective_id": objective_definition.stable_id, "index": actor_index, "position": position, "elapsed": elapsed, "health": health_component.current, "resolved": _resolved}

func restore(data: Dictionary) -> bool:
	if StringName(data.get("objective_id", "")) != objective_definition.stable_id or int(data.get("index", -1)) != actor_index: return false
	position = data.get("position", position)
	elapsed = maxf(0.0, float(data.get("elapsed", 0.0)))
	health_component.current = clampf(float(data.get("health", health_component.maximum)), 0.0, health_component.maximum)
	_resolved = bool(data.get("resolved", false))
	if _resolved: visible = false; set_physics_process(false)
	return true

func _player_within(radius: float) -> bool:
	for player in players:
		if is_instance_valid(player) and player is BaseActor2D and player.active and global_position.distance_to(player.global_position) <= radius: return true
	return false

func _resolve(succeeded: bool) -> void:
	if _resolved: return
	_resolved = true
	if objective_controller != null:
		if succeeded: objective_controller.progress(objective_definition.stable_id)
		else: objective_controller.fail(objective_definition.stable_id)
	objective_actor_resolved.emit(objective_definition.stable_id, succeeded, actor_index)
	visible = false
	set_deferred("monitoring", false)
	set_physics_process(false)

func _draw() -> void:
	var hostile := objective_definition != null and objective_definition.objective_type in ["sabotage", "destroy_marked"]
	draw_circle(Vector2.ZERO, 28.0, Color("a83b55") if hostile else Color("4dc9b0"))
	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 24, Color("ffda72") if hostile else Color("b5fff1"), 3.0)
	draw_rect(Rect2(-12,-5,24,10), Color("ffe9a8") if hostile else Color("e6fffb"))
