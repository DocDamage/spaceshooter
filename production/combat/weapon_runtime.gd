class_name WeaponRuntime
extends Node

signal fired(weapon_id: StringName, projectile_count: int)
signal dry_fired(weapon_id: StringName, reason: StringName)
signal weapon_changed(previous_id: StringName, current_id: StringName)
signal recoil_requested(strength: float)

var owner_actor: BaseActor2D
var pool_manager: ProjectilePoolManager
var registry: ActorRegistry
var event_bus: TypedEventBus
var inventory: Array[WeaponDefinition] = []
var current_index := -1
var upgrade_levels: Dictionary = {}
var global_damage_multiplier := 1.0
var global_fire_rate_multiplier := 1.0
var energy := 100.0
var maximum_energy := 100.0
var energy_recharge := 15.0
var trigger_held := false
var trigger_was_held := false
var aim_direction := Vector2.UP
var locked_target: Node2D
var _states: Dictionary = {}
var _projectile_sequence := 0
var _fallback_projectiles: Dictionary = {}

func configure(actor: BaseActor2D, manager: ProjectilePoolManager, session_registry: ActorRegistry, session_events: TypedEventBus) -> void:
	owner_actor = actor
	pool_manager = manager
	registry = session_registry
	event_bus = session_events

func equip(definitions: Array[WeaponDefinition], starting_index := 0) -> bool:
	inventory.assign(definitions)
	for definition in inventory:
		if definition != null and not _states.has(definition.stable_id):
			_states[definition.stable_id] = _default_state(definition)
	if inventory.is_empty():
		current_index = -1
		return false
	current_index = clampi(starting_index, 0, inventory.size() - 1)
	return true

func add_weapon(definition: WeaponDefinition) -> int:
	if definition == null:
		return -1
	var existing := inventory.find(definition)
	if existing >= 0:
		return existing
	inventory.append(definition)
	_states[definition.stable_id] = _default_state(definition)
	return inventory.size() - 1

func current_weapon() -> WeaponDefinition:
	return inventory[current_index] if current_index >= 0 and current_index < inventory.size() else null

func switch_to(index: int) -> bool:
	if index < 0 or index >= inventory.size() or index == current_index:
		return false
	var previous := current_weapon()
	current_index = index
	weapon_changed.emit(previous.stable_id if previous else &"", current_weapon().stable_id)
	return true

func cycle(direction: int) -> bool:
	if inventory.size() < 2:
		return false
	return switch_to(posmod(current_index + direction, inventory.size()))

func set_trigger(pressed: bool, direction := Vector2.UP) -> void:
	trigger_held = pressed
	if direction.length_squared() > 0.0:
		aim_direction = direction.normalized()

func fire_slot(index: int, direction := Vector2.UP, charge_ratio := 1.0) -> bool:
	if index < 0 or index >= inventory.size(): return false
	var weapon := inventory[index]
	if weapon == null: return false
	if direction.length_squared() > 0.0: aim_direction = direction.normalized()
	var state: Dictionary = _states[weapon.stable_id]
	var fired_now := _fire(weapon, state, clampf(charge_ratio, 0.1, 1.0))
	_states[weapon.stable_id] = state
	return fired_now

func tick(delta: float) -> void:
	energy = minf(maximum_energy, energy + energy_recharge * delta)
	for weapon_id in _states:
		var state: Dictionary = _states[weapon_id]
		state.cooldown = maxf(0.0, float(state.cooldown) - delta)
		state.burst_timer = maxf(0.0, float(state.burst_timer) - delta)
		state.reload_timer = maxf(0.0, float(state.reload_timer) - delta)
		var definition := _find_weapon(weapon_id)
		if definition != null:
			state.heat = maxf(0.0, float(state.heat) - definition.heat_dissipation_per_second * delta)
			if state.reload_timer <= 0.0 and definition.magazine_size > 0 and state.ammo <= 0:
				state.ammo = definition.magazine_size
		_states[weapon_id] = state
	var weapon := current_weapon()
	if weapon == null:
		trigger_was_held = trigger_held
		return
	var state: Dictionary = _states[weapon.stable_id]
	if trigger_held and weapon.trigger_mode == WeaponDefinition.TriggerMode.CHARGE:
		state.charge = minf(weapon.maximum_charge_seconds, float(state.charge) + delta)
	elif not trigger_held and trigger_was_held and weapon.trigger_mode == WeaponDefinition.TriggerMode.CHARGE:
		if state.charge >= weapon.minimum_charge_seconds:
			_fire(weapon, state, state.charge / maxf(weapon.maximum_charge_seconds, 0.001))
		state.charge = 0.0
	elif _should_fire(weapon, state):
		_fire(weapon, state)
	if int(state.burst_remaining) > 0 and state.burst_timer <= 0.0:
		_spawn_volley(weapon, state, 1.0)
		state.burst_remaining -= 1
		state.burst_timer = weapon.burst_interval
	_states[weapon.stable_id] = state
	trigger_was_held = trigger_held

