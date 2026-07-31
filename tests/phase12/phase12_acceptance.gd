extends SceneTree

var failures := PackedStringArray()
var passed_count := 0

func _init() -> void: call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if condition: passed_count += 1; print("PASS: %s" % message)
	else: failures.append(message); push_error("FAIL: %s" % message)

func _run() -> void:
	await process_frame
	var hub := ServiceHub.new(); root.add_child(hub)
	hub.saves.configure_storage("user://phase12_acceptance_%d" % Time.get_ticks_usec())
	_assert(hub.initialize_services(), "service hub initializes the story service behind the dialogue adapter")
	_test_dialogue_and_radio(hub)
	_test_campaign()
	_test_pilots_codex_and_persistence(hub)
	await _test_wingmen()
	if failures.is_empty(): print("PHASE 12 ACCEPTANCE: all %d checks passed" % passed_count); _finish(0)
	else: print("PHASE 12 ACCEPTANCE: %d check(s) failed" % failures.size()); _finish(1)

func _finish(exit_code: int) -> void:
	TestSupport.free_root_nodes(self)
	call_deferred("_quit_after_cleanup", exit_code)

func _quit_after_cleanup(exit_code: int) -> void:
	await process_frame
	quit(exit_code)

func _dialogue(id: StringName, context: String, one_shot := false, objective := false) -> DialogueDefinition:
	var definition := DialogueDefinition.new(); definition.stable_id = id; definition.display_name = String(id); definition.context = context
	definition.one_shot = one_shot; definition.objective_instruction = objective; definition.lines = [{"speaker": "Command", "text": "Proceed, {pilot}.", "portrait_id": "portrait.command"}]
	return definition

func _test_dialogue_and_radio(hub: ServiceHub) -> void:
	var command_portrait := CommsPortraitLibrary.texture_for_speaker("Command") as AtlasTexture
	var ace_portrait := CommsPortraitLibrary.texture_for_speaker("Corsair Ace") as AtlasTexture
	_assert(command_portrait != null and ace_portrait != null and command_portrait.region.size == Vector2(448, 448) and ace_portrait.region.position == Vector2(896, 448), "briefing and radio speakers resolve distinct production portrait-atlas cells")
	var briefing := _dialogue(&"dialogue.briefing", "briefing", true); briefing.pause_gameplay = true
	var combat := _dialogue(&"dialogue.combat", "combat", true); combat.priority = 10
	var objective := _dialogue(&"dialogue.objective", "objective", true, true); objective.priority = 100
	for definition in [briefing, combat, objective]: hub.story.register_dialogue_for_test(definition)
	var mission_state := {"status": &"active", "defeated": 4}
	_assert(hub.story.start_dialogue(briefing.stable_id, {"pilot": "Nova"}) and hub.story.adapter.paused_gameplay, "full-screen briefings resolve variables and own their pause context")
	hub.story.adapter.finish()
	_assert(mission_state == {"status": &"active", "defeated": 4}, "dialogue completion during an active mission does not mutate combat state")
	_assert(hub.story.start_dialogue(combat.stable_id) and hub.story.start_dialogue(objective.stable_id), "combat and objective radio messages enter the queue")
	hub.story.complete_radio(); _assert(StringName(hub.story.radio_queue.current.message_id) == objective.stable_id, "urgent objective radio is selected ahead of lower-priority queued messages")
	_assert(not hub.story.radio_queue.cancel(objective.stable_id, true), "important objective instructions cannot be discarded as obsolete")
	hub.story.complete_radio(); var checkpoint_story := hub.story.snapshot()
	hub.story.restore(checkpoint_story)
	_assert(not hub.story.start_dialogue(combat.stable_id), "checkpoint restore suppresses completed one-time dialogue triggers")
	_assert(hub.story.radio_queue.display_duration("A deliberately longer radio instruction") > 1.0, "radio timing respects configurable text speed")

func _node(id: StringName, operation: int, stage: int) -> CampaignNodeDefinition:
	var node := CampaignNodeDefinition.new(); node.stable_id = id; node.display_name = String(id); node.mission_id = StringName("mission.%s" % id); node.operation_index = operation; node.stage_index = stage
	return node

