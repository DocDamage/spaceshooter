class_name DamageResolver
extends RefCounted

const MAX_DAMAGE := 9999999.0

static func resolve(target: BaseActor2D, packet: DamagePacket) -> DamageResult:
	var result := DamageResult.new()
	if target == null or packet == null or not is_instance_valid(target) or not target.is_damageable():
		result.blocked_reason = &"invalid_target"
		return result
	result.input_damage = clampf(packet.base_damage, 0.0, MAX_DAMAGE)
	if target.is_invulnerable():
		result.blocked_reason = &"invulnerable"
		return result
	result.accepted = true
	var remaining := result.input_damage
	remaining = target.shield_component.resolve_damage(remaining, packet, result)
	var armor_result := target.armor_component.reduce_damage(remaining, packet.armor_penetration, target.status_component.armor_multiplier())
	remaining = float(armor_result.damage)
	result.armor_reduction = float(armor_result.reduction)
	result.resistance_multiplier = target.armor_component.resistance_multiplier(packet.damage_type)
	remaining *= result.resistance_multiplier
	if packet.is_critical:
		remaining *= maxf(0.0, packet.critical_multiplier)
	remaining *= target.status_component.damage_taken_multiplier()
	remaining = clampf(remaining, 0.0, MAX_DAMAGE)
	result.health_damage = target.health_component.apply_damage(remaining)
	for application in packet.status_applications:
		if target.status_component.apply(application):
			result.applied_statuses.append(application.status_id)
	target.on_damage_resolved(packet, result)
	if target.health_component.is_depleted():
		result.target_destroyed = true
		target.destroy_actor(packet.source_actor_id)
	return result
