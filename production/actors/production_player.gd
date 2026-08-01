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
var equipped_spells: Array[SpellDefinition] = []
var projectile_pool: ProjectilePoolManager
var progression_profile: ProgressionProfile
var presentation: PresentationActor
var ship_visual: ShipPresentation
var coop_manager: LocalCoopSessionManager
var coop_slot_id: StringName
var player_color := Color.WHITE
var shield_guard_active := false
var _focus_toggled := false
var _base_weapon_damage_multiplier := 1.0
var _wingman_mode_index := 0
var damage_collision: CollisionShape2D
var graze_area: Area2D
var graze_collision: CollisionShape2D
var rapid_weapon_index := 0
var focus_weapon_index := -1
func configure(id: StringName, index: int, ship: ShipDefinition, weapon: WeaponDefinition, session_registry: ActorRegistry, session_events: TypedEventBus, game_input: GameInputService) -> void:
	configure_actor(id, &"player", &"players", session_registry, session_events)
	player_index = index
	ship_definition = ship
	weapon_definition = weapon
	input_service = game_input
	health_component.configure(ship.max_health)
	armor_component.configure(ship.armor)
	shield_component.configure(ship.shield_capacity, ship.shield_recharge_delay, ship.shield_recharge_rate)
	hurtbox_component.configure(ship.hitbox_radius)
	hitbox_component.configure(ship.hitbox_radius, 20.0)
	_apply_control_collision()
	_apply_system_damage_settings()
	var profile := MovementProfile.new()
	profile.maximum_speed = ship.arcade_normal_speed()
	profile.focus_speed = ship.arcade_focus_speed()
	profile.boost_speed = profile.maximum_speed * 1.5
	profile.regulation_direct = ship.regulation_controls
	movement_controller = PlayerMovementController.new()
	movement_controller.name = "PlayerMovementController"
	add_child(movement_controller)
	movement_controller.configure(self, profile)
func configure_combat(pool_manager: ProjectilePoolManager, weapons: Array[WeaponDefinition], spells: Array[SpellDefinition] = [], melee_definition: MeleeDefinition = null, super_definition: SuperModeDefinition = null, conversion_service: BulletConversionService = null) -> void:
	projectile_pool = pool_manager
	equipped_spells.assign(spells)
	weapon_runtime = WeaponRuntime.new()
	weapon_runtime.name = "WeaponRuntime"
	add_child(weapon_runtime)
	weapon_runtime.configure(self, pool_manager, registry, event_bus)
	weapon_runtime.equip(weapons)
	rapid_weapon_index = _weapon_index_for(ship_definition.shot_pattern_id, 0)
	focus_weapon_index = _weapon_index_for(ship_definition.focus_pattern_id, rapid_weapon_index)
	lock_on_controller = LockOnController.new()
	lock_on_controller.name = "LockOnController"
	add_child(lock_on_controller)
	lock_on_controller.configure(self, registry)
	spell_runtime = SpellRuntime.new()
	spell_runtime.name = "SpellRuntime"
	add_child(spell_runtime)
	spell_runtime.configure(self, pool_manager, event_bus)
	if melee_definition != null:
		melee_runtime = MeleeRuntime.new()
		melee_runtime.name = "MeleeRuntime"
		add_child(melee_runtime)
		melee_runtime.configure(self, melee_definition, event_bus)
	if super_definition != null:
		super_runtime = SuperModeRuntime.new()
		super_runtime.name = "SuperModeRuntime"
		add_child(super_runtime)
		super_runtime.configure(self, weapon_runtime, super_definition, conversion_service)
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
		var normal_speed := ship_definition.arcade_normal_speed() if ship_definition.regulation_controls else float(effective.move_speed)
		movement_controller.profile.maximum_speed = normal_speed
		movement_controller.profile.focus_speed = ship_definition.arcade_focus_speed() if ship_definition.regulation_controls else normal_speed * 0.48
		movement_controller.profile.boost_speed = normal_speed * 1.5
	if weapon_runtime != null:
		weapon_runtime.upgrade_levels = profile.weapon_levels.duplicate(true)
		_base_weapon_damage_multiplier = float(effective.damage)
		weapon_runtime.global_damage_multiplier = _base_weapon_damage_multiplier
		weapon_runtime.global_fire_rate_multiplier = maxf(0.01, float(effective.fire_rate))
	if spell_runtime != null:
		spell_runtime.upgrade_levels = profile.spell_levels.duplicate(true)
		spell_runtime.global_power_multiplier = maxf(0.0, float(effective.spell_power))
	return effective
