class_name ProductionBoot
extends Node

const MISSION_SCENE := preload("res://production/missions/generated_mission.tscn")
const MENU_MUSIC := preload("res://assets_runtime/audio/music_menu_space_asteroids.ogg")

var session: GameSession
var mission: GeneratedMission
var title_label: Label
var status_label: Label
var main_menu: MenuShell
var pause_menu: MenuShell
var vertical_slice: StageOneVerticalSlice
var campaign_controller: FullCampaignController
var current_campaign_stage := 0
var results_layer: CanvasLayer
var results_screen: ResultsScreen
var diagnostics_overlay: DiagnosticsOverlay
var services: ServiceHub
var active_mode_id: StringName
var active_mode_run: ModeRunController
var mode_leaderboard := LocalLeaderboard.new()

func _ready() -> void:
	_build_interface()
	services = get_node_or_null("/root/ProductionServices") as ServiceHub
	if services == null:
		status_label.text = "Production services autoload is unavailable"
		return
	if not services.is_ready and not services.initialize_services():
		status_label.text = "Production services failed to initialize"
		return
	mode_leaderboard.load()
	services.settings.setting_changed.connect(_on_setting_changed)
	for display_key in [&"window_mode", &"vsync_enabled", &"frame_rate_limit", &"game_speed_assistance"]:
		_on_setting_changed(display_key, services.settings.get_setting(display_key))
	services.profiles.profile_selected.connect(_on_profile_selected)
	if not _configure_campaign():
		status_label.text = "Full campaign failed to initialize"
		return
	_show_main_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and session != null and is_instance_valid(session) and session.mission_state.get("status") == &"active" and (pause_menu == null or not pause_menu.visible):
		_show_pause_menu()
		get_viewport().set_input_as_handled()

func _build_interface() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 50
	add_child(hud)
	title_label = Label.new()
	title_label.position = Vector2(20, 18)
	title_label.add_theme_font_size_override("font_size", 25)
	title_label.text = "GALAX HERO — PRODUCTION"
	hud.add_child(title_label)
	status_label = Label.new()
	status_label.position = Vector2(20, 52)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.text = "Booting services…"
	hud.add_child(status_label)
	var version_label := Label.new()
	version_label.position = Vector2(380, 22)
	version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "dev")
	hud.add_child(version_label)

func _launch_test_mission() -> void:
	_launch_campaign_stage(1)

func _configure_campaign() -> bool:
	var profile := services.profiles.get_progression_profile()
	if profile == null: return false
	if campaign_controller == null: campaign_controller = FullCampaignController.new()
	return campaign_controller.configure(services.content_database, services, profile)

func _launch_campaign_stage(global_stage: int) -> void:
	active_mode_id = &""; active_mode_run = null
	if campaign_controller == null or not _configure_campaign():
		status_label.text = "Campaign preflight failed"
		return
	var profile := services.profiles.get_progression_profile()
	var mission_definition := campaign_controller.mission_for_stage(global_stage)
	var selected_ship := main_menu.selected_campaign_ship_id() if main_menu != null else &"ship.vanguard"
	var selected_loadout := main_menu.selected_campaign_loadout() if main_menu != null else {&"primary": &"weapon.pulse_cannon", &"spell": &"spell.aegis"}
	var local_players := main_menu.selected_campaign_player_count() if main_menu != null else 1
	var config: GameSessionConfig
	if local_players == 2:
		var companion_ship := &"ship.vanguard" if selected_ship != &"ship.vanguard" else &"ship.bastion"
		var connected := Input.get_connected_joypads()
		var companion_device := int(connected[0]) if not connected.is_empty() else GameInputService.UNASSIGNED_DEVICE
		var selections: Array[Dictionary] = [
			{"device_id": GameInputService.DEVICE_KEYBOARD_MOUSE, "profile_id": profile.profile_id, "ship_id": selected_ship, "loadout": selected_loadout.duplicate(true)},
			{"device_id": companion_device, "profile_id": &"guest.local_2", "ship_id": companion_ship, "loadout": selected_loadout.duplicate(true), "guest": true}
		]
		config = campaign_controller.create_local_coop_config(global_stage, selections, 50)
	else:
		config = campaign_controller.create_session_config(global_stage, selected_ship, selected_loadout, 50)
	if mission_definition == null or config == null:
		status_label.text = "Stage %d is locked or unavailable" % global_stage
		return
	_start_session(global_stage, config)

