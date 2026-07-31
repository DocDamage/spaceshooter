class_name BriefingPresenter
extends PanelContainer

var adapter: DialogueManagerAdapter
var speaker_label := Label.new()
var line_label := Label.new()
var continue_button := Button.new()
var choice_box := VBoxContainer.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -220; offset_right = 220; offset_top = -210; offset_bottom = 210
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 28); margin.add_theme_constant_override("margin_right", 28); margin.add_theme_constant_override("margin_top", 24); margin.add_theme_constant_override("margin_bottom", 24); add_child(margin)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 14); margin.add_child(box)
	var title := Label.new(); title.text = "MISSION BRIEFING"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 26); box.add_child(title)
	speaker_label.modulate = Color("72d8ff"); speaker_label.add_theme_font_size_override("font_size", 19); box.add_child(speaker_label)
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; line_label.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(line_label)
	box.add_child(choice_box)
	continue_button.text = "CONTINUE"; continue_button.custom_minimum_size.y = 52; continue_button.pressed.connect(_advance); box.add_child(continue_button)
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
	speaker_label.text = String(line.get("speaker", "COMMAND")).to_upper()
	line_label.text = String(line.get("text", ""))
	continue_button.disabled = not line.get("choices", []).is_empty()
	continue_button.call_deferred("grab_focus")

func _on_choice_requested(choices: Array) -> void:
	for child in choice_box.get_children(): child.queue_free()
	for index in choices.size():
		var button := Button.new(); button.text = String(choices[index].get("text", "Choose")); button.pressed.connect(func(): adapter.choose(index)); choice_box.add_child(button)

func _advance() -> void:
	if adapter != null: adapter.advance()

func _finish_headless() -> void:
	if adapter == null: return
	adapter.finish()
