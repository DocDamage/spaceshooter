class_name ProductionProjectile
extends PooledCombatObject

var actor_id: StringName
var source_id: StringName
var source_player_id: StringName
var source_ability_id: StringName
var definition: ProjectileDefinition
var damage := 0.0
var speed := 0.0
var velocity := Vector2.ZERO
var remaining_lifetime := 0.0
var remaining_pierces := 0
var remaining_bounces := 0
var team: StringName
var interaction_tags: Array[StringName] = []
var status_effect_ids: Array[StringName] = []
var target: Node2D
var registry: ActorRegistry
var event_bus: TypedEventBus
var absorbed := false
var visual_texture: Texture2D
var grazed_players: Dictionary = {}
var collision_shape: CollisionShape2D

const DEFAULT_VISUALS := {
	&"player_bullet": "res://assets_runtime/projectiles/projectile_plasma_lance.png",
	&"enemy_bullet": "res://assets_runtime/projectiles/projectile_plasma_orb_01.png",
	&"missile": "res://assets_runtime/projectiles/projectile_enemy_missile.png",
	&"mine": "res://assets_runtime/projectiles/projectile_reactor_core.png",
}

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	collision_shape = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	collision_shape.shape = shape
	add_child(collision_shape)
	area_entered.connect(_on_area_entered)
	queue_redraw()

func configure_from_pool(configuration: Dictionary) -> void:
	actor_id = configuration.get("actor_id", StringName("projectile.pool_%d" % pool_generation))
	source_id = configuration.get("source_id", &"")
	source_player_id = configuration.get("source_player_id", source_id)
	source_ability_id = configuration.get("source_ability_id", &"")
	definition = configuration.get("definition") as ProjectileDefinition
	registry = configuration.get("registry") as ActorRegistry
	event_bus = configuration.get("event_bus") as TypedEventBus
	target = configuration.get("target") as Node2D
	var direction: Vector2 = configuration.get("direction", Vector2.UP)
	status_effect_ids.assign(configuration.get("status_effect_ids", []))
	if definition != null:
		damage = float(configuration.get("damage", definition.damage))
		speed = definition.speed
		remaining_lifetime = definition.lifetime_seconds
		remaining_pierces = definition.pierce_count
		remaining_bounces = definition.bounce_count
		team = definition.team
		interaction_tags.assign(definition.interaction_tags)
		pool_category = definition.pool_category
		visual_texture = load(definition.visual_asset_path) as Texture2D if not definition.visual_asset_path.is_empty() and ResourceLoader.exists(definition.visual_asset_path) else null
	else:
		damage = float(configuration.get("damage", 0.0))
		speed = float(configuration.get("speed", 0.0))
		remaining_lifetime = float(configuration.get("lifetime", 5.0))
		team = configuration.get("team", &"neutral")
		interaction_tags.assign(configuration.get("interaction_tags", []))
		var configured_visual := String(configuration.get("visual_asset_path", ""))
		visual_texture = load(configured_visual) as Texture2D if not configured_visual.is_empty() and ResourceLoader.exists(configured_visual) else null
	if visual_texture == null:
		var fallback_path := String(DEFAULT_VISUALS.get(pool_category, ""))
		if not fallback_path.is_empty() and ResourceLoader.exists(fallback_path):
			visual_texture = load(fallback_path) as Texture2D
	if visual_texture == null and ResourceLoader.exists("res://assets_runtime/projectiles/projectile_plasma_orb_01.png"):
		visual_texture = load("res://assets_runtime/projectiles/projectile_plasma_orb_01.png") as Texture2D
	velocity = direction.normalized() * speed
	absorbed = false
	grazed_players.clear()
	_apply_collision_radius()
	_apply_collision_team()
	queue_redraw()

func activate_from_pool(spawn_transform := Transform2D.IDENTITY) -> bool:
	var activated := super.activate_from_pool(spawn_transform)
	if activated and registry != null and not actor_id.is_empty():
		registry.register_actor(actor_id, &"projectile", self)
	return activated

func reset_pool_object() -> void:
	if registry != null and not actor_id.is_empty():
		registry.unregister_actor(actor_id)
	super.reset_pool_object()
	actor_id = &""
	source_id = &""
	source_player_id = &""
	source_ability_id = &""
	definition = null
	damage = 0.0
	speed = 0.0
	velocity = Vector2.ZERO
	remaining_lifetime = 0.0
	remaining_pierces = 0
	remaining_bounces = 0
	team = &""
	interaction_tags.clear()
	status_effect_ids.clear()
	target = null
	registry = null
	event_bus = null
	absorbed = false
	grazed_players.clear()
	visual_texture = null
	collision_layer = 0
	collision_mask = 0