func get_state(weapon_id: StringName) -> Dictionary:
	return _states.get(weapon_id, {}).duplicate(true)

func get_effective_spec(weapon: WeaponDefinition) -> Dictionary:
	if weapon == null: return {}
	var level: int = clampi(int(upgrade_levels.get(weapon.stable_id, 1)), 1, weapon.maximum_upgrade_level)
	var steps := level - 1
	return {"level": level, "damage": weapon.damage * (1.0 + float(steps) * weapon.damage_per_upgrade) * maxf(0.0, global_damage_multiplier),
		"cooldown": weapon.cooldown_seconds / ((1.0 + float(steps) * weapon.fire_rate_per_upgrade) * maxf(0.01, global_fire_rate_multiplier)),
		"projectile_count": weapon.projectile_count + (steps / maxi(1, weapon.projectile_count_upgrade_interval)),
		"spread_degrees": maxf(0.0, weapon.spread_degrees + float(steps) * weapon.spread_per_upgrade),
		"penetration": steps * weapon.penetration_per_upgrade,
		"status_chance": clampf(float(steps) * weapon.status_chance_per_upgrade, 0.0, 1.0),
		"visual_intensity": 1.0 + float(steps) * weapon.visual_intensity_per_upgrade}

func _should_fire(weapon: WeaponDefinition, state: Dictionary) -> bool:
	if not trigger_held:
		return false
	if weapon.trigger_mode == WeaponDefinition.TriggerMode.SEMI_AUTOMATIC and trigger_was_held:
		return false
	return weapon.trigger_mode != WeaponDefinition.TriggerMode.CHARGE and state.cooldown <= 0.0 and state.reload_timer <= 0.0

func _fire(weapon: WeaponDefinition, state: Dictionary, charge_ratio := 1.0) -> bool:
	if state.cooldown > 0.0 or state.reload_timer > 0.0:
		return false
	if state.heat + weapon.heat_per_shot > weapon.maximum_heat:
		dry_fired.emit(weapon.stable_id, &"overheated")
		return false
	if energy < weapon.energy_cost:
		dry_fired.emit(weapon.stable_id, &"energy")
		return false
	if weapon.magazine_size > 0 and state.ammo <= 0:
		state.reload_timer = weapon.reload_seconds
		dry_fired.emit(weapon.stable_id, &"reload")
		return false
	energy -= weapon.energy_cost
	state.heat += weapon.heat_per_shot
	state.cooldown = float(get_effective_spec(weapon).cooldown)
	if weapon.magazine_size > 0:
		state.ammo -= 1
		if state.ammo <= 0:
			state.reload_timer = weapon.reload_seconds
	_spawn_volley(weapon, state, charge_ratio)
	state.burst_remaining = weapon.burst_count - 1
	state.burst_timer = weapon.burst_interval
	recoil_requested.emit(weapon.recoil_strength)
	return true

func _spawn_volley(weapon: WeaponDefinition, state: Dictionary, charge_ratio: float) -> void:
	if weapon.family in [WeaponDefinition.WeaponFamily.BEAM, WeaponDefinition.WeaponFamily.CHAIN_LIGHTNING] and locked_target != null and is_instance_valid(locked_target):
		var direct_hits := _fire_direct_weapon(weapon, charge_ratio)
		fired.emit(weapon.stable_id, direct_hits)
		return
	var spawned := 0
	var spec := get_effective_spec(weapon)
	var count := maxi(1, int(spec.projectile_count))
	for muzzle in weapon.muzzle_offsets:
		for projectile_index in count:
			var fraction := 0.5 if count == 1 else float(projectile_index) / float(count - 1)
			var direction := aim_direction.rotated(deg_to_rad(lerpf(-float(spec.spread_degrees) * 0.5, float(spec.spread_degrees) * 0.5, fraction)))
			_projectile_sequence += 1
			var projectile_definition := weapon.projectile_definition if weapon.projectile_definition != null else _fallback_projectile_definition(weapon)
			var category := projectile_definition.pool_category if projectile_definition else _category_for_family(weapon.family)
			var configuration := {
				"actor_id": StringName("projectile.%s.%d" % [owner_actor.actor_id, _projectile_sequence]),
				"source_id": owner_actor.actor_id, "source_player_id": owner_actor.actor_id,
				"source_ability_id": weapon.stable_id, "definition": projectile_definition,
				"damage": float(spec.damage) * maxf(1.0, charge_ratio),
				"speed": weapon.projectile_speed, "team": owner_actor.faction,
				"direction": direction, "target": locked_target, "status_effect_ids": weapon.status_effect_ids,
				"registry": registry, "event_bus": event_bus
			}
			var spawn_transform := Transform2D(direction.angle() + PI * 0.5, owner_actor.global_position + muzzle.rotated(owner_actor.global_rotation))
			if pool_manager.acquire(category, configuration, spawn_transform) != null:
				spawned += 1
	fired.emit(weapon.stable_id, spawned)

