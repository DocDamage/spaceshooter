class_name CampaignMapView
extends Control

signal node_confirmed(node_id: StringName)

var model: CampaignMapModel
var title_label: Label
var detail_label: Label

func _ready() -> void:
	set_process_unhandled_input(true)
	if title_label == null:
		title_label = Label.new(); title_label.name = "OperationTitle"; add_child(title_label)
		detail_label = Label.new(); detail_label.name = "NodeDetails"; detail_label.position = Vector2(0, 32); add_child(detail_label)
	_refresh_display()

func configure(source: CampaignMapModel) -> void:
	model = source
	if model != null: model.selection_changed.connect(func(_node_id): _refresh_display())
	_refresh_display()

func _unhandled_input(event: InputEvent) -> void:
	if model == null: return
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_up"):
		model.navigate(-1); get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_down"):
		model.navigate(1); get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_confirm"):
		var selected := model.selected_node()
		if selected.get("state") in [&"available", &"completed"]: node_confirmed.emit(StringName(selected.node_id))
		get_viewport().set_input_as_handled()

func _refresh_display() -> void:
	if title_label == null or model == null: return
	var selected := model.selected_node()
	if selected.is_empty(): title_label.text = "No mission available"; detail_label.text = ""; return
	title_label.text = "Operation %d · Stage %d" % [selected.operation, selected.stage]
	detail_label.text = "%s\n%s\nRank: %s\nReward: %s" % [selected.current_objective, String(selected.state).capitalize(), String(selected.rank), str(selected.reward_preview)]
