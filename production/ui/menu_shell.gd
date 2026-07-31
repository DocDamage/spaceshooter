class_name MenuShell
extends CanvasLayer

signal start_requested
signal resume_requested
signal campaign_stage_requested(global_stage: int)

var services: ServiceHub
var root: Control
var page_host: MarginContainer
var breadcrumb: Label
var prompt_label: Label
var page_stack: Array[StringName] = []
var current_page: StringName = &""
var is_pause_shell := false
var _capture_action: StringName = &""
var _capture_button: Button
var _profile_name_sequence := 1
var campaign_controller: FullCampaignController
var campaign_model: CampaignMapModel
var campaign_ship_id: StringName = &"ship.vanguard"
var campaign_local_players := 1

func configure(service_hub: ServiceHub, pause_shell := false, full_campaign: FullCampaignController = null) -> void:
	services = service_hub
	is_pause_shell = pause_shell
	campaign_controller = full_campaign

func set_campaign_controller(full_campaign: FullCampaignController) -> void:
	campaign_controller = full_campaign
	campaign_model = null
	if is_inside_tree() and current_page == &"campaign": show_page(&"campaign", false)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_shell()
	services.input.active_device_changed.connect(_on_active_device_changed)
	services.input.controller_connection_changed.connect(_on_controller_connection_changed)
	show_page(&"pause" if is_pause_shell else &"main", false)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not _capture_action.is_empty():
		if event.is_action_pressed(&"ui_cancel"):
			_end_capture(false)
		elif event.is_pressed() and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion):
			if event is InputEventJoypadMotion and absf(event.axis_value) < 0.6:
				return
			var conflicts := services.input.get_conflicts(_capture_action, event)
			if conflicts.is_empty() or services.input.rebind(_capture_action, event, &"replace"):
				_end_capture(true)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()

func show_page(page: StringName, push_history := true) -> void:
	if push_history and not current_page.is_empty():
		page_stack.append(current_page)
	current_page = page
	for child in page_host.get_children():
		child.queue_free()
	var content: Control
	match page:
		&"main": content = _main_page()
		&"pause": content = _pause_page()
		&"campaign": content = _campaign_page()
		&"profiles": content = _profiles_page()
		&"save_recovery": content = _save_recovery_page()
		&"settings": content = _settings_page()
		&"accessibility": content = _accessibility_page()
		&"bindings": content = _bindings_page()
		&"input_test": content = _input_test_page()
		_: content = _message_page("Unavailable", "This page has not been registered.")
	page_host.add_child(content)
	breadcrumb.text = ("PAUSED / " if is_pause_shell else "COMMAND / ") + String(page).replace("_", " ").to_upper()
	call_deferred("_focus_first", content)

func _build_shell() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.035, 0.08, 0.97)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 28)
	root.add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var title := Label.new()
	title.text = "GALAX HERO"
	title.add_theme_font_size_override("font_size", 34)
	layout.add_child(title)
	breadcrumb = Label.new()
	breadcrumb.modulate = Color("72d8ff")
	layout.add_child(breadcrumb)
	var separator := HSeparator.new()
	layout.add_child(separator)
	page_host = MarginContainer.new()
	page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(page_host)
	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label.text = _prompt_text()
	layout.add_child(prompt_label)

func _main_page() -> Control:
	var box := _page_box("Pilot systems online.")
	_add_nav_button(box, "Campaign Map — Operations 1–6", func(): show_page(&"campaign"))
	_add_nav_button(box, "Launch Stage 1 — First Contact", func(): start_requested.emit())
	_add_nav_button(box, "Profile Select", func(): show_page(&"profiles"))
	_add_nav_button(box, "Settings", func(): show_page(&"settings"))
	_add_nav_button(box, "Input Test", func(): show_page(&"input_test"))
	var quit := UIComponentLibrary.secondary_button("Quit")
	quit.pressed.connect(_confirm_quit)
	box.add_child(quit)
	return box

