class_name RadioPresenter
extends MarginContainer

var portrait := TextureRect.new()
var message_label := Label.new()
var active_message_id: StringName
var queue: RadioQueue
var active_lines: Array = []
var line_index := 0
var line_timer := Timer.new()

func _ready() -> void:
	# Lower-third placement leaves the top, center reticle, and objective tracker unobstructed.
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -360; offset_right = 360; offset_top = -180; offset_bottom = -40
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new(); add_child(row); row.add_child(portrait); row.add_child(message_label)
	portrait.custom_minimum_size = Vector2(96, 96); portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; message_label.custom_minimum_size.x = 580
	_apply_accessibility_style()
	line_timer.one_shot = true; line_timer.timeout.connect(_advance_line); add_child(line_timer)
	hide()

func bind(radio_queue: RadioQueue) -> void:
	queue = radio_queue
	queue.message_started.connect(_on_message_started)
	queue.message_finished.connect(func(_message_id): hide())

func _on_message_started(message: Dictionary) -> void:
	var hub := get_node_or_null("/root/ProductionServices") as ServiceHub
	if hub != null and not bool(hub.settings.get_setting(&"subtitles_enabled", true)):
		queue.complete_current()
		return
	active_message_id = StringName(message.message_id)
	active_lines = message.get("lines", []).duplicate(true)
	line_index = 0
	_show_current_line()
	show()

func _show_current_line() -> void:
	if queue == null or line_index >= active_lines.size():
		if queue != null: queue.complete_current()
		return
	var line: Dictionary = active_lines[line_index]
	var speaker := String(line.get("speaker", ""))
	var body := String(line.get("text", ""))
	var hub := get_node_or_null("/root/ProductionServices") as ServiceHub
	var rendered := "%s: %s" % [speaker, body] if not speaker.is_empty() else body
	message_label.text = hub.localization.render(rendered) if hub != null else rendered
	line_timer.start(queue.display_duration(body))

func _apply_accessibility_style() -> void:
	var hub := get_node_or_null("/root/ProductionServices") as ServiceHub
	if hub == null: return
	visible = bool(hub.settings.get_setting(&"subtitles_enabled", true))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.02, 0.05, float(hub.settings.get_setting(&"subtitle_background_opacity", 0.82)) if bool(hub.settings.get_setting(&"subtitle_background", true)) else 0.0)
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8; style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", style)

func _advance_line() -> void:
	line_index += 1
	_show_current_line()
