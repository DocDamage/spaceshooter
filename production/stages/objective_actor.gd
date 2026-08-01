class_name ObjectiveActor
extends BaseActor2D

const RELAY_TEXTURE := preload("res://assets_runtime/objectives/objective_relay_station.png")
const RESCUE_TEXTURE := preload("res://assets_runtime/players/ship_bastion_final.png")
const HOSTILE_TEXTURE := preload("res://assets_runtime/hazards/hazard_pirate_base.png")
const MARKED_TEXTURE := preload("res://assets_runtime/enemies/enemy_gunship.png")
const SALVAGE_TEXTURE := preload("res://assets_runtime/pickups/pickup_energy_container.png")

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
	if objective_definition == null: return
	var hostile := objective_definition.objective_type in ["sabotage", "destroy_marked"]
	var texture: Texture2D = RELAY_TEXTURE
	var target_size := Vector2(62, 62)
	match objective_definition.objective_type:
		"rescue", "escort": texture = RESCUE_TEXTURE; target_size = Vector2(52, 52)
		"collect": texture = SALVAGE_TEXTURE; target_size = Vector2(34, 34)
		"sabotage": texture = HOSTILE_TEXTURE; target_size = Vector2(92, 28)
		"destroy_marked": texture = MARKED_TEXTURE; target_size = Vector2(62, 62)
	draw_circle(Vector2.ZERO, maxf(target_size.x, target_size.y) * 0.56, Color("b43b5a", 0.22) if hostile else Color("4dc9b0", 0.18))
	draw_texture_rect(texture, Rect2(-target_size * 0.5, target_size), false, Color("ff8a9e") if hostile else Color.WHITE)
	draw_arc(Vector2.ZERO, maxf(target_size.x, target_size.y) * 0.62, 0.0, TAU, 32, Color("ffda72") if hostile else Color("b5fff1"), 2.0)