func _campaign_page() -> Control:
	if campaign_controller == null:
		return _message_page("Campaign unavailable", "The campaign controller could not be configured.")
	campaign_model = CampaignMapModel.new()
	campaign_model.configure(campaign_controller.campaign)
	var box := _page_box("Navigate all six operations. Completed stages may be replayed; locked stages require their preceding mission.")
	var available_ships: Array[ShipDefinition] = []
	var profile := services.profiles.get_progression_profile()
	for definition in services.content_database.get_definitions_by_type(&"ship"):
		var ship := definition as ShipDefinition
		if ship != null and (ship.stable_id == &"ship.vanguard" or profile.unlocked_content.has(ship.stable_id)): available_ships.append(ship)
	if available_ships.is_empty():
		var fallback := services.content_database.get_definition(&"ship.vanguard", &"ship") as ShipDefinition
		if fallback != null: available_ships.append(fallback)
	var ship_names := PackedStringArray()
	var selected_ship_index := 0
	for index in available_ships.size():
		ship_names.append(available_ships[index].display_name)
		if available_ships[index].stable_id == campaign_ship_id: selected_ship_index = index
	var ship_picker := UIComponentLibrary.drop_down(ship_names, selected_ship_index)
	ship_picker.name = "CampaignShipPicker"
	if not available_ships.is_empty(): campaign_ship_id = available_ships[selected_ship_index].stable_id
	ship_picker.item_selected.connect(func(index): campaign_ship_id = available_ships[index].stable_id)
	_add_labeled_control(box, "Ship", ship_picker)
	var player_picker := UIComponentLibrary.drop_down(PackedStringArray(["Solo", "Local Co-op (2 Players)"]), campaign_local_players - 1)
	player_picker.name = "CampaignPlayerCount"
	player_picker.item_selected.connect(func(index): campaign_local_players = index + 1)
	_add_labeled_control(box, "Players", player_picker)
	var map_view := CampaignMapView.new()
	map_view.name = "FullCampaignMap"
	map_view.custom_minimum_size = Vector2(460, 180)
	map_view.configure(campaign_model)
	map_view.node_confirmed.connect(_request_campaign_node)
	box.add_child(map_view)
	var navigation := HBoxContainer.new()
	var previous := UIComponentLibrary.secondary_button("Previous")
	previous.pressed.connect(func(): campaign_model.navigate(-1))
	navigation.add_child(previous)
	var launch := UIComponentLibrary.primary_button("Launch Selected Stage")
	launch.pressed.connect(func():
		var selected := campaign_model.selected_node()
		if selected.get("state") in [&"available", &"completed"]: _request_campaign_node(StringName(selected.node_id)))
	navigation.add_child(launch)
	var next := UIComponentLibrary.secondary_button("Next")
	next.pressed.connect(func(): campaign_model.navigate(1))
	navigation.add_child(next)
	box.add_child(navigation)
	_add_back_button(box)
	return box

func _request_campaign_node(node_id: StringName) -> void:
	var global_stage := campaign_controller.global_stage_for_node(node_id) if campaign_controller != null else 0
	if global_stage > 0: campaign_stage_requested.emit(global_stage)

func selected_campaign_ship_id() -> StringName:
	return campaign_ship_id

func selected_campaign_player_count() -> int:
	return campaign_local_players

func _pause_page() -> Control:
	var box := _page_box("Mission paused")
	_add_nav_button(box, "Resume", func(): resume_requested.emit())
	_add_nav_button(box, "Settings", func(): show_page(&"settings"))
	_add_nav_button(box, "Input Test", func(): show_page(&"input_test"))
	return box

func _profiles_page() -> Control:
	var box := _page_box("Create, select, duplicate, rename, or delete a local pilot. Save operations retain two recovery generations.")
	for summary in services.profiles.profile_summaries():
		var row := HBoxContainer.new()
		var hours := int(summary.playtime_seconds) / 3600
		var minutes := (int(summary.playtime_seconds) % 3600) / 60
		var progress: Dictionary = summary.campaign_progress
		var body := "Level %d • %02d:%02d • Campaign %d%%\nLast: %s • NG+ %d" % [summary.level, hours, minutes, int(progress.get("percent", 0)), String(summary.last_played_stage) if not String(summary.last_played_stage).is_empty() else "—", summary.new_game_plus_cycle]
		row.add_child(UIComponentLibrary.profile_card(summary.display_name, body))
		var select := UIComponentLibrary.primary_button("SELECT" if summary.profile_id not in services.profiles.selected_profile_ids else "SELECTED")
		select.disabled = summary.profile_id in services.profiles.selected_profile_ids
		select.pressed.connect(func(): services.profiles.select_profiles([StringName(summary.profile_id)]); show_page(&"profiles", false))
		row.add_child(select)
		var duplicate := UIComponentLibrary.icon_button("COPY", "Duplicate profile")
		duplicate.pressed.connect(func(): services.profiles.duplicate_profile(StringName(summary.profile_id)); show_page(&"profiles", false))
		row.add_child(duplicate)
		var rename := UIComponentLibrary.icon_button("RENAME", "Assign a generated pilot name")
		rename.pressed.connect(func(): _profile_name_sequence += 1; services.profiles.rename_profile(StringName(summary.profile_id), "Pilot %d" % _profile_name_sequence); show_page(&"profiles", false))
		row.add_child(rename)
		var remove := UIComponentLibrary.icon_button("DELETE", "Delete this profile")
		remove.disabled = services.profiles.progression_profiles.size() <= 1
		remove.pressed.connect(_confirm_profile_delete.bind(StringName(summary.profile_id)))
		row.add_child(remove)
		box.add_child(row)
	var create := UIComponentLibrary.primary_button("Create New Pilot")
	create.disabled = services.profiles.progression_profiles.size() >= ProfileService.MAX_PROFILES
	create.pressed.connect(func(): _profile_name_sequence += 1; services.profiles.create_profile("Pilot %d" % _profile_name_sequence); show_page(&"profiles", false))
	box.add_child(create)
	if services.saves.status == &"corrupt" or services.saves.status == &"recovered":
		_add_nav_button(box, "Save Recovery Details", func(): show_page(&"save_recovery"))
	_add_back_button(box)
	return _scroll(box)