func _fire_direct_weapon(weapon: WeaponDefinition, charge_ratio: float) -> int:
	var targets: Array[Node] = [locked_target]
	if weapon.family == WeaponDefinition.WeaponFamily.CHAIN_LIGHTNING and registry != null:
		for candidate in registry.get_actors(&"enemy") + registry.get_actors(&"miniboss") + registry.get_actors(&"boss"):
			if candidate not in targets and candidate is BaseActor2D and is_instance_valid(candidate):
				targets.append(candidate)
		targets.sort_custom(func(a: Node, b: Node): return locked_target.global_position.distance_squared_to(a.global_position) < locked_target.global_position.distance_squared_to(b.global_position))
	var hit_count := 0
	var spec := get_effective_spec(weapon)
	for target_index in mini(targets.size(), maxi(1, int(spec.projectile_count))):
		var target := targets[target_index] as BaseActor2D
		if target == null or target.faction == owner_actor.faction:
			continue
		var falloff := pow(0.75, target_index) if weapon.family == WeaponDefinition.WeaponFamily.CHAIN_LIGHTNING else 1.0
		var packet := DamagePacket.new(float(spec.damage) * maxf(1.0, charge_ratio) * falloff, owner_actor.actor_id)
		packet.source_player_id = owner_actor.actor_id
		packet.source_ability_id = weapon.stable_id
		packet.chain_attribution = owner_actor.actor_id
		packet.score_attribution = owner_actor.actor_id
		for status_id in weapon.status_effect_ids:
			packet.status_applications.append(StatusApplication.new(status_id, owner_actor.actor_id, 2.0))
		target.receive_damage(packet)
		if event_bus != null:
			event_bus.publish(ProjectileInteractionEvent.new(owner_actor.actor_id, target.actor_id, &"beam" if weapon.family == WeaponDefinition.WeaponFamily.BEAM else &"chain"))
		hit_count += 1
	return hit_count

func _fallback_projectile_definition(weapon: WeaponDefinition) -> ProjectileDefinition:
	if _fallback_projectiles.has(weapon.stable_id):
		return _fallback_projectiles[weapon.stable_id]
	var projectile := ProjectileDefinition.new()
	projectile.stable_id = StringName("projectile.%s" % weapon.stable_id)
	projectile.damage = weapon.damage
	projectile.speed = weapon.projectile_speed
	projectile.team = owner_actor.faction
	projectile.pool_category = _category_for_family(weapon.family)
	match weapon.family:
		WeaponDefinition.WeaponFamily.MISSILE, WeaponDefinition.WeaponFamily.HOMING_LASER:
			projectile.homing_strength = 1.0
			projectile.turn_rate_degrees = 240.0
		WeaponDefinition.WeaponFamily.MINE:
			projectile.lifetime_seconds = 8.0
		WeaponDefinition.WeaponFamily.RAIL:
			projectile.pierce_count = 5
		WeaponDefinition.WeaponFamily.SCATTER:
			projectile.lifetime_seconds = 0.45
	_fallback_projectiles[weapon.stable_id] = projectile
	return projectile

func _default_state(definition: WeaponDefinition) -> Dictionary:
	return {"cooldown": 0.0, "burst_remaining": 0, "burst_timer": 0.0, "charge": 0.0, "heat": 0.0, "ammo": definition.magazine_size, "reload_timer": 0.0}

func _find_weapon(weapon_id: StringName) -> WeaponDefinition:
	for weapon in inventory:
		if weapon != null and weapon.stable_id == weapon_id:
			return weapon
	return null

func _upgrade_multiplier(weapon: WeaponDefinition) -> float:
	return float(get_effective_spec(weapon).damage) / maxf(weapon.damage, 0.001)

func _category_for_family(family: int) -> StringName:
	match family:
		WeaponDefinition.WeaponFamily.MISSILE, WeaponDefinition.WeaponFamily.HOMING_LASER: return &"missile"
		WeaponDefinition.WeaponFamily.MINE: return &"mine"
		_: return &"player_bullet"
