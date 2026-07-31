class_name RadioPresenter
extends MarginContainer

var portrait := TextureRect.new()
var message_label := Label.new()
var active_message_id: StringName

func _ready() -> void:
	# Lower-third placement leaves the top, center reticle, and objective tracker unobstructed.
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -360; offset_right = 360; offset_top = -180; offset_bottom = -40
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new(); add_child(row); row.add_child(portrait); row.add_child(message_label)
	portrait.custom_minimum_size = Vector2(96, 96); portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; message_label.custom_minimum_size.x = 580
	hide()

func bind(queue: RadioQueue) -> void:
	queue.message_started.connect(_on_message_started)
	queue.message_finished.connect(func(_message_id): hide())

func _on_message_started(message: Dictionary) -> void:
	active_message_id = StringName(message.message_id)
	var lines: Array = message.get("lines", [])
	message_label.text = String(lines[0].get("text", "")) if not lines.is_empty() else ""
	show()