func _ready() -> void:
	super()
	collision_layer = 1
	collision_mask = 8
	damage_collision = CollisionShape2D.new()
	damage_collision.name = "DamageHitbox"
	add_child(damage_collision)
	graze_area = Area2D.new()
	graze_area.name = "GrazeRing"
	graze_area.collision_layer = 0
	graze_area.collision_mask = 8
	graze_area.monitoring = false # Phase 2 owns graze events; Phase 1 establishes the honest geometry.
	graze_collision = CollisionShape2D.new()
	graze_area.add_child(graze_collision)
	add_child(graze_area)
	_apply_control_collision()
	ship_visual = ShipPresentation.new()
	ship_visual.name = "ShipPresentation"
	add_child(ship_visual)
	ship_visual.configure_visual(ship_definition.visual_asset_path, ship_definition.visual_scale, player_color)
	ship_visual.configure_arcade_feedback(ship_definition.hitbox_radius, ship_definition.graze_radius)
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
	var focus_toggle := bool(input_service.get_gameplay_setting(&"focus_toggle", false))
	if focus_toggle and input_service.is_action_just_pressed_for_player(&"focus_beam", player_index): _focus_toggled = not _focus_toggled
	var focus_active := _focus_toggled if focus_toggle else input_service.is_focus_beam_pressed(player_index)
	if not ship_definition.regulation_controls and input_service.is_action_pressed_for_player(&"boost", player_index):
		movement_controller.set_boost(true)
	elif focus_active:
		movement_controller.set_focus(true)
	else:
		movement_controller.state_machine.request(MovementStateMachine.NORMAL)
	movement_controller.simulate(move_input, delta)
	if not ship_definition.regulation_controls:
		if input_service.is_action_just_pressed_for_player(&"dash", player_index): movement_controller.dash(move_input)
		if input_service.is_action_just_pressed_for_player(&"barrel_roll", player_index): movement_controller.roll()
		if input_service.is_action_just_pressed_for_player(&"teleport", player_index): movement_controller.teleport(move_input)
	var shield_toggle := bool(input_service.get_gameplay_setting(&"shield_toggle", false))
	if shield_toggle:
		if input_service.is_action_just_pressed_for_player(&"shield", player_index): shield_guard_active = not shield_guard_active
	else:
		shield_guard_active = input_service.is_action_pressed_for_player(&"shield", player_index)
	if weapon_runtime != null:
		lock_on_controller.update_lock(delta, input_service.get_aim_vector(player_index))
		weapon_runtime.locked_target = null if ship_definition.regulation_controls else lock_on_controller.primary_target()
		var aim := input_service.get_aim_vector(player_index)
		var fire_mode := ArcadeInputRules.select_fire_mode(input_service.is_fire_pressed(player_index), focus_active)
		_select_arcade_weapon(fire_mode)
		weapon_runtime.set_trigger(not fire_mode.is_empty() and movement_controller.state_machine.allows_firing(), Vector2.UP if ship_definition.regulation_controls or aim.length_squared() == 0.0 else aim)
		weapon_runtime.tick(delta)
		spell_runtime.tick(delta)
		if melee_runtime != null: melee_runtime.tick(delta)
		if super_runtime != null:
			super_runtime.tick(delta)
			weapon_runtime.global_damage_multiplier = _base_weapon_damage_multiplier * super_runtime.damage_multiplier()
		ship_visual.update_state(move_input, shield_component.current / maxf(shield_component.capacity, 1.0), health_component.current / maxf(health_component.maximum, 1.0), not fire_mode.is_empty(), super_runtime != null and super_runtime.active, focus_active, bool(input_service.get_gameplay_setting(&"always_show_hitbox", false)), delta)
		var fire_direction := Vector2.UP if aim.length_squared() == 0.0 else aim
		if input_service.is_action_just_pressed_for_player(&"element", player_index) and not equipped_spells.is_empty():
			var element := get_node_or_null("ElementRuntime") as ElementRuntime
			if element != null: element.activate(_combat_targets(), _hostile_projectiles())
			else: spell_runtime.cast(equipped_spells[0], _combat_targets(), _hostile_projectiles())
		if not ship_definition.regulation_controls and input_service.is_action_just_pressed_for_player(&"secondary_fire", player_index): weapon_runtime.fire_slot(1, fire_direction)
		if not ship_definition.regulation_controls and input_service.is_action_just_pressed_for_player(&"heavy_weapon", player_index): weapon_runtime.fire_slot(2, fire_direction)
		if not ship_definition.regulation_controls and melee_runtime != null and input_service.is_action_just_pressed_for_player(&"melee", player_index): melee_runtime.attack(_combat_targets(), fire_direction)
		if not ship_definition.regulation_controls and melee_runtime != null and input_service.is_action_just_pressed_for_player(&"parry", player_index): melee_runtime.begin_parry()
		if melee_runtime != null and melee_runtime.parry_remaining > 0.0:
			for projectile in _hostile_projectiles():
				if melee_runtime.try_parry(projectile): break
		if super_runtime != null and input_service.consume_buffered_action(&"overdrive", player_index):
			if super_runtime.active: super_runtime.cancel()
			else: super_runtime.activate()
		var bomb := get_node_or_null("ArcadeBombRuntime") as ArcadeBombRuntime
		if bomb != null and input_service.consume_buffered_action(&"bomb", player_index): bomb.activate(self)
		if not ship_definition.regulation_controls:
			if input_service.is_action_just_pressed_for_player(&"wingman_command", player_index): _issue_wingman_command(false)
			if input_service.is_action_just_pressed_for_player(&"wingman_command_wheel", player_index): _issue_wingman_command(true)
			if input_service.is_action_just_pressed_for_player(&"next_weapon", player_index): weapon_runtime.cycle(1)
			if input_service.is_action_just_pressed_for_player(&"previous_weapon", player_index): weapon_runtime.cycle(-1)
	else:
		fire_cooldown = maxf(0.0, fire_cooldown - delta)
		if input_service.is_fire_pressed(player_index) and movement_controller.state_machine.allows_firing() and fire_cooldown <= 0.0:
			fire_cooldown = weapon_definition.cooldown_seconds
			get_parent().spawn_projectile(self)