func _save_recovery_page() -> Control:
	var panel := SaveRecoveryPanel.new()
	panel.configure(services.saves, services.saves.last_recovery_report)
	panel.dismissed.connect(func(): show_page(&"profiles", false))
	return panel

func _confirm_profile_delete(profile_id: StringName) -> void:
	var profile := services.profiles.get_progression_profile(profile_id, false)
	if profile == null: return
	var dialog := UIComponentLibrary.confirmation_dialog("Delete %s?" % profile.display_name, "The profile and checkpoint files will be permanently removed. Other profiles are unaffected.")
	root.add_child(dialog)
	dialog.confirmed.connect(func(): services.profiles.delete_profile(profile_id); show_page(&"profiles", false))
	dialog.popup_centered()

func _settings_page() -> Control:
	var box := _page_box("Settings save automatically.")
	_add_nav_button(box, "Accessibility", func(): show_page(&"accessibility"))
	_add_nav_button(box, "Controls & Rebinding", func(): show_page(&"bindings"))
	_add_slider_setting(box, "Controller dead zone", &"controller_dead_zone", 0.05, 0.75, 0.05)
	_add_slider_setting(box, "Aim sensitivity", &"aim_sensitivity", 0.25, 2.0, 0.05)
	_add_slider_setting(box, "Movement sensitivity", &"movement_sensitivity", 0.25, 2.0, 0.05)
	_add_toggle_setting(box, "Analog movement", &"analog_movement")
	_add_toggle_setting(box, "Vibration", &"vibration_enabled")
	_add_slider_setting(box, "Vibration strength", &"vibration_strength", 0.0, 1.0, 0.05)
	var glyphs := PackedStringArray(["Auto", "Xbox", "PlayStation", "Nintendo"])
	var glyph_setting := String(services.settings.get_setting(&"glyph_family", "auto"))
	var glyph_index := ["auto", "xbox", "playstation", "nintendo"].find(glyph_setting)
	var glyph_picker := UIComponentLibrary.drop_down(glyphs, maxi(0, glyph_index))
	glyph_picker.item_selected.connect(func(index): services.settings.set_setting(&"glyph_family", glyphs[index].to_lower()))
	_add_labeled_control(box, "Prompt glyphs", glyph_picker)
	for category in ["damage", "weapon", "impact", "ui"]:
		_add_vibration_category(box, category)
	var restore := UIComponentLibrary.secondary_button("Restore Defaults")
	restore.pressed.connect(func(): services.settings.restore_defaults(); services.input.restore_default_bindings(); show_page(&"settings", false))
	box.add_child(restore)
	_add_back_button(box)
	return _scroll(box)

