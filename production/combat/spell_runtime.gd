class_name SpellRuntime
extends Node

signal spell_cast(spell_id: StringName, school: int, result: Dictionary)
signal spell_failed(spell_id: StringName, reason: StringName)

var owner_actor: BaseActor2D
var pool_manager: ProjectilePoolManager
var event_bus: TypedEventBus
var energy := 100.0
var cooldowns: Dictionary = {}
var upgrade_levels: Dictionary = {}
var global_power_multiplier := 1.0
var energy_recharge := 8.0

func configure(actor: BaseActor2D, manager: ProjectilePoolManager, session_events: TypedEventBus) -> void:
	owner_actor = actor
	pool_manager = manager
	event_bus = session_events

func tick(delta: float) -> void:
	energy = minf(100.0, energy + energy_recharge * delta)
	for spell_id in cooldowns:
		cooldowns[spell_id] = maxf(0.0, float(cooldowns[spell_id]) - delta)

func cast(spell: SpellDefinition, targets: Array[Node] = [], projectiles: Array[ProductionProjectile] = []) -> Dictionary:
	var result := {"success": false, "affected": 0, "energy_gained": 0.0, "score_gained": 0}
	if spell == null or owner_actor == null:
		return result
	if float(cooldowns.get(spell.stable_id, 0.0)) > 0.0:
		spell_failed.emit(spell.stable_id, &"cooldown")
		return result
	if energy < spell.energy_cost:
		spell_failed.emit(spell.stable_id, &"energy")
		return result
	var level := clampi(int(upgrade_levels.get(spell.stable_id, 1)), 1, spell.maximum_upgrade_level)
	var effective_power := spell.power * (1.0 + float(level - 1) * spell.power_per_upgrade) * maxf(0.0, global_power_multiplier)
	energy -= spell.energy_cost
	cooldowns[spell.stable_id] = spell.cooldown_seconds * maxf(0.25, 1.0 - float(level - 1) * spell.cooldown_reduction_per_upgrade)
	match spell.school:
		SpellDefinition.School.NOVA, SpellDefinition.School.SOLAR, SpellDefinition.School.STORM:
			for target in targets:
				if target is BaseActor2D and owner_actor.global_position.distance_to(target.global_position) <= spell.radius:
					var packet := DamagePacket.new(effective_power, owner_actor.actor_id)
					packet.source_player_id = owner_actor.actor_id
					packet.source_ability_id = spell.stable_id
					target.receive_damage(packet)
					result.affected += 1
		SpellDefinition.School.AEGIS:
			owner_actor.shield_component.current = minf(owner_actor.shield_component.capacity, owner_actor.shield_component.current + effective_power)
			owner_actor.shield_component.capacity_changed.emit(owner_actor.shield_component.current, owner_actor.shield_component.capacity)
			result.affected = 1
		SpellDefinition.School.GRAVITY, SpellDefinition.School.VOID, SpellDefinition.School.CRYO:
			for projectile in projectiles:
				if is_instance_valid(projectile) and projectile.pool_active and owner_actor.global_position.distance_to(projectile.global_position) <= spell.radius:
					var interaction := ProjectileInteractionResolver.resolve(projectile, spell.interaction_policy, owner_actor.actor_id, owner_actor.faction, event_bus)
					if interaction.applied:
						result.affected += 1
						result.energy_gained += interaction.energy
						result.score_gained += interaction.score
		SpellDefinition.School.WARP:
			owner_actor.global_position += Vector2.UP * effective_power
			result.affected = 1
		SpellDefinition.School.SUMMON:
			var summon := spell.summon_scene.instantiate() if spell.summon_scene != null else Node2D.new()
			summon.name = "Summon_%s" % spell.stable_id
			owner_actor.get_parent().add_child(summon)
			if summon is Node2D:
				summon.global_position = owner_actor.global_position
			result.affected = 1
		SpellDefinition.School.REPAIR:
			owner_actor.health_component.heal(effective_power)
			result.affected = 1
	energy = minf(100.0, energy + result.energy_gained)
	result.success = true
	spell_cast.emit(spell.stable_id, spell.school, result)
	return result