func validate_reset() -> PackedStringArray:
	var errors := super.validate_reset()
	if not actor_id.is_empty() or definition != null or velocity != Vector2.ZERO or remaining_lifetime != 0.0 or not interaction_tags.is_empty():
		errors.append("projectile gameplay state was not reset")
	return errors

func _physics_process(delta: float) -> void:
	if not pool_active:
		return
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0:
		deactivate_to_pool()
		return
	if definition != null:
		speed = maxf(0.0, speed + definition.acceleration * delta)
		if target != null and is_instance_valid(target) and definition.homing_strength > 0.0:
			var desired := global_position.direction_to(target.global_position)
			var max_turn := deg_to_rad(definition.turn_rate_degrees) * delta
			velocity = velocity.normalized().rotated(clampf(velocity.angle_to(desired), -max_turn, max_turn)) * speed
		else:
			velocity = velocity.normalized() * speed
	position += velocity * delta

func reflect(new_owner_id: StringName, new_team: StringName, direction := Vector2.ZERO) -> void:
	source_id = new_owner_id
	source_player_id = new_owner_id
	team = new_team
	velocity = (-velocity if direction == Vector2.ZERO else direction.normalized() * speed)
	absorbed = false
	_apply_collision_team()

func absorb() -> void:
	absorbed = true
	deactivate_to_pool()

func try_graze(player_id: StringName) -> bool:
	if not pool_active or absorbed or team != &"enemies" or player_id.is_empty() or grazed_players.has(player_id): return false
	grazed_players[player_id] = true
	return true

func clear_graze_player(player_id: StringName) -> void:
	if definition != null and definition.allow_regraze: grazed_players.erase(player_id)

func graze_value() -> int:
	return definition.graze_value if definition != null else 1

func can_convert() -> bool:
	return pool_active and not absorbed and team == &"enemies" and ((definition != null and definition.cancel_class == &"eligible") or &"cancelable" in interaction_tags)

func flux_value() -> int:
	return definition.flux_value if definition != null else maxi(1, roundi(damage * 0.1))

func convert_to_flux() -> void:
	if not can_convert(): return
	absorbed = true
	if event_bus != null: event_bus.publish(ProjectileInteractionEvent.new(source_id if not source_id.is_empty() else actor_id, actor_id, &"flux_convert"))
	deactivate_to_pool()

func _on_area_entered(area: Area2D) -> void:
	if not pool_active or absorbed or not (area is BaseActor2D) or area.faction == team:
		return
	if event_bus != null:
		event_bus.publish(ProjectileInteractionEvent.new(actor_id, area.actor_id, &"hit"))
	var packet := DamagePacket.new(damage, source_id)
	packet.source_player_id = source_player_id
	packet.source_ability_id = source_ability_id
	packet.chain_attribution = source_player_id
	packet.score_attribution = source_player_id
	for status_id in status_effect_ids:
		packet.status_applications.append(StatusApplication.new(status_id, source_id, 2.0))
	area.receive_damage(packet)
	if remaining_pierces > 0:
		remaining_pierces -= 1
	else:
		# Area overlap signals are emitted while physics is flushing queries. Deferring
		# the pool transition avoids mutating monitoring/collision state in that callback.
		absorbed = true
		call_deferred("deactivate_to_pool")

func _apply_collision_team() -> void:
	if team == &"players":
		collision_layer = 2
		collision_mask = 4
	elif team == &"enemies":
		collision_layer = 8
		collision_mask = 1
	else:
		collision_layer = 0
		collision_mask = 0

func _apply_collision_radius() -> void:
	if collision_shape == null: return
	var shape := collision_shape.shape as CircleShape2D
	if shape == null:
		shape = CircleShape2D.new()
		collision_shape.shape = shape
	shape.radius = definition.collision_radius if definition != null else 5.0

func _draw() -> void:
	var radius := definition.collision_radius if definition != null else 5.0
	var color := Color("69efff") if team == &"players" else Color("ffd36d") if can_convert() else Color("ff6688")
	draw_circle(Vector2.ZERO, radius + 1.5, Color(color, 0.28))
	if visual_texture != null:
		var size := visual_texture.get_size()
		var scale_factor := maxf(1.0, radius * 2.0 / maxf(size.x, size.y))
		size *= scale_factor
		draw_texture_rect(visual_texture, Rect2(-size * 0.5, size), false, color)
	else:
		draw_circle(Vector2.ZERO, radius, color)
