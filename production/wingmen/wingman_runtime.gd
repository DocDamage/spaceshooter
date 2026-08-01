class_name WingmanRuntime
extends BaseActor2D

signal command_changed(mode: StringName, target_id: StringName)
signal special_used(ability_id: StringName)

const MODES := [&"attack", &"defend", &"focus", &"intercept", &"hold", &"retreat", &"use_special"]

var definition: WingmanDefinition
var actor_slot: ActorSlot
var command_mode: StringName = &"defend"
var command_target_id: StringName
var command_cooldown_remaining := 0.0
var special_cooldown_remaining := 0.0
var respawn_generation := 0
var desired_position := Vector2.ZERO
var velocity := Vector2.ZERO
var leader: ProductionPlayer
var weapon_runtime: WeaponRuntime
var projectile_pool: ProjectilePoolManager
var ship_definition: ShipDefinition
var ship_visual: ShipPresentation

func configure_wingman(source: WingmanDefinition, slot: ActorSlot, session_registry: ActorRegistry, session_events: TypedEventBus) -> bool:
	if source == null or slot == null: return false
	definition = source; actor_slot = slot; actor_slot.actor = self
	configure_actor(slot.slot_id, &"wingman", &"players", session_registry, session_events)
	health_component.configure(float(source.ai_profile.get("health", 100.0)))
	hurtbox_component.configure(10.0)
	return true

func configure_combat_context(player_leader: ProductionPlayer, ship: ShipDefinition, weapon: WeaponDefinition, pool: ProjectilePoolManager) -> void:
	leader = player_leader; ship_definition = ship; projectile_pool = pool
	if ship != null:
		health_component.configure(float(source_health(ship)))
		armor_component.configure(ship.armor)
		shield_component.configure(ship.shield_capacity, ship.shield_recharge_delay, ship.shield_recharge_rate)
	if weapon != null and pool != null:
		weapon_runtime = WeaponRuntime.new(); weapon_runtime.name = "WeaponRuntime"; add_child(weapon_runtime)
		weapon_runtime.configure(self, pool, registry, event_bus)
		weapon_runtime.equip([weapon])

func _ready() -> void:
	super._ready()
	collision_layer = 1; collision_mask = 8
	var collision := CollisionShape2D.new(); var shape := CircleShape2D.new(); shape.radius = 10.0; collision.shape = shape; add_child(collision)
	ship_visual = ShipPresentation.new(); ship_visual.name = "ShipPresentation"; add_child(ship_visual)
	if ship_definition != null: ship_visual.configure_visual(ship_definition.visual_asset_path, ship_definition.visual_scale * 0.82, Color(0.75, 0.9, 1.0))

func _physics_process(delta: float) -> void:
	super(delta)
	command_cooldown_remaining = maxf(0.0, command_cooldown_remaining - delta)
	special_cooldown_remaining = maxf(0.0, special_cooldown_remaining - delta)
	if active and actor_slot != null and actor_slot.controller_kind == &"ai": _tick_ai(delta)
	if weapon_runtime != null:
		var target := _target_actor()
		var should_fire := command_mode in [&"attack", &"focus", &"intercept"] and target != null
		weapon_runtime.locked_target = target
		weapon_runtime.set_trigger(should_fire, global_position.direction_to(target.global_position) if target != null else Vector2.UP)
		weapon_runtime.tick(delta)
	if ship_visual != null: ship_visual.update_state(velocity.normalized(), shield_component.current / maxf(1.0, shield_component.capacity), health_component.current / maxf(1.0, health_component.maximum), weapon_runtime != null and weapon_runtime.trigger_held, false, false, false, delta)

func issue_command(mode: StringName, target_id: StringName = &"") -> bool:
	if definition == null or mode not in MODES or command_cooldown_remaining > 0.0: return false
	if mode == &"use_special": return use_special()
	command_mode = mode; command_target_id = target_id; command_cooldown_remaining = definition.command_cooldown
	command_changed.emit(mode, target_id)
	return true

