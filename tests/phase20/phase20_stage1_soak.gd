extends SceneTree

const TARGET_SIMULATED_SECONDS := 4.0 * 60.0 * 60.0
const TIME_SCALE := 120.0
const MIN_COMPLETED_RUNS := 30

var failures := PackedStringArray()
var hub: ServiceHub
var campaign: FullCampaignController
var profile: ProgressionProfile
var simulated_seconds := 0.0
var peak_enemies := 0
var peak_projectiles := 0
var peak_pickups := 0
var peak_registry := 0
var completed_runs := 0
var initial_memory := 0
var peak_memory := 0
var storage_path := ""

func _init() -> void: call_deferred("_run")

func _run() -> void:
	await process_frame
	storage_path = "user://phase20_soak_%d" % Time.get_ticks_usec()
	hub = ServiceHub.new(); root.add_child(hub); await process_frame; hub.saves.configure_storage(storage_path)
	profile = ProgressionProfile.new(); profile.profile_id = &"profile.soak"; profile.display_name = "Soak Pilot"; profile.unlocked_content.append(&"wingman.rook")
	hub.profiles.progression_profiles = {profile.profile_id: profile}; hub.profiles.selected_profile_ids = [profile.profile_id]
	hub.settings.set_setting(&"invulnerability_assist", true, false); hub.settings.set_setting(&"auto_fire", true, false); hub.settings.set_setting(&"simplified_patterns", true, false)
	campaign = FullCampaignController.new()
	if not campaign.configure(hub.content_database, hub, profile): failures.append("campaign configuration failed")
	initial_memory = int(Performance.get_monitor(Performance.MEMORY_STATIC)); peak_memory = initial_memory
	Engine.time_scale = TIME_SCALE
	while simulated_seconds < TARGET_SIMULATED_SECONDS and failures.is_empty():
		await _run_stage_one()
	Engine.time_scale = 1.0
	var final_memory := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	if completed_runs < MIN_COMPLETED_RUNS: failures.append("fewer than %d complete Stage 1 loops finished" % MIN_COMPLETED_RUNS)
	if peak_enemies <= 0: failures.append("soak never observed a live authored enemy wave")
	if peak_pickups <= 0: failures.append("soak never observed a live pooled pickup")
	if peak_enemies > 48: failures.append("enemy prewarm capacity grew unexpectedly")
	if peak_projectiles > 360: failures.append("active projectile safety budget exceeded")
	if final_memory - initial_memory > 32 * 1024 * 1024: failures.append("memory grew by more than 32 MiB")
	var report := {"schema_version": 1, "simulated_seconds": simulated_seconds, "time_scale": TIME_SCALE, "completed_runs": completed_runs, "peak_enemies": peak_enemies, "peak_projectiles": peak_projectiles, "peak_pickups": peak_pickups, "peak_registry": peak_registry, "memory_initial_bytes": initial_memory, "memory_peak_bytes": peak_memory, "memory_final_bytes": final_memory, "memory_growth_bytes": final_memory - initial_memory, "failures": failures}
	_write_report(report)
	if failures.is_empty(): print("PHASE 20 SOAK PASS: %s" % report)
	else:
		for failure in failures: push_error("SOAK FAIL: %s" % failure)
	_cleanup(0 if failures.is_empty() else 1)

