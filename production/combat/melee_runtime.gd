class_name MeleeRuntime
extends Node

signal melee_hit(target_id: StringName, damage: float, risk_bonus: float)
signal projectile_parried(projectile_id: StringName)
signal hit_stop_requested(seconds: float)

var owner_actor: BaseActor2D
var definition: MeleeDefinition
var event_bus: TypedEventBus
var cooldown := 0.0
var parry_remaining := 0.0
var ram_charge := 0.0

func configure(actor: BaseActor2D, melee_definition: MeleeDefinition, session_events: TypedEventBus) -> void:
	owner_actor = actor
	definition = melee_definition
	event_bus = session_events

func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	parry_remaining = maxf(0.0, parry_remaining - delta)

func attack(targets: Array[Node], aim_direction := Vector2.UP) -> int:
	if owner_actor == null or definition == null or cooldown > 0.0:
		return 0
	cooldown = definition.cooldown_seconds
	var hits := 0
	for target in targets:
		if not (target is BaseActor2D) or target.faction == owner_actor.faction:
			continue
		var offset: Vector2 = target.global_position - owner_actor.global_position
		var effective_range := maxf(definition.range_pixels, definition.shockwave_radius)
		var outside_arc := definition.shockwave_radius <= 0.0 and absf(aim_direction.angle_to(offset.normalized())) > deg_to_rad(definition.arc_degrees * 0.5)
		if offset.length() > effective_range or outside_arc:
			continue
		var packet := DamagePacket.new(definition.damage, owner_actor.actor_id)
		packet.source_player_id = owner_actor.actor_id
		packet.source_ability_id = definition.stable_id
		packet.chain_attribution = owner_actor.actor_id
		packet.score_attribution = owner_actor.actor_id
		target.receive_damage(packet)
		var bonus: float = definition.close_range_bonus * (1.0 - offset.length() / maxf(1.0, effective_range))
		melee_hit.emit(target.actor_id, definition.damage, bonus)
		hits += 1
	if hits > 0:
		hit_stop_requested.emit(definition.hit_stop_seconds)
	return hits

func begin_parry() -> void:
	if definition != null:
		parry_remaining = definition.parry_window_seconds

func try_parry(projectile: ProductionProjectile) -> bool:
	if parry_remaining <= 0.0 or projectile == null or not projectile.pool_active:
		return false
	var old_id := projectile.actor_id
	projectile.reflect(owner_actor.actor_id, owner_actor.faction)
	projectile_parried.emit(old_id)
	parry_remaining = 0.0
	return true

func begin_ram() -> void:
	ram_charge = 0.0

func charge_ram(delta: float) -> void:
	ram_charge = minf(1.0, ram_charge + delta)

func ram(target: BaseActor2D) -> bool:
	if target == null or definition == null or ram_charge <= 0.0:
		return false
	var packet := DamagePacket.new(definition.damage * definition.ram_damage_multiplier * ram_charge, owner_actor.actor_id)
	packet.is_collision_damage = true
	target.receive_damage(packet)
	var retaliation := DamagePacket.new(definition.damage * ram_charge * (1.0 - definition.collision_armor), target.actor_id)
	retaliation.is_collision_damage = true
	owner_actor.receive_damage(retaliation)
	ram_charge = 0.0
	return true