func use_special() -> bool:
	if definition == null or special_cooldown_remaining > 0.0: return false
	special_cooldown_remaining = definition.special_cooldown
	command_cooldown_remaining = definition.command_cooldown
	special_used.emit(definition.special_ability_id)
	if is_instance_valid(leader):
		leader.grant_invulnerability(1.5)
		leader.shield_component.current = minf(leader.shield_component.capacity, leader.shield_component.current + 25.0)
	return true

func on_player_respawn(player_position: Vector2) -> void:
	respawn_generation += 1
	position = player_position + Vector2(80.0, 40.0)
	if not active: spawn_actor()
	grant_invulnerability(2.0)
	command_mode = &"defend"

func handoff_to_human(profile_id: StringName) -> void:
	if actor_slot != null: actor_slot.replace_controller(&"human", profile_id)

func handoff_to_ai() -> void:
	if actor_slot != null: actor_slot.replace_controller(&"ai")

func snapshot() -> Dictionary:
	return {"slot_id": actor_slot.slot_id if actor_slot else &"", "ship_id": actor_slot.ship_id if actor_slot else &"", "controller_kind": actor_slot.controller_kind if actor_slot else &"ai", "profile_id": actor_slot.profile_id if actor_slot else &"", "command_mode": command_mode, "command_target_id": command_target_id, "command_cooldown": command_cooldown_remaining, "special_cooldown": special_cooldown_remaining, "position": position, "health": health_component.current, "respawn_generation": respawn_generation}

func restore(state: Dictionary) -> void:
	command_mode = StringName(state.get("command_mode", "defend")); command_target_id = StringName(state.get("command_target_id", ""))
	command_cooldown_remaining = maxf(0.0, float(state.get("command_cooldown", 0.0))); special_cooldown_remaining = maxf(0.0, float(state.get("special_cooldown", 0.0)))
	position = state.get("position", position); health_component.current = clampf(float(state.get("health", health_component.maximum)), 0.0, health_component.maximum)
	respawn_generation = maxi(0, int(state.get("respawn_generation", 0)))
	if actor_slot != null: actor_slot.replace_controller(StringName(state.get("controller_kind", "ai")), StringName(state.get("profile_id", "")))

func _tick_ai(delta: float) -> void:
	if not is_instance_valid(leader): return
	var offset: Vector2 = definition.ai_profile.get("formation_offset", Vector2(90, 70))
	var target := _target_actor()
	match command_mode:
		&"hold": velocity = Vector2.ZERO
		&"retreat": desired_position = leader.position + Vector2(0, 140); velocity = position.direction_to(desired_position) * 180.0
		&"defend": desired_position = leader.position + offset; velocity = position.direction_to(desired_position) * float(definition.ai_profile.get("speed", 180.0))
		&"attack": desired_position = target.position + Vector2(0, 170) if target != null else leader.position + offset; velocity = position.direction_to(desired_position) * float(definition.ai_profile.get("speed", 220.0))
		&"focus": desired_position = leader.position - offset * Vector2(0.65, -0.45); velocity = position.direction_to(desired_position) * float(definition.ai_profile.get("speed", 205.0))
		&"intercept": desired_position = target.position + Vector2(0, 120) if target != null else leader.position + offset; velocity = position.direction_to(desired_position) * float(definition.ai_profile.get("speed", 240.0))
	position += velocity * delta
	position.x = clampf(position.x, 24.0, 516.0); position.y = clampf(position.y, 100.0, 920.0)

func _target_actor() -> BaseActor2D:
	if registry == null: return null
	if not command_target_id.is_empty():
		var commanded := registry.get_actor(command_target_id)
		if commanded is BaseActor2D and commanded.active: return commanded
	var candidates := registry.get_actors(&"enemy") + registry.get_actors(&"miniboss") + registry.get_actors(&"boss")
	var best: BaseActor2D
	var best_distance := INF
	for candidate in candidates:
		if candidate is BaseActor2D and candidate.active:
			var distance := global_position.distance_squared_to(candidate.global_position)
			if distance < best_distance: best = candidate; best_distance = distance
	return best

func source_health(ship: ShipDefinition) -> float:
	return maxf(float(ship.max_health) * 0.75, float(definition.ai_profile.get("health", 100.0)))
