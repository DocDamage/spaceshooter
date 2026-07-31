class_name ProductionPlayer
extends BaseActor2D

var player_index := 0
var ship_definition: ShipDefinition
var weapon_definition: WeaponDefinition
var input_service: GameInputService
var movement_controller: PlayerMovementController
var fire_cooldown := 0.0
var weapon_runtime: WeaponRuntime
var lock_on_controller: LockOnController
var melee_runtime: MeleeRuntime
var spell_runtime: SpellRuntime
var super_runtime: SuperModeRuntime
var progression_profile: ProgressionProfile
var presentation: PresentationActor
var ship_visual: ShipPresentation
var coop_manager: LocalCoopSessionManager
var coop_slot_id: StringName
var player_color := Color.WHITE

func configure(id: StringName, index: int, ship: ShipDefinition, weapon: WeaponDefinition, session_registry: ActorRegistry, session_events: TypedEventBus, game_input: GameInputService) -> void:
	configure_actor(id, &"player", &"players", session_registry, session_events)
	player_index = index
	ship_definition = ship
	weapon_definition = weapon
	input_service = game_input
	health_component.configure(ship.max_health)
	armor_component.configure(ship.armor)
	shield_component.configure(ship.shield_capacity, ship.shield_recharge_delay, ship.shield_recharge_rate)
	hurtbox_component.configure(12.0 * ship.collision_scale)
	hitbox_component.configure(12.0 * ship.collision_scale, 20.0)
	_apply_system_damage_settings()
	var profile := MovementProfile.new()
	profile.maximum_speed = ship.move_speed
	profile.focus_speed = ship.move_speed * 0.48
	profile.boost_speed = ship.move_speed * 1.5
	movement_controller = PlayerMovementController.new()
	movement_controller.name = "PlayerMovementController"
	add_child(movement_controller)
	movement_controller.configure(self, profile)

func configure_combat(pool_manager: ProjectilePoolManager, weapons: Array[WeaponDefinition]) -> void:
	weapon_runtime = WeaponRuntime.new()
	weapon_runtime.name = "WeaponRuntime"
	add_child(weapon_runtime)
	weapon_runtime.configure(self, pool_manager, registry, event_bus)
	weapon_runtime.equip(weapons)
	lock_on_controller = LockOnController.new()
	lock_on_controller.name = "LockOnController"
	add_child(lock_on_controller)
	lock_on_controller.configure(self, registry)
	spell_runtime = SpellRuntime.new()
	spell_runtime.name = "SpellRuntime"
	add_child(spell_runtime)
	spell_runtime.configure(self, pool_manager, event_bus)

func apply_progression(profile: ProgressionProfile, equipment_modifiers: Array[Dictionary] = [], skill_modifiers: Array[Dictionary] = [], temporary_modifiers: Array[Dictionary] = [], status_modifiers: Array[Dictionary] = [], difficulty_modifiers: Dictionary = {}) -> Dictionary:
	if profile == null or ship_definition == null: return {}
	progression_profile = profile
	var base_stats := {&"max_health": float(ship_definition.max_health), &"shield": ship_definition.shield_capacity,
		&"armor": ship_definition.armor, &"move_speed": ship_definition.move_speed, &"damage": 1.0, &"fire_rate": 1.0, &"spell_power": 1.0}
	var effective := StatCalculator.calculate(base_stats, profile.allocated_stats, equipment_modifiers, skill_modifiers, temporary_modifiers, status_modifiers, difficulty_modifiers)
	health_component.configure(float(effective.max_health))
	shield_component.configure(float(effective.shield), ship_definition.shield_recharge_delay, ship_definition.shield_recharge_rate)
	armor_component.configure(float(effective.armor))
	if movement_controller != null and movement_controller.profile != null:
		movement_controller.profile.maximum_speed = float(effective.move_speed)
		movement_controller.profile.focus_speed = float(effective.move_speed) * 0.48
		movement_controller.profile.boost_speed = float(effective.move_speed) * 1.5
	if weapon_runtime != null:
		weapon_runtime.upgrade_levels = profile.weapon_levels.duplicate(true)
		weapon_runtime.global_damage_multiplier = float(effective.damage)
		weapon_runtime.global_fire_rate_multiplier = maxf(0.01, float(effective.fire_rate))
	if spell_runtime != null:
		spell_runtime.upgrade_levels = profile.spell_levels.duplicate(true)
		spell_runtime.global_power_multiplier = maxf(0.0, float(effective.spell_power))
	return effective