func _start_session(global_stage: int, config: GameSessionConfig, resume_snapshot: Dictionary = {}) -> void:
	var mission_definition := campaign_controller.mission_for_stage(global_stage)
	var local_players := int(config.multiplayer_configuration.get("local_players", 1))
	if mission_definition == null:
		status_label.text = "Stage %d is unavailable" % global_stage
		return
	if main_menu:
		main_menu.queue_free()
		main_menu = null
	current_campaign_stage = global_stage
	config.mode_rules.merge({"friendly_fire": false, "continues": 3}, true)
	if local_players == 1: config.multiplayer_configuration = {"local_players": 1, "online": false}
	session = GameSession.new()
	session.name = "GameSession"
	if not session.configure(config, services):
		status_label.text = "Session configuration failed"
		return
	if not resume_snapshot.is_empty() and not session.restore_checkpoint(resume_snapshot):
		status_label.text = "Checkpoint recovery failed validation"
		session = null
		return
	session.session_completed.connect(_on_session_completed)
	add_child(session)
	mission = MISSION_SCENE.instantiate()
	mission.configure(session, services.content_database)
	session.add_child(mission)
	diagnostics_overlay = DiagnosticsOverlay.new()
	diagnostics_overlay.configure(services.diagnostics, services.saves)
	diagnostics_overlay.visible = OS.is_debug_build() and bool(ProjectSettings.get_setting("development/enabled", false)) and bool(ProjectSettings.get_setting("development/diagnostics_visible", true))
	add_child(diagnostics_overlay)
	var diagnostics_hint := "  •  F3 diagnostics" if diagnostics_overlay.visible else ""
	status_label.text = "CAMPAIGN %d/60  •  %s  •  seed %d%s" % [global_stage, mission_definition.display_name, config.stage_seed, diagnostics_hint]

func _show_main_menu(open_campaign := false) -> void:
	services.audio.play_music(MENU_MUSIC, true)
	main_menu = MenuShell.new()
	main_menu.name = "MainMenuShell"
	main_menu.configure(services, false, campaign_controller)
	main_menu.start_requested.connect(_launch_test_mission)
	main_menu.campaign_stage_requested.connect(_launch_campaign_stage)
	main_menu.mode_requested.connect(_launch_mode)
	add_child(main_menu)
	status_label.text = "Full campaign ready  •  60 stages  •  six operations"
	if open_campaign: main_menu.call_deferred("show_page", &"campaign", false)

func _launch_mode(mode_id: StringName, global_stage: int, difficulty: int, seed: int, player_count: int, ship_id: StringName, loadout: Dictionary) -> void:
	if campaign_controller == null or not _configure_campaign(): return
	var mode := ModeCatalog.get_mode(mode_id)
	if mode == null:
		status_label.text = "Mode configuration is unavailable"
		return
	var profile := services.profiles.get_progression_profile()
	var config: GameSessionConfig
	if player_count == 2 and mode.multiplayer_allowed:
		var connected := Input.get_connected_joypads()
		var companion_device := int(connected[0]) if not connected.is_empty() else GameInputService.UNASSIGNED_DEVICE
		var companion_ship := &"ship.bastion" if ship_id != &"ship.bastion" else &"ship.vanguard"
		config = campaign_controller.create_local_coop_config(global_stage, [
			{"device_id": GameInputService.DEVICE_KEYBOARD_MOUSE, "profile_id": profile.profile_id, "ship_id": ship_id, "loadout": loadout.duplicate(true)},
			{"device_id": companion_device, "profile_id": &"guest.mode_2", "ship_id": companion_ship, "loadout": loadout.duplicate(true), "guest": true}
		], difficulty, seed)
	else:
		config = campaign_controller.create_session_config(global_stage, ship_id, loadout, difficulty, seed)
	if config == null:
		status_label.text = "The selected stage is locked or unavailable for this mode"
		return
	config.difficulty_profile = &"veteran" if difficulty >= 70 else &"normal"
	config.mode_rules.merge(mode.snapshot(), true)
	config.mode_rules.merge(mode.rules, true)
	config.mode_rules.campaign = false
	config.mode_rules.mode_id = mode_id
	config.mode_rules.difficulty_rating = difficulty
	config.mode_rules.disable_campaign_rewards = true
	active_mode_id = mode_id
	active_mode_run = ModeRunController.new()
	active_mode_run.start(mode, config.stage_seed, difficulty, [])
	_start_session(global_stage, config)

func _show_pause_menu() -> void:
	get_tree().paused = true
	pause_menu = MenuShell.new()
	pause_menu.name = "PauseMenuShell"
	pause_menu.configure(services, true)
	pause_menu.resume_requested.connect(_resume_mission)
	add_child(pause_menu)

func _resume_mission() -> void:
	if pause_menu:
		pause_menu.queue_free()
		pause_menu = null
	get_tree().paused = false