func _accessibility_page() -> Control:
	var split := HBoxContainer.new()
	var box := _page_box("Changes apply to the live preview and save immediately.")
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var modes := PackedStringArray(["Off", "Protanopia", "Deuteranopia", "Tritanopia"])
	var colorblind := UIComponentLibrary.segmented_control(modes, modes.find(String(services.settings.get_setting(&"colorblind_filter", "off")).capitalize()))
	_add_labeled_control(box, "Colorblind filter", colorblind)
	colorblind.item_selected.connect(func(index): services.settings.set_setting(&"colorblind_filter", modes[index].to_lower()))
	var hostile_colors := PackedStringArray(["Red", "Orange", "Magenta"])
	var hostile_values := ["ff566d", "ff9f43", "ff5ee7"]
	var hostile_picker := UIComponentLibrary.drop_down(hostile_colors)
	hostile_picker.item_selected.connect(func(index): services.settings.set_setting(&"hostile_bullet_color", hostile_values[index]))
	_add_labeled_control(box, "Hostile bullet color", hostile_picker)
	var friendly_colors := PackedStringArray(["Cyan", "Green", "White"])
	var friendly_values := ["62dcff", "66ff9a", "ffffff"]
	var friendly_picker := UIComponentLibrary.drop_down(friendly_colors)
	friendly_picker.item_selected.connect(func(index): services.settings.set_setting(&"friendly_bullet_color", friendly_values[index]))
	_add_labeled_control(box, "Friendly bullet color", friendly_picker)
	_add_toggle_setting(box, "Projectile outline", &"projectile_outline")
	_add_toggle_setting(box, "Player outline", &"player_outline")
	_add_slider_setting(box, "Screen shake", &"screen_shake_scale", 0, 1, 0.1)
	_add_slider_setting(box, "Flash reduction", &"flash_reduction", 0, 1, 0.1)
	_add_slider_setting(box, "Particle density", &"particle_density", 0, 1, 0.1)
	_add_slider_setting(box, "Background motion reduction", &"background_motion_reduction", 0, 1, 0.1)
	_add_slider_setting(box, "UI scale", &"ui_scale", 0.75, 1.5, 0.05)
	_add_slider_setting(box, "Text scale", &"text_scale", 0.75, 1.75, 0.05)
	_add_slider_setting(box, "Aim assistance", &"aim_assistance", 0, 1, 0.1)
	_add_slider_setting(box, "Game speed assistance", &"game_speed_assistance", 0.5, 1, 0.05)
	for pair in [["Auto-fire", &"auto_fire"], ["Toggle focus", &"focus_toggle"], ["Toggle shield", &"shield_toggle"], ["System damage", &"system_damage_enabled"], ["Simplified patterns", &"simplified_patterns"], ["Invulnerability assist", &"invulnerability_assist"]]:
		_add_toggle_setting(box, pair[0], pair[1])
	_add_back_button(box)
	var preview := AccessibilityPreview.new()
	preview.configure(services.settings)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_scroll(box))
	split.add_child(preview)
	return split

func _bindings_page() -> Control:
	var box := _page_box("Select a binding, then press a key, mouse button, controller button, or axis. Conflicts are replaced; Enter and Escape remain emergency bindings.")
	for action in GameInputService.ACTION_NAMES:
		var row := UIComponentLibrary.key_binding_row(String(action).replace("_", " ").capitalize(), services.input.get_prompt(action))
		var button := row.get_node("BindingButton") as Button
		button.pressed.connect(_begin_capture.bind(action, button))
		box.add_child(row)
	var restore := UIComponentLibrary.secondary_button("Restore Default Bindings")
	restore.pressed.connect(func(): services.input.restore_default_bindings(); show_page(&"bindings", false))
	box.add_child(restore)
	_add_back_button(box)
	return _scroll(box)

func _input_test_page() -> Control:
	var box := _page_box("Move sticks, press controls, and connect or disconnect controllers.")
	var device := Label.new()
	device.name = "DeviceReadout"
	device.text = "Last device: %s • glyphs: %s" % [services.input.last_device_kind, services.input.get_glyph_family()]
	box.add_child(device)
	var movement := Label.new()
	movement.name = "MovementReadout"
	movement.text = "Movement: 0, 0 • Aim: 0, 0"
	box.add_child(movement)
	var controllers := Label.new()
	controllers.name = "ControllerReadout"
	controllers.text = "Connected controllers: %s" % Input.get_connected_joypads()
	box.add_child(controllers)
	var updater := Timer.new()
	updater.wait_time = 0.05
	updater.autostart = true
	updater.timeout.connect(func():
		if is_instance_valid(movement): movement.text = "Movement: %s • Aim: %s" % [services.input.get_move_vector(0), services.input.get_aim_vector(0)]
		if is_instance_valid(device): device.text = "Last device: %s • glyphs: %s" % [services.input.last_device_kind, services.input.get_glyph_family()]
		if is_instance_valid(controllers): controllers.text = "Connected controllers: %s" % Input.get_connected_joypads())
	box.add_child(updater)
	_add_back_button(box)
	return box

