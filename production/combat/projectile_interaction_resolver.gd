class_name ProjectileInteractionResolver
extends RefCounted

static func resolve(projectile: ProductionProjectile, policy: ProjectileInteractionPolicy, actor_id: StringName, actor_team: StringName, event_bus: TypedEventBus = null) -> Dictionary:
	var result := {"applied": false, "energy": 0.0, "score": 0, "split_count": 0, "owner_id": projectile.source_id if projectile else &""}
	if projectile == null or policy == null or not projectile.pool_active or not policy.accepts(projectile.interaction_tags):
		return result
	result.applied = true
	var interaction_name: StringName
	match policy.interaction:
		ProjectileInteractionPolicy.Interaction.DESTROY:
			interaction_name = &"destroy"
			projectile.deactivate_to_pool()
		ProjectileInteractionPolicy.Interaction.REFLECT:
			interaction_name = &"reflect"
			projectile.reflect(actor_id, policy.replacement_team if not policy.replacement_team.is_empty() else actor_team)
			result.owner_id = actor_id
		ProjectileInteractionPolicy.Interaction.ABSORB:
			interaction_name = &"absorb"
			projectile.absorb()
		ProjectileInteractionPolicy.Interaction.CONVERT_ENERGY:
			interaction_name = &"convert_energy"
			result.energy = projectile.damage * policy.magnitude
			projectile.absorb()
		ProjectileInteractionPolicy.Interaction.CONVERT_SCORE:
			interaction_name = &"convert_score"
			result.score = roundi(projectile.damage * policy.magnitude)
			projectile.absorb()
		ProjectileInteractionPolicy.Interaction.FREEZE:
			interaction_name = &"freeze"
			projectile.speed = 0.0
			projectile.velocity = Vector2.ZERO
		ProjectileInteractionPolicy.Interaction.SLOW:
			interaction_name = &"slow"
			projectile.speed *= clampf(policy.magnitude, 0.0, 1.0)
			projectile.velocity = projectile.velocity.normalized() * projectile.speed
		ProjectileInteractionPolicy.Interaction.REDIRECT:
			interaction_name = &"redirect"
			projectile.reflect(actor_id, actor_team, Vector2.UP)
			result.owner_id = actor_id
		ProjectileInteractionPolicy.Interaction.PHASE_THROUGH:
			interaction_name = &"phase_through"
			projectile.collision_mask = 0
		ProjectileInteractionPolicy.Interaction.SPLIT:
			interaction_name = &"split"
			result.split_count = maxi(2, policy.split_count)
			projectile.deactivate_to_pool()
		ProjectileInteractionPolicy.Interaction.DETONATE:
			interaction_name = &"detonate"
			projectile.deactivate_to_pool()
	if event_bus != null:
		event_bus.publish(ProjectileInteractionEvent.new(actor_id, projectile.actor_id, interaction_name))
	return result