func _on_setting_changed(key: StringName, value: Variant) -> void:
	match key:
		&"master_volume": services.audio.set_master_volume(float(value))
		&"game_speed_assistance": Engine.time_scale = float(value)
		&"window_mode":
			match String(value):
				"fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
				"borderless": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				_: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		&"vsync_enabled": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(value) else DisplayServer.VSYNC_DISABLED)
		&"frame_rate_limit": Engine.max_fps = maxi(0, int(value))
		&"ui_scale":
			if main_menu: main_menu.root.scale = Vector2.ONE * float(value)
			if pause_menu: pause_menu.root.scale = Vector2.ONE * float(value)

func _on_session_completed(result: Dictionary) -> void:
	if campaign_controller == null or current_campaign_stage <= 0: return
	if not active_mode_id.is_empty():
		_complete_mode_run(result)
		return
	if not bool(result.get("success", false)):
		if mission != null: mission.process_mode = Node.PROCESS_MODE_DISABLED
		status_label.text = "STAGE %d FAILED  •  checkpoint %s" % [current_campaign_stage, "available" if not session.checkpoint_snapshot.is_empty() else "unavailable"]
		_show_failure_results(result)
		return
	var definition := campaign_controller.mission_for_stage(current_campaign_stage)
	result.base_xp = maxi(int(definition.mission_rewards.get("xp", 0)), int(result.get("base_xp", 0)))
	result.base_currency = maxi(int(definition.mission_rewards.get("credits", 0)), int(result.get("base_currency", 0)))
	if not result.has("rank"): result.rank = &"C"
	var completion := campaign_controller.complete_stage(current_campaign_stage, result)
	status_label.text = "STAGE %d COMPLETE  •  rewards %s  •  save %s" % [current_campaign_stage, "claimed" if completion.get("claimed", false) else "already claimed", services.saves.status]
	_show_campaign_results(completion)

func _show_failure_results(result: Dictionary) -> void:
	if results_layer != null: results_layer.queue_free()
	results_layer = CanvasLayer.new(); results_layer.layer = 60; add_child(results_layer)
	var shade := ColorRect.new(); shade.color = Color(0.015, 0.025, 0.065, 0.92); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); results_layer.add_child(shade)
	var panel := PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); panel.position = Vector2(-190, -190); panel.size = Vector2(380, 380); shade.add_child(panel)
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 30); margin.add_theme_constant_override("margin_right", 30); margin.add_theme_constant_override("margin_top", 28); margin.add_theme_constant_override("margin_bottom", 28); panel.add_child(margin)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 14); margin.add_child(box)
	var title := Label.new(); title.text = "MISSION FAILED"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 28); box.add_child(title)
	var summary := Label.new(); summary.text = "Score %06d  •  Rank %s\n%s" % [int(result.get("score", 0)), String(result.get("rank", &"D")), String(result.get("failure_reason", &"combat_loss")).replace("_", " ").capitalize()]; summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(summary)
	var retry := Button.new(); retry.text = "Retry Stage"; retry.custom_minimum_size.y = 52; retry.pressed.connect(_restart_stage); box.add_child(retry)
	var resume := Button.new(); resume.text = "Resume Checkpoint"; resume.custom_minimum_size.y = 52; resume.disabled = session == null or session.checkpoint_snapshot.is_empty(); resume.pressed.connect(_resume_checkpoint); box.add_child(resume)
	var abandon := Button.new(); abandon.text = "Abandon to Campaign"; abandon.custom_minimum_size.y = 52; abandon.pressed.connect(_abandon_to_campaign); box.add_child(abandon)
	retry.call_deferred("grab_focus")

func _restart_stage() -> void:
	if session == null: return
	var config := session.config
	var stage := current_campaign_stage
	_cleanup_current_session()
	if not active_mode_id.is_empty():
		var definition := ModeCatalog.get_mode(active_mode_id)
		active_mode_run = ModeRunController.new()
		active_mode_run.start(definition, config.stage_seed, int(config.mode_rules.get("difficulty_rating", 50)), [])
	_start_session(stage, config)

func _resume_checkpoint() -> void:
	if session == null or session.checkpoint_snapshot.is_empty(): return
	var config := session.config
	var snapshot := session.checkpoint_snapshot.duplicate(true)
	var stage := current_campaign_stage
	_cleanup_current_session()
	_start_session(stage, config, snapshot)

func _abandon_to_campaign() -> void:
	_cleanup_current_session()
	current_campaign_stage = 0
	active_mode_id = &""; active_mode_run = null
	services.game_flow.transition_to(&"campaign_map")
	_configure_campaign()
	_show_main_menu(true)