func _run_stage_one() -> void:
	var config := campaign.create_session_config(1, &"ship.vanguard", {&"primary": &"weapon.pulse_cannon", &"secondary": &"weapon.spread_cannon", &"heavy": &"weapon.missile_launcher", &"spell": &"spell.aegis", &"wingman": &"wingman.rook"}, 50, 140001 + completed_runs)
	if config == null: failures.append("Stage 1 session config failed"); return
	var session := GameSession.new()
	if not session.configure(config, hub): failures.append("Stage 1 session failed to configure"); return
	root.add_child(session)
	var mission := GeneratedMission.new(); mission.configure(session, hub.content_database); session.add_child(mission)
	for frame in 12: await physics_frame
	var run_seconds := 0.0
	while session.mission_state.get("status") == &"active" and run_seconds < 900.0:
		await physics_frame
		var delta_simulated := TIME_SCALE / float(Engine.physics_ticks_per_second)
		run_seconds += delta_simulated; simulated_seconds += delta_simulated
		# Sample before the accelerated driver clears the current encounter so the
		# concurrency measurements represent the live authored wave.
		peak_enemies = maxi(peak_enemies, mission.enemy_pool.active_count())
		peak_projectiles = maxi(peak_projectiles, mission.projectile_pool.get_active_count())
		peak_pickups = maxi(peak_pickups, mission.projectile_pool.get_active_count(&"pickup"))
		var counts := session.actor_registry.get_counts(); var registry_total := 0
		for value in counts.values(): registry_total += int(value)
		peak_registry = maxi(peak_registry, registry_total)
		peak_memory = maxi(peak_memory, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
		_drive_stage(mission)
	if session.mission_state.get("status") != &"complete":
		var runtime := mission.stage_runtime
		var detail := {"node": runtime.current_node_id if runtime != null else &"", "category": runtime.current_segment.definition.category if runtime != null and runtime.current_segment != null else "none", "segment_elapsed": runtime.current_segment.elapsed if runtime != null and runtime.current_segment != null else -1.0, "wave": runtime.current_segment.wave_scheduler.snapshot() if runtime != null and runtime.current_segment != null and runtime.current_segment.wave_scheduler != null else {}, "objectives": runtime.objectives.snapshot() if runtime != null and runtime.objectives != null else {}, "gates": runtime.current_segment._external_gates.keys() if runtime != null and runtime.current_segment != null else []}
		failures.append("Stage 1 did not complete within 900 simulated seconds: %s" % detail)
	else: completed_runs += 1
	session.queue_free(); await process_frame; await process_frame

func _drive_stage(mission: GeneratedMission) -> void:
	# Collect drops from the preceding frame first. Kills below then leave their
	# newly spawned drops live long enough for the next concurrency sample.
	for pickup in mission.projectile_pool.get_active_objects(&"pickup"):
		if pickup is ProductionPickup: pickup._on_area_entered(mission.player_actors[0])
	if mission.stage_runtime != null and mission.stage_runtime.current_segment != null:
		var runtime := mission.stage_runtime
		var node: Dictionary = runtime.plan.node_for(runtime.current_node_id)
		var choices: Array = node.get("next_ids", [])
		if choices.size() > 1 and not runtime.route_choices.has(runtime.current_node_id): runtime.choose_branch(StringName(choices[0]))
		for actor in runtime.current_segment.objective_actors:
			if not is_instance_valid(actor) or actor._resolved: continue
			if actor.faction == &"enemies": actor.receive_damage(DamagePacket.new(999999.0, mission.player_actors[0].actor_id))
			else:
				actor.position = mission.player_actors[0].position
				actor._physics_process(0.0)
	for enemy in mission.enemy_pool.active_enemies():
		if is_instance_valid(enemy) and enemy.active:
			var packet := DamagePacket.new(999999.0, mission.player_actors[0].actor_id); packet.source_player_id = mission.player_actors[0].actor_id; enemy.receive_damage(packet)
	if is_instance_valid(mission.active_boss) and mission.active_boss.active:
		var boss_packet := DamagePacket.new(9999999.0, mission.player_actors[0].actor_id); boss_packet.source_player_id = mission.player_actors[0].actor_id; mission.active_boss.receive_damage(boss_packet)

func _write_report(report: Dictionary) -> void:
	var directory := ProjectSettings.globalize_path("res://builds/reports")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open("res://builds/reports/stage1_soak_latest.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "  ")); file.close()

func _cleanup(code: int) -> void:
	hub = null; campaign = null; profile = null
	TestSupport.free_root_nodes(self); TestSupport.remove_tree(storage_path)
	call_deferred("_quit_after_cleanup", code)

func _quit_after_cleanup(code: int) -> void:
	for frame in 4: await process_frame
	quit(code)
