extends SceneTree

var failures := PackedStringArray()
var checks := 0
var database: ContentDatabase
var mission: MissionDefinition

func _init() -> void: call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		checks += 1
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)

func _run() -> void:
	database = ContentDatabase.new()
	root.add_child(database)
	_check(database.initialize(), "arcade timeline resources pass content validation")
	mission = database.get_definition(&"mission.stage1_vertical_slice", &"mission") as MissionDefinition
	_test_authored_timeline()
	_test_variant_runtime_composition()
	await _test_timeline_presentation()
	_test_overlapping_waves()
	print("ARCADE TIMELINE ACCEPTANCE: all %d checks passed" % checks if failures.is_empty() else "ARCADE TIMELINE ACCEPTANCE: %d failure(s)" % failures.size())
	mission = null
	database = null
	TestSupport.free_root_nodes(self)
	await process_frame
	call_deferred("_quit_after_cleanup", 0 if failures.is_empty() else 1)

func _quit_after_cleanup(exit_code: int) -> void:
	await process_frame
	quit(exit_code)

func _test_authored_timeline() -> void:
	var timeline := mission.encounter_timeline if mission != null else null
	var generator := StageGraphGenerator.new()
	var first := generator.generate(mission, mission.default_seed) if mission != null else null
	var replay := generator.generate(mission, mission.default_seed) if mission != null else null
	var report := StageValidator.validate(first, mission) if first != null else {}
	_check(timeline != null and timeline.beats.size() == 13 and first != null and first.main_route.size() == 12 and first.nodes.size() == 13, "Stage 1 is an explicit 12-beat route with one authored secret beat")
	_check(replay != null and first.fingerprint() == replay.fingerprint() and report.get("valid", false), "authored beat sheet is deterministic and validator-backed")
	var families := {}
	var roles := {}
	for beat in timeline.beats:
		for variant in beat.encounter_variants:
			if variant != null and variant.visual_family != null and variant.archetype != null:
				families[variant.visual_family.stable_id] = true
				roles[variant.archetype.role_name()] = true
	var complete_metadata := true
	for node in first.nodes:
		var pressure: Dictionary = node.get("pressure", {})
		complete_metadata = complete_metadata and not StringName(node.get("beat_label", "")).is_empty() and not StringName(node.get("practice_id", "")).is_empty() and int(pressure.get("high_attention_roles", 0)) <= 2
	_check(families.size() >= 8 and roles.size() >= 6 and complete_metadata, "Stage 1 provides eight visual families, six roles, practice labels, and bounded pressure")

func _test_variant_runtime_composition() -> void:
	var source := database.get_definition(&"enemy.scout_mk2", &"enemy") as EnemyDefinition
	var runtime := StageRuntime.new()
	runtime.runtime_context["timeline_beat"] = {"encounter_variant_ids": [&"encounter.frontier_scout"]}
	var generated := GeneratedMission.new()
	generated.database = database
	generated.stage_runtime = runtime
	generated.enemy_sequence = 1
	var composed := generated._apply_beat_variant(source)
	_check(composed != source and composed.encounter_variant != null and composed.resolved_visual_family().stable_id == &"visual.raider_scout", "beat cues compose an approved enemy variant at spawn time")
	runtime.free()
	generated.free()

func _test_timeline_presentation() -> void:
	var generator := StageGraphGenerator.new()
	var plan := generator.generate(mission, mission.default_seed)
	var presenter := StagePropPresenter.new()
	presenter.configure(mission.encounter_timeline)
	presenter.present(plan.nodes[0].get("landmark_ids", []))
	_check(presenter.get_child_count() > 0, "landmark cue instantiates its approved runtime prop")
	var preview := StagePreview.new()
	preview.configure(mission)
	preview._build_ui()
	preview.generate_previews(1)
	_check(preview.output.get_parsed_text().contains("Outer-Orbit Hook") and preview.output.get_parsed_text().contains("practice.stage1"), "stage preview exposes authored beat labels and practice diagnostics")
	presenter.free()
	preview.free()

func _test_overlapping_waves() -> void:
	var first := WaveDefinition.new()
	first.stable_id = &"wave.overlap_first"
	first.enemy_ids = [&"enemy.scout_mk2"]
	first.spawn_delay = 0.0
	first.next_wave_condition = &"spawned"
	var second := WaveDefinition.new()
	second.stable_id = &"wave.overlap_second"
	second.enemy_ids = [&"enemy.raider"]
	second.spawn_delay = 0.0
	var scheduler := WaveScheduler.new()
	root.add_child(scheduler)
	scheduler.configure([first, second])
	var spawned: Array[StringName] = []
	scheduler.enemy_spawn_requested.connect(func(_enemy_id, _position, _formation, _slot, wave_id): spawned.append(wave_id))
	scheduler.start()
	scheduler.tick(0.01)
	scheduler.tick(0.01)
	_check(spawned == [&"wave.overlap_first", &"wave.overlap_second"], "spawned completion condition allows controlled wave overlap")
	scheduler.notify_enemy_finished(&"wave.overlap_first")
	scheduler.tick(0.01)
	_check(scheduler.running, "first wave completion does not end an active overlapping wave")
	scheduler.notify_enemy_finished(&"wave.overlap_second")
	scheduler.tick(0.01)
	_check(not scheduler.running, "per-wave completion resolves the overlapped schedule")
	scheduler.free()