func _cleanup_current_session() -> void:
	get_tree().paused = false
	if pause_menu != null: pause_menu.queue_free(); pause_menu = null
	if results_layer != null: results_layer.queue_free(); results_layer = null; results_screen = null
	if diagnostics_overlay != null: diagnostics_overlay.queue_free(); diagnostics_overlay = null
	if session != null: session.queue_free(); session = null; mission = null

func _show_campaign_results(completion: Dictionary) -> void:
	results_layer = CanvasLayer.new()
	results_layer.layer = 60
	add_child(results_layer)
	results_screen = ResultsScreen.new()
	var narrative := ""
	var choices: Array = []
	var mission_definition := campaign_controller.mission_for_stage(current_campaign_stage)
	var results_id := StringName(mission_definition.dialogue_hooks.get("results", ""))
	var results_dialogue := services.content_database.get_definition(results_id, &"dialogue") as DialogueDefinition
	if results_dialogue != null:
		var lines := PackedStringArray()
		for line in results_dialogue.lines:
			lines.append("%s: %s" % [line.get("speaker", ""), line.get("text", "")])
			if not line.get("choices", []).is_empty(): choices = line.get("choices", []).duplicate(true)
		narrative = "\n".join(lines)
	results_screen.configure_persisted(services.profiles.get_progression_profile(), completion, narrative, choices)
	results_screen.decision_selected.connect(_record_campaign_decision)
	results_screen.continue_requested.connect(_return_to_campaign_map)
	results_layer.add_child(results_screen)

func _record_campaign_decision(decision_id: StringName, value: Variant) -> void:
	if campaign_controller != null: campaign_controller.record_campaign_decision(decision_id, value)

func _return_to_campaign_map() -> void:
	_cleanup_current_session()
	current_campaign_stage = 0
	active_mode_id = &""; active_mode_run = null
	services.game_flow.transition_to(&"campaign_map")
	_configure_campaign()
	_show_main_menu(true)

func _on_profile_selected(_profile_ids: Array[StringName]) -> void:
	if not _configure_campaign(): return
	if main_menu != null: main_menu.set_campaign_controller(campaign_controller)

func _complete_mode_run(result: Dictionary) -> void:
	if active_mode_run == null: return
	active_mode_run.score = maxi(0, int(result.get("score", 0)))
	active_mode_run.elapsed_seconds = maxf(0.0, float(result.get("elapsed_seconds", 0.0)))
	active_mode_run.active_assists.assign(result.get("run_metadata", {}).get("active_assists", []))
	var mode_result := active_mode_run.finish(bool(result.get("success", false)), mode_leaderboard)
	mode_leaderboard.save()
	if mission != null: mission.process_mode = Node.PROCESS_MODE_DISABLED
	_show_mode_results(mode_result, StringName(result.get("failure_reason", "")))

func _show_mode_results(result: Dictionary, failure_reason: StringName) -> void:
	if results_layer != null: results_layer.queue_free()
	results_layer = CanvasLayer.new(); results_layer.layer = 60; add_child(results_layer)
	var shade := ColorRect.new(); shade.color = Color(0.015, 0.025, 0.065, 0.94); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); results_layer.add_child(shade)
	var panel := PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); panel.position = Vector2(-200, -190); panel.size = Vector2(400, 380); shade.add_child(panel)
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 28); margin.add_theme_constant_override("margin_right", 28); margin.add_theme_constant_override("margin_top", 26); margin.add_theme_constant_override("margin_bottom", 26); panel.add_child(margin)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 14); margin.add_child(box)
	var definition := ModeCatalog.get_mode(active_mode_id)
	var title := Label.new(); title.text = "%s RESULTS" % (definition.display_name.to_upper() if definition != null else "MODE"); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 27); box.add_child(title)
	var summary := Label.new(); summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; summary.text = "Score %06d\nTime %0.1f s\nSeed %d\n%s" % [int(result.get("score", 0)), float(result.get("elapsed_seconds", 0.0)), int(result.get("seed", 0)), "Complete" if bool(result.get("success", false)) else String(failure_reason).replace("_", " ").capitalize()]; box.add_child(summary)
	var retry := UIComponentLibrary.primary_button("Retry Same Seed"); retry.pressed.connect(_restart_stage); box.add_child(retry)
	var modes := UIComponentLibrary.secondary_button("Return to Modes"); modes.pressed.connect(_return_to_modes); box.add_child(modes)
	retry.call_deferred("grab_focus")

func _return_to_modes() -> void:
	_cleanup_current_session()
	current_campaign_stage = 0
	active_mode_id = &""; active_mode_run = null
	_configure_campaign(); _show_main_menu(); main_menu.call_deferred("show_page", &"modes", false)
