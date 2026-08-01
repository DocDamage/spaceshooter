extends SceneTree

var failures := PackedStringArray()
var host: Node
var registry: ActorRegistry
var events: TypedEventBus

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	host = Node.new(); root.add_child(host)
	registry = ActorRegistry.new(); events = TypedEventBus.new(); host.add_child(registry)
	_test_direct_movement()
	_test_arcade_input_rules()
	await _test_honest_collision_geometry()
	var exit_code := 0 if failures.is_empty() else 1
	print("PHASE 1 ARCADE ACCEPTANCE: PASS" if exit_code == 0 else "PHASE 1 ARCADE ACCEPTANCE: %d failure(s)" % failures.size())
	events = null; registry = null; host = null
	TestSupport.free_root_nodes(self)
	call_deferred("_quit_after_cleanup", exit_code)

func _quit_after_cleanup(exit_code: int) -> void:
	await process_frame
	quit(exit_code)

func _test_direct_movement() -> void:
	var actor := BaseActor2D.new()
	actor.configure_actor(&"player.arcade_test", &"player", &"players", registry, events)
	host.add_child(actor)
	var profile := MovementProfile.new()
	profile.maximum_speed = 320.0; profile.focus_speed = 160.0; profile.regulation_direct = true; profile.boundary = Rect2(0, 0, 540, 960)
	var controller := PlayerMovementController.new()
	actor.add_child(controller); controller.configure(actor, profile)
	controller.simulate(Vector2.RIGHT, 1.0 / 60.0)
	_check(is_equal_approx(actor.position.x, 320.0 / 60.0) and is_equal_approx(controller.velocity.x, 320.0), "regulation movement starts within one fixed tick")
	var stopped_at := actor.position
	controller.simulate(Vector2.ZERO, 1.0 / 60.0)
	_check(actor.position == stopped_at and controller.velocity == Vector2.ZERO, "regulation movement stops within one fixed tick")
	actor.position = Vector2.ZERO
	var first := _alternating_focus_distance(controller, actor)
	actor.position = Vector2.ZERO
	var second := _alternating_focus_distance(controller, actor)
	_check(is_equal_approx(first, second), "twenty one-tick focus taps have repeatable displacement")

func _alternating_focus_distance(controller: PlayerMovementController, actor: BaseActor2D) -> float:
	for tick in 20:
		controller.set_focus(tick % 2 == 0)
		controller.simulate(Vector2.RIGHT, 1.0 / 60.0)
	return actor.position.x

func _test_arcade_input_rules() -> void:
	_check(ArcadeInputRules.radial_response(Vector2(0.18, 0), 0.18, 1.0) == Vector2.ZERO, "radial dead zone rejects threshold drift")
	var diagonal := ArcadeInputRules.radial_response(Vector2(0.8, 0.8), 0.18, 1.0)
	_check(diagonal.length() <= 1.0 and diagonal.x > 0.0 and diagonal.y > 0.0, "radial response preserves diagonal direction without exceeding top speed")
	_check(ArcadeInputRules.select_fire_mode(true, false) == &"rapid" and ArcadeInputRules.select_fire_mode(true, true) == &"focus" and ArcadeInputRules.select_fire_mode(true, false) == &"rapid", "Rapid and Focus priority transitions have no empty mode")
	for action in [&"rapid_shot", &"focus_beam", &"element", &"overdrive", &"bomb"]:
		_check(GameInputService.ACTION_NAMES.has(action), "arcade action %s is bindable" % action)

func _test_honest_collision_geometry() -> void:
	var ship := ShipDefinition.new()
	ship.hitbox_radius = 4.5; ship.graze_radius = 28.0
	var player := ProductionPlayer.new()
	player.configure(&"player.geometry_test", 0, ship, WeaponDefinition.new(), registry, events, null)
	host.add_child(player)
	player.set_physics_process(false)
	await process_frame
	var damage_shape := player.damage_collision.shape as CircleShape2D
	var graze_shape := player.graze_collision.shape as CircleShape2D
	_check(is_equal_approx(player.hurtbox_component.radius, 4.5) and is_equal_approx(damage_shape.radius, 4.5), "visible player damage core and physical collision agree")
	_check(is_equal_approx(graze_shape.radius, 28.0) and not player.graze_area.monitoring, "graze ring is separate and awaits Phase 2 events")
	player.despawn_actor()
	player.free()