func receive_damage(packet: DamagePacket) -> DamageResult:
	var bomb := get_node_or_null("ArcadeBombRuntime") as ArcadeBombRuntime
	if input_service != null and bool(input_service.get_gameplay_setting(&"story_auto_bomb", false)) and bomb != null and not is_invulnerable() and packet.base_damage > shield_component.current:
		bomb.activate(self)
	if input_service != null and input_service.is_assist_enabled(&"invulnerability_assist"):
		var blocked := DamageResult.new()
		blocked.blocked_reason = &"accessibility_assist"
		return blocked
	if shield_guard_active and shield_component.current > 0.0:
		var guarded := packet.duplicate_packet()
		guarded.base_damage *= 0.55
		return super(guarded)
	return super(packet)

func grant_super_charge(amount: float) -> void:
	if super_runtime != null: super_runtime.add_charge(amount)
func grant_temporary_drop(category: StringName, amount: int) -> void:
	match category:
		&"healing": health_component.heal(maxi(1, amount) * 20.0)
		&"temporary_weapon_power":
			_base_weapon_damage_multiplier *= 1.0 + 0.05 * float(maxi(1, amount))
			if weapon_runtime != null: weapon_runtime.global_damage_multiplier = _base_weapon_damage_multiplier
func combat_loadout_snapshot() -> Dictionary:
	var weapon_ids: Array[StringName] = []
	if weapon_runtime != null:
		for weapon in weapon_runtime.inventory:
			if weapon != null: weapon_ids.append(weapon.stable_id)
	var spell_ids: Array[StringName] = []
	for spell in equipped_spells:
		if spell != null: spell_ids.append(spell.stable_id)
	return {"weapons": weapon_ids, "spells": spell_ids, "melee": melee_runtime.definition.stable_id if melee_runtime != null else &"", "super": super_runtime.definition.stable_id if super_runtime != null else &""}
