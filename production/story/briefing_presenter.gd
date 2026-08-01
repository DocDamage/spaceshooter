class_name BriefingPresenter
extends PanelContainer

var adapter: DialogueManagerAdapter
var portrait := TextureRect.new()
var speaker_label := Label.new()
var line_label := Label.new()
var continue_button := Button.new()
var choice_box := VBoxContainer.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -250; offset_right = 250; offset_top = -250; offset_bottom = 250
	theme = GalaxHeroTheme.create()
	var hub := get_node_or_null("/root/ProductionServices") as ServiceHub
	var opacity := float(hub.settings.get_setting(&"subtitle_background_opacity", 0.88)) if hub != null else 0.88
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.006, 0.02, 0.055, opacity)
	style.border_color = Color("3fa6cf")
	style.set_border_width_all(2)
	style.border_width_top = 4
	style.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var title := Label.new()
	title.text = "MISSION BRIEFING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	box.add_child(title)
	var separator := HSeparator.new()
	box.add_child(separator)
	var dialogue_row := HBoxContainer.new()
	dialogue_row.add_theme_constant_override("separation", 18)
	dialogue_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(dialogue_row)
	portrait.custom_minimum_size = Vector2(128, 128)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	dialogue_row.add_child(portrait)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_row.add_child(copy)
	speaker_label.modulate = Color("72d8ff")
	speaker_label.add_theme_font_size_override("font_size", 19)
	copy.add_child(speaker_label)
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.add_child(line_label)
	box.add_child(choice_box)
	continue_button.text = "CONTINUE"
	continue_button.custom_minimum_size.y = 50
	continue_button.pressed.connect(_advance)
	box.add_child(continue_button)
	if hub != null: hub.localization.localize_tree(self)
	hide()

func bind(dialogue_adapter: DialogueManagerAdapter) -> void:
	adapter = dialogue_adapter
	adapter.dialogue_started.connect(func(_id, context):
		if context == &"briefing" or context == &"hub": show())
	adapter.line_presented.connect(_on_line_presented)
	adapter.choice_requested.connect(_on_choice_requested)
	adapter.dialogue_finished.connect(func(_id): hide())
	if DisplayServer.get_name() == "headless": adapter.dialogue_started.connect(func(_id, _context): call_deferred("_finish_headless"))

func _on_line_presented(line: Dictionary) -> void:
	var hub := get_node_or_null("/root/ProductionServices") as ServiceHub
	var speaker := String(line.get("speaker", "Command"))
	var body := String(line.get("text", ""))
	var portrait_name := String(line.get("portrait_id", speaker)).replace("portrait.", "").replace("_", " ")
	portrait.texture = CommsPortraitLibrary.texture_for_speaker(portrait_name)
	speaker_label.text = hub.localization.render(speaker.to_upper()) if hub != null else speaker.to_upper()
	line_label.text = hub.localization.render(body) if hub != null else body
	continue_button.disabled = not line.get("choices", []).is_empty()
	continue_button.call_deferred("grab_focus")

func _on_choice_requested(choices: Array) -> void:
	for child in choice_box.get_children(): child.queue_free()
	for index in choices.size():
		var button := Button.new()
		button.text = String(choices[index].get("text", "Choose"))
		button.pressed.connect(func(): adapter.choose(index))
		choice_box.add_child(button)

func _advance() -> void:
	if adapter != null: adapter.advance()

func _finish_headless() -> void:
	if adapter != null: adapter.finish()
