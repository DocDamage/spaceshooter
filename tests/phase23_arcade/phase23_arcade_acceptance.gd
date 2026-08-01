extends SceneTree

var failures := PackedStringArray()
var checks := 0
var host: Node
var registry: ActorRegistry
var events: TypedEventBus

func _init() -> void: call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition: checks += 1; print("PASS: " + message)
	else: failures.append(message); push_error("FAIL: " + message)

func _run() -> void:
	host = Node.new(); root.add_child(host)
	registry = ActorRegistry.new(); host.add_child(registry); events = TypedEventBus.new()
	await _test_projectile_graze_and_conversion()
	_test_score_loop_and_replay()
	_test_element_overdrive_and_bomb()
	_test_choreography_content()
	await _test_telegraph_runtime()
	print("PHASE 2/3 ARCADE ACCEPTANCE: all %d checks passed" % checks if failures.is_empty() else "PHASE 2/3 ARCADE ACCEPTANCE: %d failure(s)" % failures.size())
	TestSupport.free_root_nodes(self); call_deferred("_quit_after_cleanup", 0 if failures.is_empty() else 1)

func _quit_after_cleanup(exit_code: int) -> void:
	await process_frame
	quit(exit_code)

func _test_projectile_graze_and_conversion() -> void:
	var pool := ProjectilePoolManager.new(); host.add_child(pool)
	pool.register_factory(&"pickup", func(): return ProductionPickup.new())
	var definition := ProjectileDefinition.new(); definition.team = &"enemies"; definition.collision_radius = 3.5; definition.cancel_class = &"eligible"; definition.graze_value = 2; definition.flux_value = 3
	var projectile := pool.acquire(&"enemy_bullet", {&"actor_id": &"projectile.phase23", &"definition": definition, &"direction": Vector2.DOWN, &"registry": registry, &"event_bus": events}, Transform2D.IDENTITY) as ProductionProjectile
	await process_frame
	var shape := projectile.collision_shape.shape as CircleShape2D
	_check(is_equal_approx(shape.radius, 3.5), "projectile collision shape follows its definition")
	_check(projectile.try_graze(&"player.one") and not projectile.try_graze(&"player.one"), "each live hostile projectile grants one graze per player")
	var converter := BulletConversionService.new(); host.add_child(converter); converter.configure(pool, null)
	_check(converter.convert_projectiles([projectile], &"player.one") == 1 and not projectile.pool_active and pool.get_active_count(&"pickup") == 1, "eligible bullets convert deterministically into pooled Flux")

func _test_score_loop_and_replay() -> void:
	var tracker := MissionScoreTracker.new(); host.add_child(tracker)
	tracker.record_defeat(&"player.one", 100)
	tracker.record_graze(&"player.one", 2)
	tracker.record_flux(&"player.one", 3)
	tracker.set_beam_hold(true); tracker._process(0.1)
	var snapshot := tracker.snapshot(); var restored := MissionScoreTracker.new(); restored.restore(snapshot)
	_check(snapshot.chain == restored.chain and snapshot.rate == restored.rate and snapshot.graze == 1, "chain, beam hold, graze, Flux, and rate survive deterministic replay state")
	restored.free()
	tracker.record_bomb(&"player.one")
	_check(tracker.bombs_used == 1 and tracker.rate < snapshot.rate, "bomb applies the visible chain/rate penalty")

func _test_element_overdrive_and_bomb() -> void:
	var owner := BaseActor2D.new(); owner.configure_actor(&"player.loop", &"player", &"players", registry, events); host.add_child(owner)
	var spell_runtime := SpellRuntime.new(); host.add_child(spell_runtime); spell_runtime.configure(owner, null, events)
	var control := SpellDefinition.new(); control.stable_id = &"element.control"; control.element_role = SpellDefinition.ElementRole.CONTROL; control.energy_cost = 0.0; control.radius = 500.0
	var element := ElementRuntime.new(); host.add_child(element); element.configure(spell_runtime, control)
	_check(element.snapshot().element_id == &"element.control", "one active Element slot carries a control tool")
	var super_definition := SuperModeDefinition.new(); super_definition.stable_id = &"super.loop"; super_definition.charge_required = 10.0; super_definition.duration_seconds = 0.05; super_definition.recovery_seconds = 0.25
	var overdrive := SuperModeRuntime.new(); host.add_child(overdrive); overdrive.configure(owner, null, super_definition); overdrive.add_charge(10.0)
	_check(overdrive.activate() and overdrive.snapshot().active, "Overdrive activation has deterministic active state")
	overdrive.tick(0.1)
	_check(overdrive.recovery_remaining > 0.0, "Overdrive end enters a visible recovery state")
	var bomb := ArcadeBombRuntime.new(); host.add_child(bomb); bomb.configure(null, 1)
	_check(bomb.activate(owner) and bomb.stock == 0 and owner.is_invulnerable(), "manual bomb consumes stock and grants safety")

func _test_choreography_content() -> void:
	var database := ContentDatabase.new(); host.add_child(database)
	_check(database.initialize(), "Phase 2/3 resources pass content validation")
	_check(database.get_definitions_by_type(&"enemy_archetype").size() >= 6 and database.get_definitions_by_type(&"attack_phrase").size() >= 10, "six combat roles and ten authored attack phrases are data-driven")
	var variant := database.get_definition(&"encounter.frontier_anchor", &"encounter_variant") as EncounterVariantDefinition
	_check(variant != null and variant.visual_family != null and variant.archetype != null and variant.behavior_score != null, "visual family, archetype, behavior score, and encounter variant remain separate")
	var behavior := database.get_definition(&"behavior.frontier_anchor", &"enemy_behavior_score") as EnemyBehaviorScoreDefinition
	_check(EnemyPhraseValidator.validate_behavior(behavior).is_empty() and behavior.fingerprint(77) == behavior.fingerprint(77), "safe lanes validate and behavior replay fingerprints are deterministic")
	var path := database.get_definition(&"path.frontier_arc", &"movement_path") as MovementPathDefinition
	_check(path.position_at(0.5) == path.position_at(0.5), "authored movement paths are deterministic")

func _test_telegraph_runtime() -> void:
	var owner := BaseActor2D.new(); owner.configure_actor(&"enemy.telegraph", &"enemy", &"enemies", registry, events); owner.position = Vector2(270, 120); host.add_child(owner)
	var target := Node2D.new(); target.position = Vector2(270, 600); host.add_child(target)
	var pool := ProjectilePoolManager.new(); host.add_child(pool)
	var pattern := AttackPatternDefinition.new(); pattern.stable_id = &"attack.telegraph"; pattern.telegraph_seconds = 0.0; pattern.cooldown = 1.0
	var phrase := AttackPhraseDefinition.new(); phrase.stable_id = &"phrase.telegraph"; phrase.pattern = pattern; phrase.telegraph_seconds = 0.2
	var deck := AttackDeckDefinition.new(); deck.attack_phrases = [phrase]
	var controller := EnemyAttackController.new(); host.add_child(controller); controller.configure(owner, deck, target, pool, registry, events)
	controller.tick(0.01)
	_check(controller.telegraph_remaining > 0.0 and pool.get_active_count(&"enemy_bullet") == 0, "enemy phrases telegraph before their first projectile")
	controller.tick(0.25)
	_check(pool.get_active_count(&"enemy_bullet") > 0, "telegraphed phrase fires after its authored warning")
