extends SceneTree

var failures := PackedStringArray()
var passed_count := 0
var host: Node
var registry: ActorRegistry
var event_bus: TypedEventBus

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
	root.add_child(host)
	registry = ActorRegistry.new()
	host.add_child(registry)
	event_bus = TypedEventBus.new()
	_test_pool_reset_and_stress()
	_test_reflection_and_absorption()
	_test_lock_on_destruction()
	_test_weapon_switch_state()
	_test_content_examples()
	if failures.is_empty():
		print("PHASE 6 ACCEPTANCE: all %d checks passed" % passed_count)
		quit(0)
	else:
		print("PHASE 6 ACCEPTANCE: %d check(s) failed" % failures.size())
		quit(1)

func _test_pool_reset_and_stress() -> void:
	var pool := ProjectilePoolManager.new()
	host.add_child(pool)
	pool.hard_limit_per_category = 2100
	pool.prewarm(&"player_bullet", 2000)
	_assert(pool.get_total_count(&"player_bullet") == 2000, "2,000 projectile objects prewarm into one stable pool")
	var acquired: Array[PooledCombatObject] = []
	for index in 2000:
		var object := pool.acquire(&"player_bullet", {"actor_id": StringName("stress.%d" % index), "source_id": &"player.stress", "damage": 1.0, "speed": 1.0, "team": &"players", "direction": Vector2.UP, "registry": registry, "event_bus": event_bus})
		if object != null:
			acquired.append(object)
	_assert(acquired.size() == 2000 and pool.get_active_count(&"player_bullet") == 2000, "2,000 projectile stress acquisition remains stable")
	for object in acquired:
		object.position = Vector2(19, 23)
		pool.release(object)
	_assert(pool.get_active_count(&"player_bullet") == 0, "pool returns every active projectile")
	_assert(pool.validate_inactive_objects().is_empty(), "returned projectile objects have a complete clean reset")

func _test_reflection_and_absorption() -> void:
	var pool := ProjectilePoolManager.new()
	host.add_child(pool)
	var projectile := pool.acquire(&"enemy_bullet", {"actor_id": &"projectile.reflect", "source_id": &"enemy.source", "source_player_id": &"", "damage": 12.0, "speed": 100.0, "team": &"enemies", "direction": Vector2.DOWN, "registry": registry, "event_bus": event_bus}) as ProductionProjectile
	var reflect := ProjectileInteractionPolicy.new()
	reflect.interaction = ProjectileInteractionPolicy.Interaction.REFLECT
	var reflected := ProjectileInteractionResolver.resolve(projectile, reflect, &"player.one", &"players", event_bus)
	_assert(reflected.applied and projectile.source_id == &"player.one" and projectile.source_player_id == &"player.one" and projectile.team == &"players", "reflected bullets change ownership and reward attribution")
	var absorb := ProjectileInteractionPolicy.new()
	absorb.interaction = ProjectileInteractionPolicy.Interaction.ABSORB
	var absorbed := ProjectileInteractionResolver.resolve(projectile, absorb, &"player.one", &"players", event_bus)
	_assert(absorbed.applied and not projectile.pool_active and projectile.absorbed == false, "absorbed bullets deactivate before they can damage the player")

func _test_lock_on_destruction() -> void:
	var owner := BaseActor2D.new()
	owner.configure_actor(&"player.lock", &"player", &"players", registry, event_bus)
	host.add_child(owner)
	var target := BaseActor2D.new()
	target.configure_actor(&"enemy.lock", &"enemy", &"enemies", registry, event_bus)
	target.position = Vector2(0, -100)
	host.add_child(target)
	var lock := LockOnController.new()
	host.add_child(lock)
	lock.configure(owner, registry)
	lock.lock_time = 0.0
	lock.update_lock(0.01)
	_assert(lock.primary_target() == target, "lock-on acquires prioritized targets")
	target.despawn_actor()
	_assert(lock.primary_target() == null, "lock-on safely clears a destroyed target")

func _test_weapon_switch_state() -> void:
	var pool := ProjectilePoolManager.new()
	host.add_child(pool)
	var owner := BaseActor2D.new()
	owner.configure_actor(&"player.weapon", &"player", &"players", registry, event_bus)
	host.add_child(owner)
	var pulse := WeaponDefinition.new()
	pulse.stable_id = &"weapon.test_pulse"
	pulse.cooldown_seconds = 1.0
	var spread := WeaponDefinition.new()
	spread.stable_id = &"weapon.test_spread"
	spread.cooldown_seconds = 0.1
	var runtime := WeaponRuntime.new()
	host.add_child(runtime)
	runtime.configure(owner, pool, registry, event_bus)
	runtime.equip([pulse, spread])
	runtime.set_trigger(true)
	runtime.tick(0.01)
	var pulse_cooldown: float = runtime.get_state(pulse.stable_id).cooldown
	runtime.switch_to(1)
	runtime.set_trigger(false)
	runtime.tick(0.1)
	runtime.switch_to(0)
	_assert(runtime.get_state(pulse.stable_id).cooldown < pulse_cooldown and runtime.get_state(pulse.stable_id).cooldown > 0.0, "weapon switching preserves and advances valid cooldown state")

func _test_content_examples() -> void:
	var database := ContentDatabase.new()
	host.add_child(database)
	_assert(database.initialize(), "Phase 6 data definitions pass content validation")
	_assert(database.get_definitions_by_type(&"weapon").size() >= 10, "all ten initial weapon families are data-driven")
	_assert(database.get_definitions_by_type(&"spell").size() >= 10, "all ten early-priority spell schools have examples")
