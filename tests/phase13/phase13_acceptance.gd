extends SceneTree

var failures := PackedStringArray()
var passed_count := 0

func _init() -> void: call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if condition: passed_count += 1; print("PASS: %s" % message)
	else: failures.append(message); push_error("FAIL: %s" % message)

func _run() -> void:
	await process_frame
	_test_content_and_variants()
	_test_phase_machine_and_summons()
	_test_parts_challenges_arena_and_practice()
	await _test_boss_actor_hud_snapshot_and_rewards()
	if failures.is_empty(): print("PHASE 13 ACCEPTANCE: all %d checks passed" % passed_count); quit(0)
	else: print("PHASE 13 ACCEPTANCE: %d check(s) failed" % failures.size()); quit(1)

func _definition() -> BossDefinition:
	return load("res://production/content/data/boss/corsair_dreadnought.tres") as BossDefinition

func _test_content_and_variants() -> void:
	var definition := _definition()
	_assert(definition != null and definition.validate_definition().is_empty(), "authored bosses validate phases, parts, challenges, rewards, and presentation hooks")
	_assert(definition.phases.size() == 2 and definition.phases[1].arena_behavior.has("hazards"), "phase resources carry health gates, decks, summons, arena, music, dialogue, transitions, and enrage")
	_assert(definition.variants[0].validate_definition().is_empty() and not definition.variants[0].additional_summon_ids.is_empty(), "New Game Plus variants alter behavior rather than only multiplying health")
	var database := ContentDatabase.new()
	_assert(database.initialize() and database.get_definition(definition.stable_id, &"boss") != null, "boss resources participate in the production content database")
	var miniboss := database.get_definition(&"boss.corsair_ace_miniboss", &"boss") as BossDefinition
	_assert(miniboss != null and miniboss.is_miniboss and miniboss.phases.size() == 1 and not miniboss.guaranteed_rewards.is_empty(), "miniboss profiles reuse the boss stack with compact phases and guaranteed rewards")

func _test_phase_machine_and_summons() -> void:
	var definition := _definition()
	var machine := BossPhaseStateMachine.new()
	_assert(machine.configure(definition.phases) and machine.current_index == 0, "boss phase state machine starts from an authored phase")
	_assert(machine.tick(0.1, 0.49, 0) and machine.current_index == 1, "health thresholds deterministically transition to the next phase")
	machine.tick(definition.phases[1].enrage_after + 0.1, 0.2, 0)
	_assert(machine.is_enraged, "phase-local enrage timers produce an explicit state transition")
	var summons := BossSummonController.new()
	var first := definition.phases[0]; summons.tick(first.summon_interval, first)
	_assert(summons.active_summons.size() == 1, "summon controller enforces phase cadence and tracks owned summons")

func _test_parts_challenges_arena_and_practice() -> void:
	var definition := _definition(); var part := BossPartRuntime.new(); part.configure(definition.parts[0])
	var applied := part.receive_damage(1000.0)
	_assert(applied == definition.parts[0].maximum_health and not part.active, "targetable parts resolve independent armor and durability")
	var tracker := BossChallengeTracker.new(); tracker.configure(definition.challenges)
	tracker.record(&"parts_progress", 1.0); tracker.record(&"player_damaged")
	var results := tracker.complete_results()
	_assert(results[&"boss_challenge.corsair_parts"].passed and not results[&"boss_challenge.corsair_no_damage"].passed, "challenge tracker handles positive-progress and fail-on-event conditions")
	var arena := BossArenaController.new(); arena.configure(definition.arena_profile, 2)
	_assert(arena.enter_player(&"player.1") and not arena.locked and arena.enter_player(&"player.2") and arena.locked, "arena lock waits for multiplayer clearance")
	_assert(arena.respawn_player(&"player.1") == definition.arena_profile.safe_entry and arena.clamp_position(Vector2(-50, 2000)) == Vector2(20, 920), "arena provides safe respawn and authoritative boundaries")
	var practice := BossPracticeSession.new()
	_assert(practice.configure(definition.stable_id, 1, 80, {"weapon_id": &"weapon.rail"}, definition.phases.size()) and practice.starting_phase == 1 and not practice.result_policy().grant_rewards, "boss practice selects phase, loadout, and difficulty without campaign rewards")

func _test_boss_actor_hud_snapshot_and_rewards() -> void:
	var definition := _definition(); var registry := ActorRegistry.new(); root.add_child(registry); var events := TypedEventBus.new()
	var arena := BossArenaController.new(); root.add_child(arena); arena.configure(definition.arena_profile)
	var boss := BossActor.new(); _assert(boss.configure_boss(definition, registry, events, arena, null, 1), "boss actor composes health, armor, shields, phases, parts, variants, arena, and challenge systems")
	root.add_child(boss); await process_frame
	_assert(boss.active and boss.active_variant != null and boss.hud.view_model().phase_count == 2 and boss.hud.view_model().parts.size() == 1, "boss HUD exposes health, defenses, phase divisions, parts, enrage, status, and challenge state")
	boss.receive_part_damage(&"boss_part.corsair_turret", 1000.0)
	_assert(&"attack.ring" in boss.disabled_attack_ids and boss.damage_taken_multiplier > 1.0, "part destruction removes attacks and exposes the authored weakness")
	boss.health_component.current = 1000.0; boss.phase_machine.tick(0.1, boss.health_component.current / boss.health_component.maximum, 1)
	_assert(boss.phase_machine.current_index == 1 and not arena.active_hazards.is_empty(), "phase entry coordinates arena behavior through explicit hooks")
	var snapshot := boss.snapshot_boss(); boss.health_component.current = 1.0
	_assert(boss.restore_boss(snapshot) and boss.health_component.current == 1000.0, "boss checkpoint snapshots restore phase, defenses, parts, and challenge state by stable ID")
	arena.enter_player(&"player.1")
	var rewards := {"value": {}}; boss.rewards_ready.connect(func(value, _challenges): rewards.value = value)
	boss.invulnerability_time = 0.0; boss.shield_component.current = 0.0; boss.health_component.current = 1.0; boss.take_damage(100.0, &"player.1"); await process_frame
	_assert(not rewards.value.is_empty() and not arena.locked, "boss defeat emits guaranteed and variant reward hooks and cleans up the arena")
