class_name StageHazard
extends BaseActor2D

var hazard_id: StringName
var hazard_index := 0
var players: Array[Node2D] = []
var projectile_pool: ProjectilePoolManager
var difficulty: DifficultyProfileDefinition
var stage_seed := 0
var elapsed := 0.0
var pulse_elapsed := 0.0
var projectile_sequence := 0
var velocity := Vector2.ZERO

func configure_hazard(id: StringName, index: int, context: Dictionary) -> void:
	hazard_id = id
	hazard_index = index
	players.assign(context.get("players", []))
	projectile_pool = context.get("projectile_pool") as ProjectilePoolManager
	difficulty = context.get("difficulty") as DifficultyProfileDefinition
	stage_seed = int(context.get("stage_seed", 0))
	configure_actor(StringName("%s.%d" % [hazard_id, index]), &"hazard", &"environment", context.get("registry") as ActorRegistry, context.get("event_bus") as TypedEventBus)
	health_component.configure(180.0)
	armor_component.configure(4.0)
	hurtbox_component.configure(24.0)
	var hash_value: int = absi(hash("%s:%d:%d" % [hazard_id, stage_seed, index]))
	position = Vector2(70.0 + float(hash_value % 400), 120.0 + float((hash_value / 401) % 360))
	if _kind() in [&"asteroids", &"debris"]: velocity = Vector2(float((hash_value % 81) - 40), 65.0 + float(hash_value % 55))

func _ready() -> void:
	super()
	collision_layer = 8
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new(); shape.radius = 24.0
	collision.shape = shape
	add_child(collision)
	queue_redraw()

func _physics_process(delta: float) -> void:
	super(delta)
	if not active: return
	elapsed += delta
	pulse_elapsed += delta
	match _kind():
		&"asteroids", &"debris":
			position += velocity * delta
			rotation += delta * (0.45 if hazard_index % 2 == 0 else -0.35)
			if position.y > 1040.0: position.y = -60.0
			if position.x < 30.0 or position.x > 510.0: velocity.x *= -1.0
			if pulse_elapsed >= 0.45: _damage_nearby(42.0, 10.0 if _kind() == &"asteroids" else 6.0); pulse_elapsed = 0.0
		&"ion_storm":
			if pulse_elapsed >= 1.75: _damage_all(3.0, DamagePacket.DamageType.ELECTRIC); pulse_elapsed = 0.0
		&"minefield":
			if pulse_elapsed >= 2.4: _fire(Vector2.DOWN, &"mine", 9.0, 100.0); pulse_elapsed = 0.0
		&"turret_wall", &"orbital_weapon", &"crossfire", &"reactor_arc":
			var period := 1.35 if _kind() in [&"turret_wall", &"crossfire"] else 1.8
			if pulse_elapsed >= period:
				_fire_at_player()
				if _kind() in [&"crossfire", &"reactor_arc"]: _fire(Vector2.DOWN.rotated(0.35 if hazard_index % 2 == 0 else -0.35), &"enemy_bullet", 7.0, 230.0)
				pulse_elapsed = 0.0

func snapshot() -> Dictionary:
	return {"hazard_id": hazard_id, "index": hazard_index, "position": position, "velocity": velocity, "elapsed": elapsed, "health": health_component.current, "active": active}

func restore(data: Dictionary) -> bool:
	if StringName(data.get("hazard_id", "")) != hazard_id or int(data.get("index", -1)) != hazard_index: return false
	position = data.get("position", position)
	velocity = data.get("velocity", velocity)
	elapsed = maxf(0.0, float(data.get("elapsed", 0.0)))
	health_component.current = clampf(float(data.get("health", health_component.maximum)), 0.0, health_component.maximum)
	return true

func _kind() -> StringName:
	return StringName(String(hazard_id).trim_prefix("hazard."))

func _damage_nearby(radius: float, amount: float) -> void:
	for player in players:
		if is_instance_valid(player) and player is BaseActor2D and player.active and global_position.distance_to(player.global_position) <= radius:
			_apply_damage(player, amount, DamagePacket.DamageType.KINETIC)

func _damage_all(amount: float, damage_type: DamagePacket.DamageType) -> void:
	for player in players:
		if is_instance_valid(player) and player is BaseActor2D and player.active: _apply_damage(player, amount, damage_type)

func _apply_damage(player: BaseActor2D, amount: float, damage_type: DamagePacket.DamageType) -> void:
	var packet := DamagePacket.new(amount * (difficulty.health_multiplier if difficulty != null else 1.0), actor_id)
	packet.damage_type = damage_type
	player.receive_damage(packet)

func _fire_at_player() -> void:
	var target: Node2D
	var closest := INF
	for player in players:
		if is_instance_valid(player) and player is BaseActor2D and player.active:
			var distance := global_position.distance_squared_to(player.global_position)
			if distance < closest: closest = distance; target = player
	_fire(global_position.direction_to(target.global_position) if target != null else Vector2.DOWN, &"enemy_bullet", 7.0, 220.0)

func _fire(direction: Vector2, category: StringName, damage: float, speed: float) -> void:
	if projectile_pool == null: return
	projectile_sequence += 1
	var scaled_speed := speed * (difficulty.projectile_speed_multiplier if difficulty != null else 1.0)
	var config := {"actor_id": StringName("projectile.%s.%d" % [actor_id, projectile_sequence]), "source_id": actor_id, "source_ability_id": hazard_id, "damage": damage, "speed": scaled_speed, "team": &"enemies", "direction": direction.normalized(), "registry": registry, "event_bus": event_bus}
	projectile_pool.acquire(category, config, Transform2D(direction.angle() + PI * 0.5, global_position))

func _draw() -> void:
	match _kind():
		&"ion_storm":
			draw_circle(Vector2.ZERO, 150.0, Color(0.25, 0.65, 1.0, 0.08))
			draw_arc(Vector2.ZERO, 105.0, 0.0, TAU, 32, Color(0.55, 0.85, 1.0, 0.4), 3.0)
		&"asteroids":
			draw_colored_polygon(PackedVector2Array([Vector2(-22,-15), Vector2(8,-25), Vector2(27,-4), Vector2(17,23), Vector2(-17,20), Vector2(-28,2)]), Color("8e8178"))
		&"debris":
			draw_rect(Rect2(-24,-10,48,20), Color("7889a5")); draw_line(Vector2(-18,-18), Vector2(20,18), Color("c6d6ec"), 4.0)
		_:
			draw_rect(Rect2(-24,-18,48,36), Color("9b355b")); draw_circle(Vector2.ZERO, 8.0, Color("ffda70"))
