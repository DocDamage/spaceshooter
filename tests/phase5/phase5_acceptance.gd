extends SceneTree

var failures := PackedStringArray()
var passed_count := 0
var host: Node
var registry: ActorRegistry
var event_bus: TypedEventBus
var sequence := 0

func _init() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)

func _run() -> void:
	await process_frame
	host = Node.new()
	host.name = "Phase5TestHost"
	root.add_child(host)
	registry = ActorRegistry.new()
	host.add_child(registry)
	event_bus = TypedEventBus.new()
	_test_damage_order_and_determinism()
	_test_invulnerability_and_statuses()
	_test_shield_features()
	_test_movement_state_machine()
	_test_system_damage_switches()
	_test_actor_lifecycle_and_coexistence()
	if failures.is_empty():
		print("PHASE 5 ACCEPTANCE: all %d checks passed" % passed_count)
		quit(0)
	else:
		print("PHASE 5 ACCEPTANCE: %d check(s) failed" % failures.size())
		quit(1)

func _actor(category: StringName = &"enemy", pooled := false) -> BaseActor2D:
	sequence += 1
	var actor := BaseActor2D.new()
	actor.configure_actor(StringName("%s.test_%d" % [category, sequence]), category, category, registry, event_bus, pooled)
	actor.health_component.configure(100.0)
	actor.shield_component.configure(20.0, 0.1, 10.0)
	actor.armor_component.configure(5.0, {DamagePacket.DamageType.KINETIC: 0.2})
	host.add_child(actor)
	return actor

func _test_damage_order_and_determinism() -> void:
	var first := _actor()
	var packet := DamagePacket.new(50.0, &"player.test")
	packet.network_sequence_id = 7
	var first_result := first.receive_damage(packet)
	_assert(is_equal_approx(first_result.shield_damage, 20.0), "shield resolves before armor")
	_assert(is_equal_approx(first_result.armor_reduction, 5.0), "armor applies after the shield")
	_assert(is_equal_approx(first_result.health_damage, 20.0), "resistance applies after armor")
	var second := _actor()
	var second_result := second.receive_damage(packet.duplicate_packet())
	_assert(first_result.snapshot() == second_result.snapshot(), "fixed damage input resolves deterministically")
	var critical := _actor()
	critical.shield_component.current = 0.0
	var critical_packet := DamagePacket.new(20.0, &"player.test")
	critical_packet.is_critical = true
	critical_packet.critical_multiplier = 2.0
	var critical_result := critical.receive_damage(critical_packet)
	_assert(is_equal_approx(critical_result.health_damage, 24.0), "critical multiplier applies after armor and resistance")

func _test_invulnerability_and_statuses() -> void:
	var actor := _actor()
	actor.grant_invulnerability(0.5)
	var blocked := actor.receive_damage(DamagePacket.new(10.0, &"player.test"))
	_assert(not blocked.accepted and blocked.blocked_reason == &"invulnerable" and actor.health_component.current == 100.0, "invulnerability windows block damage")
	actor.invulnerability_time = 0.0
	var burn := StatusApplication.new(&"burn", &"player.test", 3.0, 1)
	var packet := DamagePacket.new(1.0, &"player.test")
	packet.status_applications.append(burn)
	var result := actor.receive_damage(packet)
	_assert(&"burn" in result.applied_statuses and actor.status_component.has(&"burn"), "typed status applications are applied after HP damage")
	actor.shield_component.current = 0.0
	var source_ids := PackedStringArray()
	actor.damage_resolved.connect(func(periodic_packet, _periodic_result): source_ids.append(String(periodic_packet.source_ability_id)))
	actor.status_component.tick(1.0)
	_assert(actor.health_component.current < 100.0 and "status.burn" in source_ids, "burn deals attributed periodic fire damage")
	actor.status_component.status_resistances[&"freeze"] = 1.0
	_assert(not actor.status_component.apply(StatusApplication.new(&"freeze", &"player.test", 2.0)), "status resistance can fully reject a status")

func _test_shield_features() -> void:
	var actor := _actor()
	actor.shield_component.absorption_ratio = 0.25
	actor.shield_component.reflection_ratio = 0.5
	var result := actor.receive_damage(DamagePacket.new(20.0, &"player.test"))
	_assert(is_equal_approx(result.absorbed_damage, 5.0) and is_equal_approx(result.shield_damage, 15.0), "shield absorption reduces capacity damage")
	_assert(is_equal_approx(result.reflected_damage, 7.5), "shield reflection reports deterministic feedback damage")
	actor.shield_component.tick(2.0)
	_assert(actor.shield_component.current > 5.0, "shields recharge after their delay")
	var penetration_actor := _actor()
	var penetration := DamagePacket.new(20.0, &"player.test")
	penetration.shield_interaction = DamagePacket.ShieldInteraction.PARTIAL_PENETRATION
	penetration.shield_penetration = 0.5
	var penetration_result := penetration_actor.receive_damage(penetration)
	_assert(penetration_result.shield_damage == 10.0 and penetration_result.health_damage > 0.0, "partial shield penetration splits damage")