func _message_page(title: String, message: String) -> Control:
	var box := _page_box(title)
	var label := Label.new(); label.text = message; box.add_child(label)
	_add_back_button(box)
	return box

func _page_box(description: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = description
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	return box

func _scroll(content: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(content)
	return scroll

func _add_nav_button(box: VBoxContainer, text: String, callback: Callable) -> void:
	var button := UIComponentLibrary.primary_button(text)
	button.pressed.connect(callback)
	box.add_child(button)

func _add_back_button(box: VBoxContainer) -> void:
	var button := UIComponentLibrary.secondary_button("Back")
	button.pressed.connect(_go_back)
	box.add_child(button)

func _add_toggle_setting(box: VBoxContainer, text: String, key: StringName) -> void:
	var control := UIComponentLibrary.check_box(text, bool(services.settings.get_setting(key, false)))
	control.toggled.connect(func(value): services.settings.set_setting(key, value))
	box.add_child(control)

func _add_vibration_category(box: VBoxContainer, category: String) -> void:
	var categories: Dictionary = services.settings.get_setting(&"vibration_categories", {})
	var control := UIComponentLibrary.check_box("Vibration: %s" % category.capitalize(), bool(categories.get(category, true)))
	control.toggled.connect(func(value):
		var changed: Dictionary = services.settings.get_setting(&"vibration_categories", {}).duplicate(true)
		changed[category] = value
		services.settings.set_setting(&"vibration_categories", changed))
	box.add_child(control)

func _add_slider_setting(box: VBoxContainer, text: String, key: StringName, minimum: float, maximum: float, step: float) -> void:
	var control := UIComponentLibrary.slider(minimum, maximum, float(services.settings.get_setting(key, minimum)), step)
	control.value_changed.connect(func(value): services.settings.set_setting(key, value))
	_add_labeled_control(box, text, control)

func _add_labeled_control(box: VBoxContainer, text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new(); label.text = text; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
	row.add_child(control)
	box.add_child(row)

func _go_back() -> void:
	if not page_stack.is_empty():
		show_page(page_stack.pop_back(), false)
	elif is_pause_shell:
		resume_requested.emit()

func _focus_first(scope: Control) -> void:
	var controls: Array[Control] = []
	_collect_focusable(scope, controls)
	UIComponentLibrary.link_focus_chain(controls)
	if not controls.is_empty():
		controls[0].grab_focus()

func _collect_focusable(node: Node, result: Array[Control]) -> void:
	if node is Control and node.focus_mode == Control.FOCUS_ALL and node.is_visible_in_tree():
		result.append(node)
	for child in node.get_children():
		_collect_focusable(child, result)

func _begin_capture(action: StringName, button: Button) -> void:
	_capture_action = action
	_capture_button = button
	button.text = "Press a control… (Cancel to stop)"

func _end_capture(changed: bool) -> void:
	if is_instance_valid(_capture_button):
		_capture_button.text = services.input.get_prompt(_capture_action) if changed else "Cancelled"
	_capture_action = &""
	_capture_button = null

func _assign_picker(item: int, player_index: int, picker: OptionButton) -> void:
	var device := GameInputService.DEVICE_KEYBOARD_MOUSE if item == 0 else GameInputService.UNASSIGNED_DEVICE if item == 1 else Input.get_connected_joypads()[item - 2]
	if not services.input.assign_device(player_index, device):
		picker.select(1)
		var warning := UIComponentLibrary.warning_dialog("Device already assigned", "A device may control only one local player.")
		root.add_child(warning)
		warning.popup_centered()

func _confirm_quit() -> void:
	var dialog := UIComponentLibrary.confirmation_dialog("Quit Galax Hero?", "Unsaved mission progress will be lost.")
	root.add_child(dialog)
	dialog.confirmed.connect(func(): get_tree().quit())
	dialog.popup_centered()

func _on_active_device_changed(_kind: StringName, _device: int, _glyph: StringName) -> void:
	prompt_label.text = _prompt_text()

func _on_controller_connection_changed(_device: int, _connected: bool) -> void:
	prompt_label.text = _prompt_text()

func _prompt_text() -> String:
	return "%s Confirm    %s Back" % [services.input.get_prompt(&"ui_confirm") if services else "Enter", services.input.get_prompt(&"ui_cancel") if services else "Esc"]
