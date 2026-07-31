class_name ProductionBoot
extends Node

const MISSION_SCENE := preload("res://production/missions/generated_mission.tscn")

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

func _ready() -> void:
	_build_interface()
	services = get_node_or_null("/root/ProductionServices") as ServiceHub
	if services == null:
		status_label.text = "Production services autoload is unavailable"
		return
	if not services.is_ready and not services.initialize_services():
		status_label.text = "Production services failed to initialize"
		return
	services.settings.setting_changed.connect(_on_setting_changed)
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
	if campaign_controller == null or not _configure_campaign():
		status_label.text = "Campaign preflight failed"
		return
	var profile := services.profiles.get_progression_profile()
	var mission_definition := campaign_controller.mission_for_stage(global_stage)
	var selected_ship := main_menu.selected_campaign_ship_id() if main_menu != null else &"ship.vanguard"
	var local_players := main_menu.selected_campaign_player_count() if main_menu != null else 1
	var config: GameSessionConfig
	if local_players == 2:
		var companion_ship := &"ship.vanguard" if selected_ship != &"ship.vanguard" else &"ship.bastion"
		var connected := Input.get_connected_joypads()
		var companion_device := int(connected[0]) if not connected.is_empty() else GameInputService.UNASSIGNED_DEVICE
		var selections: Array[Dictionary] = [
			{"device_id": GameInputService.DEVICE_KEYBOARD_MOUSE, "profile_id": profile.profile_id, "ship_id": selected_ship, "loadout": {"weapon_id": &"weapon.pulse_cannon", "spell_id": &"spell.aegis"}},
			{"device_id": companion_device, "profile_id": &"guest.local_2", "ship_id": companion_ship, "loadout": {"weapon_id": &"weapon.pulse_cannon", "spell_id": &"spell.aegis"}, "guest": true}
		]
		config = campaign_controller.create_local_coop_config(global_stage, selections, 50)
	else:
		config = campaign_controller.create_session_config(global_stage, selected_ship, {"weapon_id": &"weapon.pulse_cannon", "spell_id": &"spell.aegis"}, 50)
	if mission_definition == null or config == null:
		status_label.text = "Stage %d is locked or unavailable" % global_stage
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
	add_child(session)
	mission = MISSION_SCENE.instantiate()
	mission.configure(session, services.content_database)
	session.add_child(mission)
	session.session_completed.connect(_on_session_completed)
	diagnostics_overlay = DiagnosticsOverlay.new()
	diagnostics_overlay.configure(services.diagnostics, services.saves)
	diagnostics_overlay.visible = ProjectSettings.get_setting("development/diagnostics_visible", true)
	add_child(diagnostics_overlay)
	status_label.text = "CAMPAIGN %d/60  •  %s  •  seed %d  •  F3 diagnostics" % [global_stage, mission_definition.display_name, config.stage_seed]

func _show_main_menu(open_campaign := false) -> void:
	main_menu = MenuShell.new()
	main_menu.name = "MainMenuShell"
	main_menu.configure(services, false, campaign_controller)
	main_menu.start_requested.connect(_launch_test_mission)
	main_menu.campaign_stage_requested.connect(_launch_campaign_stage)
	add_child(main_menu)
	status_label.text = "Full campaign ready  •  60 stages  •  six operations"
	if open_campaign: main_menu.call_deferred("show_page", &"campaign", false)

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
		&"ui_scale":
			if main_menu: main_menu.root.scale = Vector2.ONE * float(value)
			if pause_menu: pause_menu.root.scale = Vector2.ONE * float(value)

func _on_session_completed(result: Dictionary) -> void:
	if campaign_controller == null or current_campaign_stage <= 0: return
	var definition := campaign_controller.mission_for_stage(current_campaign_stage)
	result.base_xp = maxi(int(definition.mission_rewards.get("xp", 0)), int(result.get("base_xp", 0)))
	result.base_currency = maxi(int(definition.mission_rewards.get("credits", 0)), int(result.get("base_currency", 0)))
	result.rank = &"C"
	var completion := campaign_controller.complete_stage(current_campaign_stage, result)
	status_label.text = "STAGE %d COMPLETE  •  rewards %s  •  save %s" % [current_campaign_stage, "claimed" if completion.get("claimed", false) else "already claimed", services.saves.status]
	_show_campaign_results(completion)

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
	if results_layer != null:
		results_layer.queue_free()
		results_layer = null
		results_screen = null
	if diagnostics_overlay != null:
		diagnostics_overlay.queue_free()
		diagnostics_overlay = null
	if session != null:
		session.queue_free()
		session = null
		mission = null
	current_campaign_stage = 0
	services.game_flow.transition_to(&"campaign_map")
	_configure_campaign()
	_show_main_menu(true)

func _on_profile_selected(_profile_ids: Array[StringName]) -> void:
	if not _configure_campaign(): return
	if main_menu != null: main_menu.set_campaign_controller(campaign_controller)