func _ready() -> void:
	super()
	collision_layer = 1
	collision_mask = 8
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	collision.shape = shape
	add_child(collision)
	ship_visual = ShipPresentation.new()
	ship_visual.name = "ShipPresentation"
	add_child(ship_visual)
	presentation = PresentationActor.new()
	presentation.name = "PresentationActor"
	add_child(presentation)
	presentation.configure(ship_visual, input_service.get_settings_service() if input_service != null else null)

func _physics_process(delta: float) -> void:
	super(delta)
	if not active:
		return
	var move_input := input_service.get_move_vector(player_index)
	presentation.banking_amount = move_toward(presentation.banking_amount, move_input.x, delta * 5.0)
	presentation.pitch_amount = move_toward(presentation.pitch_amount, move_input.y, delta * 5.0)
	presentation.apply_presentation()
	if input_service.is_action_pressed_for_player(&"boost", player_index):
		movement_controller.set_boost(true)
	elif input_service.is_action_pressed_for_player(&"focus", player_index):
		movement_controller.set_focus(true)
	else:
		movement_controller.state_machine.request(MovementStateMachine.NORMAL)
	movement_controller.simulate(move_input, delta)
	if input_service.is_action_pressed_for_player(&"dash", player_index):
		movement_controller.dash(move_input)
	if input_service.is_action_pressed_for_player(&"barrel_roll", player_index):
		movement_controller.roll()
	if input_service.is_action_pressed_for_player(&"teleport", player_index):
		movement_controller.teleport(move_input)
	if weapon_runtime != null:
		lock_on_controller.update_lock(delta, input_service.get_aim_vector(player_index))
		weapon_runtime.locked_target = lock_on_controller.primary_target()
		var aim := input_service.get_aim_vector(player_index)
		weapon_runtime.set_trigger(input_service.is_fire_pressed(player_index) and movement_controller.state_machine.allows_firing(), Vector2.UP if aim.length_squared() == 0.0 else aim)
		weapon_runtime.tick(delta)
		spell_runtime.tick(delta)
		ship_visual.update_state(move_input, shield_component.current / maxf(shield_component.capacity, 1.0), health_component.current / maxf(health_component.maximum, 1.0), input_service.is_fire_pressed(player_index), super_runtime != null and super_runtime.active, delta)
		if input_service.is_action_just_pressed_for_player(&"next_weapon", player_index):
			weapon_runtime.cycle(1)
		if input_service.is_action_just_pressed_for_player(&"previous_weapon", player_index):
			weapon_runtime.cycle(-1)
	else:
		fire_cooldown = maxf(0.0, fire_cooldown - delta)
		if input_service.is_fire_pressed(player_index) and movement_controller.state_machine.allows_firing() and fire_cooldown <= 0.0:
			fire_cooldown = weapon_definition.cooldown_seconds
			get_parent().spawn_projectile(self)

func receive_damage(packet: DamagePacket) -> DamageResult:
	if input_service != null and input_service.is_assist_enabled(&"invulnerability_assist"):
		var blocked := DamageResult.new()
		blocked.blocked_reason = &"accessibility_assist"
		return blocked
	return super(packet)

func destroy_actor(source_actor_id: StringName) -> void:
	if movement_controller != null:
		movement_controller.state_machine.request(MovementStateMachine.DESTROYED)
	if coop_manager != null and coop_manager.handle_player_defeat(coop_slot_id):
		active = false
		monitoring = false
		return
	super(source_actor_id)

func revive_from_coop(health_fraction := 0.4) -> void:
	health_component.current = maxf(1.0, health_component.maximum * clampf(health_fraction, 0.1, 1.0))
	shield_component.reset()
	active = true
	visible = true
	monitoring = true
	grant_invulnerability(2.0)
	if movement_controller != null: movement_controller.state_machine.request(MovementStateMachine.NORMAL)

func _apply_system_damage_settings() -> void:
	if input_service == null:
		return
	armor_component.system_damage_enabled = bool(input_service.get_gameplay_setting(&"system_damage_enabled", true))
	for subsystem in ArmorComponent.SUBSYSTEMS:
		armor_component.set_subsystem_enabled(subsystem, bool(input_service.get_gameplay_setting(StringName("%s_damage_enabled" % subsystem), true)))
