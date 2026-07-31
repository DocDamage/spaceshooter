class_name UIComponentLibrary
extends RefCounted

## Shared constructors keep focus, sizing, and naming conventions identical across menus.
static func primary_button(text: String) -> Button:
	return _button(text, &"PrimaryButton", 58.0)

static func secondary_button(text: String) -> Button:
	return _button(text, &"SecondaryButton", 48.0)

static func icon_button(text: String, tooltip: String) -> Button:
	var button := _button(text, &"IconButton", 48.0)
	button.tooltip_text = tooltip
	button.custom_minimum_size.x = 56.0
	return button

static func segmented_control(items: PackedStringArray, selected := 0) -> OptionButton:
	var control := OptionButton.new()
	control.name = "SegmentedControl"
	control.focus_mode = Control.FOCUS_ALL
	control.custom_minimum_size = Vector2(220, 44)
	for item in items:
		control.add_item(item)
	control.select(clampi(selected, 0, maxi(0, items.size() - 1)))
	return control

static func slider(minimum: float, maximum: float, value: float, step := 0.05) -> HSlider:
	var control := HSlider.new()
	control.name = "SettingsSlider"
	control.focus_mode = Control.FOCUS_ALL
	control.custom_minimum_size = Vector2(230, 38)
	control.min_value = minimum
	control.max_value = maximum
	control.step = step
	control.value = value
	return control

static func check_box(text: String, pressed: bool) -> CheckBox:
	var control := CheckBox.new()
	control.name = "SettingsCheckBox"
	control.focus_mode = Control.FOCUS_ALL
	control.text = text
	control.button_pressed = pressed
	return control

static func drop_down(items: PackedStringArray, selected := 0) -> OptionButton:
	return segmented_control(items, selected)

static func key_binding_row(action_label: String, prompt: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "KeyBindingRow"
	var label := Label.new()
	label.text = action_label
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := secondary_button(prompt)
	button.name = "BindingButton"
	row.add_child(button)
	return row

static func card(title: String, body: String, kind: StringName = &"EquipmentCard") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = String(kind)
	panel.custom_minimum_size = Vector2(250, 112)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 20)
	box.add_child(heading)
	var description := Label.new()
	description.text = body
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	return panel

static func equipment_card(title: String, body: String) -> PanelContainer:
	return card(title, body, &"EquipmentCard")

static func ship_card(title: String, body: String) -> PanelContainer:
	return card(title, body, &"ShipCard")

static func stage_card(title: String, body: String) -> PanelContainer:
	return card(title, body, &"StageCard")

static func profile_card(title: String, body: String) -> PanelContainer:
	return card(title, body, &"ProfileCard")

static func tab_bar(tabs: PackedStringArray) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.name = "TabBar"
	for tab in tabs:
		bar.add_child(secondary_button(tab))
	return bar

static func tooltip(text: String) -> Label:
	var label := Label.new()
	label.name = "Tooltip"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

static func confirmation_dialog(title: String, message: String) -> ConfirmationDialog:
	var dialog := ConfirmationDialog.new()
	dialog.name = "ConfirmationDialog"
	dialog.title = title
	dialog.dialog_text = message
	return dialog

static func warning_dialog(title: String, message: String) -> AcceptDialog:
	var dialog := AcceptDialog.new()
	dialog.name = "WarningDialog"
	dialog.title = title
	dialog.dialog_text = message
	return dialog

static func notification_toast(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "NotificationToast"
	var label := Label.new()
	label.text = text
	panel.add_child(label)
	return panel

static func loading_indicator(text := "Loading…") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "LoadingIndicator"
	var spinner := ProgressBar.new()
	spinner.indeterminate = true
	spinner.custom_minimum_size = Vector2(70, 14)
	row.add_child(spinner)
	var label := Label.new()
	label.text = text
	row.add_child(label)
	return row

static func link_focus_chain(controls: Array[Control]) -> void:
	if controls.is_empty():
		return
	for index in controls.size():
		var current := controls[index]
		var previous := controls[(index - 1 + controls.size()) % controls.size()]
		var next := controls[(index + 1) % controls.size()]
		current.focus_neighbor_top = current.get_path_to(previous)
		current.focus_neighbor_bottom = current.get_path_to(next)
		current.focus_previous = current.get_path_to(previous)
		current.focus_next = current.get_path_to(next)

static func _button(text: String, component_name: StringName, height: float) -> Button:
	var button := Button.new()
	button.name = String(component_name)
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(250, height)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button