func arcade_metrics() -> Dictionary:
	return {&"velocity": movement_controller.velocity if movement_controller != null else Vector2.ZERO, &"hitbox_radius": hurtbox_component.radius, &"graze_radius": ship_definition.graze_radius}

func _weapon_index_for(weapon_id: StringName, fallback: int) -> int:
	if weapon_runtime == null or weapon_id.is_empty():
		return fallback
	for index in weapon_runtime.inventory.size():
		if weapon_runtime.inventory[index] != null and weapon_runtime.inventory[index].stable_id == weapon_id:
			return index
	return fallback
func _select_arcade_weapon(fire_mode: StringName) -> void:
	if weapon_runtime == null or fire_mode.is_empty():
		return
	weapon_runtime.switch_to(focus_weapon_index if fire_mode == &"focus" else rapid_weapon_index)

func _apply_control_collision() -> void:
	if damage_collision != null:
		var damage_shape := damage_collision.shape as CircleShape2D
		if damage_shape == null:
			damage_shape = CircleShape2D.new()
			damage_collision.shape = damage_shape
		damage_shape.radius = hurtbox_component.radius
	if graze_collision != null:
		var graze_shape := graze_collision.shape as CircleShape2D
		if graze_shape == null:
			graze_shape = CircleShape2D.new()
			graze_collision.shape = graze_shape
		graze_shape.radius = ship_definition.graze_radius
func _combat_targets() -> Array[Node]:
	var targets: Array[Node] = []
	if registry == null: return targets
	targets.append_array(registry.get_actors(&"enemy"))
	targets.append_array(registry.get_actors(&"miniboss"))
	targets.append_array(registry.get_actors(&"boss"))
	for objective in registry.get_actors(&"objective"):
		if objective is BaseActor2D and objective.faction == &"enemies": targets.append(objective)
	return targets
func _hostile_projectiles() -> Array[ProductionProjectile]:
	var result: Array[ProductionProjectile] = []
	if projectile_pool == null: return result
	for category in [&"enemy_bullet", &"missile", &"mine"]:
		for object in projectile_pool.get_active_objects(category):
			if object is ProductionProjectile and object.team != faction: result.append(object)
	return result
func _issue_wingman_command(use_special: bool) -> void:
	if registry == null: return
	var modes := [&"attack", &"defend", &"focus", &"intercept"]
	for actor in registry.get_actors(&"wingman"):
		if actor is WingmanRuntime:
			if use_special: actor.use_special()
			else: actor.issue_command(modes[_wingman_mode_index % modes.size()])
	if not use_special: _wingman_mode_index = (_wingman_mode_index + 1) % modes.size()

func destroy_actor(source_actor_id: StringName) -> void:
	if movement_controller != null: movement_controller.state_machine.request(MovementStateMachine.DESTROYED)
	if coop_manager != null and coop_manager.handle_player_defeat(coop_slot_id):
		active = false; monitoring = false
		return
	super(source_actor_id)

func revive_from_coop(health_fraction := 0.4) -> void:
	health_component.current = maxf(1.0, health_component.maximum * clampf(health_fraction, 0.1, 1.0))
	shield_component.reset(); active = true; visible = true; monitoring = true
	grant_invulnerability(2.0)
	if movement_controller != null: movement_controller.state_machine.request(MovementStateMachine.NORMAL)

func _apply_system_damage_settings() -> void:
	if input_service == null:
		return
	armor_component.system_damage_enabled = bool(input_service.get_gameplay_setting(&"system_damage_enabled", true))
	for subsystem in ArmorComponent.SUBSYSTEMS:
		armor_component.set_subsystem_enabled(subsystem, bool(input_service.get_gameplay_setting(StringName("%s_damage_enabled" % subsystem), true)))