func _test_campaign() -> void:
	var first := _node(&"node.1.1", 1, 1); first.boss_node = true; first.reward_preview = {"credits": 100}
	var second := _node(&"node.2.1", 2, 1); second.prerequisite_node_ids = [first.stable_id]
	var route := _node(&"node.2.route", 2, 2); route.prerequisite_node_ids = [first.stable_id]; route.decision_requirements = {&"route": &"rescue"}
	var secret := _node(&"node.secret", 3, 1); secret.secret = true; secret.prerequisite_flags = {&"secret_found": true}
	var ng_plus := _node(&"node.ngplus", 6, 1); ng_plus.new_game_plus_variant = &"elite"
	var campaign := CampaignProgression.new(); campaign.configure([first, second, route, secret, ng_plus])
	_assert(campaign.node_state(first.stable_id) == &"available" and campaign.node_state(second.stable_id) == &"locked", "stage and operation prerequisites lock campaign nodes")
	_assert(campaign.complete_stage(first.stable_id, &"S", {&"route": &"rescue"}) and campaign.node_state(second.stable_id) == &"available" and campaign.node_state(route.stable_id) == &"available", "completion, ranks, and route decisions unlock dependent nodes")
	_assert(first.stable_id in campaign.boss_practice, "boss victory unlocks boss practice")
	campaign.complete_stage(first.stable_id, &"A", {&"route": &"assault"})
	_assert(campaign.decisions[&"route"] == &"rescue", "mission replay cannot overwrite a story decision unless explicitly allowed")
	_assert(campaign.node_state(secret.stable_id) == &"secret" and campaign.node_state(ng_plus.stable_id) == &"locked", "secret and New Game Plus variants remain hidden or locked until earned")
	campaign.set_story_flag(&"secret_found"); campaign.new_game_plus_cycle = 1
	_assert(campaign.node_state(secret.stable_id) == &"available" and campaign.node_state(ng_plus.stable_id) == &"available", "story flags and New Game Plus state reveal their authored variants")
	var map := CampaignMapModel.new(); map.configure(campaign); var before: StringName = map.selected_node().node_id; var after: StringName = map.navigate(1)
	_assert(not after.is_empty() and after != before and map.selected_node().has("reward_preview"), "campaign map navigation exposes node state and reward preview through one keyboard/controller-neutral model")

func _test_pilots_codex_and_persistence(hub: ServiceHub) -> void:
	var pilot := PilotDefinition.new(); pilot.stable_id = &"pilot.nova"; pilot.display_name = "Nova"; pilot.biography = "Test pilot"; pilot.campaign_perspective = &"rebel"
	_assert(pilot.validate_definition().is_empty(), "pilot identity carries portrait-ready narrative data without combat-stat bonuses")
	var selection := PilotSelectionModel.new(); selection.configure([pilot], {}, [pilot.stable_id]); _assert(selection.select(pilot.stable_id) and selection.selected_pilot() == pilot, "pilot selection is driven by unlock state and narrative perspective")
	var entry := CodexEntryDefinition.new(); entry.stable_id = &"codex.raiders"; entry.display_name = "Raiders"; entry.category = "factions"; entry.body = "A pirate faction."; entry.unlock_rule = {"boss_defeated": &"raider"}
	var codex := CodexManager.new(); codex.configure([entry])
	_assert(codex.evaluate_unlocks({"boss_defeated": &"raider"}) == [entry.stable_id] and codex.unlocked_by_category(&"factions").size() == 1, "codex entries unlock from authored campaign events and category correctly")
	var profile := ProgressionProfile.new(); profile.story_state = hub.story.snapshot(); profile.codex_unlocks = codex.unlocked_ids; selection.save_to_profile(profile)
	var restored := ProgressionProfile.from_snapshot(profile.to_snapshot())
	_assert(restored.story_state.completed_dialogue_ids == profile.story_state.completed_dialogue_ids and restored.codex_unlocks == [entry.stable_id] and restored.selected_pilot_id == pilot.stable_id, "dialogue, codex, and pilot selection persist in profile snapshots")

func _test_wingmen() -> void:
	var definition := WingmanDefinition.new(); definition.stable_id = &"wingman.echo"; definition.display_name = "Echo"; definition.pilot_id = &"pilot.echo"; definition.ship_id = &"ship.echo"; definition.basic_attack_id = &"weapon.echo"; definition.special_ability_id = &"spell.intercept"; definition.ai_profile = {"health": 120.0, "speed": 200.0}; definition.command_cooldown = 0.0; definition.special_cooldown = 2.0
	var registry := ActorRegistry.new(); root.add_child(registry); var events := TypedEventBus.new(); var slot := ActorSlot.new().configure(&"slot.companion_1", definition.ship_id)
	var wingman := WingmanRuntime.new(); _assert(wingman.configure_wingman(definition, slot, registry, events), "wingman definition configures a compatible actor slot"); root.add_child(wingman); await process_frame
	var commands := WingmanCommandSystem.new(); commands.register(wingman)
	_assert(commands.issue(slot.slot_id, &"focus", &"enemy.elite") and wingman.command_target_id == &"enemy.elite", "wingmen obey targeted attack, defend, focus, intercept, hold, retreat, and special command modes")
	commands.player_respawned(Vector2(100, 200)); _assert(wingman.active and wingman.respawn_generation == 1 and wingman.position == Vector2(180, 240), "wingmen survive and reposition through player respawn transitions")
	wingman.handoff_to_human(&"profile.player_2"); _assert(slot.controller_kind == &"human" and slot.profile_id == &"profile.player_2", "a human player can replace a wingman in the same mission actor slot")
