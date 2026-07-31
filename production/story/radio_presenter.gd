class_name RadioPresenter
extends PanelContainer

var portrait := TextureRect.new()
var speaker_label := Label.new()
var message_label := Label.new()
var active_message_id: StringName
var queue: RadioQueue
var active_lines: Array = []
var line_index := 0
var line_timer := Timer.new()

func _ready() -> void:
	# A compact lower third stays clear of the aiming area and cannot exceed the 540px viewport.
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -250; offset_right = 250; offset_top = -330; offset_bottom = -190
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = GalaxHeroTheme.create()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)
	portrait.custom_minimum_size = Vector2(104, 104)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	row.add_child(portrait)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 5)
	row.add_child(copy)
	speaker_label.modulate = Color("72d8ff")
	speaker_label.add_theme_font_size_override("font_size", 18)
	copy.add_child(speaker_label)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.add_child(message_label)
	_apply_accessibility_style()
	line_timer.one_shot = true
	line_timer.timeout.connect(_advance_line)
	add_child(line_timer)
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
	var speaker := String(line.get("speaker", "Command"))
	var body := String(line.get("text", ""))
	var portrait_name := String(line.get("portrait_id", speaker)).replace("portrait.", "").replace("_", " ")
	portrait.texture = CommsPortraitLibrary.texture_for_speaker(portrait_name)
	var hub := get_node_or_null("/root/ProductionServices") as ServiceHub
	speaker_label.text = hub.localization.render(speaker.to_upper()) if hub != null else speaker.to_upper()
	message_label.text = hub.localization.render(body) if hub != null else body
	line_timer.start(queue.display_duration(body))

func _apply_accessibility_style() -> void:
	var hub := get_node_or_null("/root/ProductionServices") as ServiceHub
	var opacity := 0.88
	if hub != null:
		visible = bool(hub.settings.get_setting(&"subtitles_enabled", true))
		opacity = float(hub.settings.get_setting(&"subtitle_background_opacity", 0.82)) if bool(hub.settings.get_setting(&"subtitle_background", true)) else 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.025, 0.065, opacity)
	style.border_color = Color(0.22, 0.68, 0.88, 0.9)
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)

func _advance_line() -> void:
	line_index += 1
	_show_current_line()
