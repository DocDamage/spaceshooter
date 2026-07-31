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
	line_timer.one_shot = true; line_timer.timeout.connect(_advance_line); add_child(line_timer)
	hide()

func bind(radio_queue: RadioQueue) -> void:
	queue = radio_queue
	queue.message_started.connect(_on_message_started)
	queue.message_finished.connect(func(_message_id): hide())

func _on_message_started(message: Dictionary) -> void:
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
	message_label.text = "%s: %s" % [speaker, body] if not speaker.is_empty() else body
	line_timer.start(queue.display_duration(body))

func _advance_line() -> void:
	line_index += 1
	_show_current_line()