func _test_movement_state_machine() -> void:
	var actor := _actor(&"player")
	var profile := MovementProfile.new()
	profile.boundary = Rect2(0, 0, 500, 500)
	var controller := PlayerMovementController.new()
	actor.add_child(controller)
	controller.configure(actor, profile)
	_assert(controller.dash(Vector2.RIGHT), "dash enters its movement state")
	_assert(controller.teleport(Vector2.UP), "teleport cancels dash when available")
	_assert(controller.state_machine.current_state == MovementStateMachine.TELEPORT, "exclusive movement states do not overlap")
	controller.state_machine.tick(0.02)
	_assert(controller.state_machine.current_state == MovementStateMachine.NORMAL, "timed movement state returns to normal")
	controller.state_machine.cooldowns[MovementStateMachine.DASH] = 0.0
	_assert(controller.dash(Vector2.RIGHT) and not controller.set_focus(true), "focus cannot cancel an active dash")
	controller.state_machine.tick(profile.dash_time)
	controller.state_machine.request(MovementStateMachine.PAUSED)
	var before := actor.position
	controller.simulate(Vector2.RIGHT, 1.0)
	_assert(actor.position == before, "pause freezes offline movement")
	controller.state_machine.resume()
	controller.simulate(Vector2.RIGHT, 0.1)
	_assert(actor.position.x > before.x, "movement resumes without becoming stuck")
	controller.state_machine.cooldowns[MovementStateMachine.DASH] = 0.0
	actor.status_component.apply(StatusApplication.new(&"emp", &"enemy.test", 1.0))
	_assert(not controller.dash(Vector2.RIGHT), "EMP blocks active movement abilities")
	actor.status_component.clear()
	controller.state_machine.request(MovementStateMachine.DESTROYED)
	_assert(not controller.state_machine.request(MovementStateMachine.DASH), "destroyed state cancels and rejects abilities")

func _test_system_damage_switches() -> void:
	var armor := ArmorComponent.new()
	host.add_child(armor)
	armor.set_subsystem_enabled(&"engine", false)
	_assert(not armor.damage_subsystem(&"engine", 0.5) and armor.get_condition(&"engine") == 1.0, "engine damage can be disabled independently")
	_assert(armor.damage_subsystem(&"weapons", 0.5) and armor.get_condition(&"weapons") == 0.5, "other subsystem damage remains enabled")
	armor.system_damage_enabled = false
	_assert(not armor.damage_subsystem(&"reactor", 0.5), "master system-damage setting disables all subsystem damage")
	var actor := _actor(&"player")
	var packet := DamagePacket.new(0.0, &"enemy.test")
	packet.subsystem_damage = {&"engine": 0.4, &"weapons": 0.6}
	var result := actor.receive_damage(packet)
	_assert(result.damaged_subsystems == [&"engine", &"weapons"] and is_equal_approx(actor.armor_component.get_condition(&"engine"), 0.6) and is_equal_approx(actor.armor_component.get_condition(&"weapons"), 0.4), "damage packets apply named subsystem damage through the resolver")

func _test_actor_lifecycle_and_coexistence() -> void:
	var player_one := _actor(&"player")
	var player_two := _actor(&"player")
	_assert(registry.get_count(&"player") >= 2 and player_one.actor_id != player_two.actor_id, "two stable-ID player actors coexist")
	var pooled := _actor(&"enemy", true)
	var pooled_id := pooled.actor_id
	pooled.despawn_actor()
	_assert(registry.get_actor(pooled_id) == null and not pooled.active, "pooled actor unregisters on despawn")
	_assert(pooled.spawn_actor() and registry.get_actor(pooled_id) == pooled, "pooled actor can respawn without a leaked registry reference")
	for iteration in range(5):
		pooled.despawn_actor()
		_assert(pooled.spawn_actor(), "repeated pooled lifecycle %d succeeds" % (iteration + 1))
	pooled.despawn_actor()
	_assert(registry.get_actor(pooled_id) == null, "repeated lifecycle leaves no stale actor reference")
