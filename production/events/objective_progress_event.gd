class_name ObjectiveProgressEvent
extends GameEvent

var current: int
var required: int

func _init(event_source_id: StringName = &"", event_target_id: StringName = &"", current_value := 0, required_value := 0) -> void:
	super(event_source_id, event_target_id)
	current = current_value
	required = required_value

func get_event_type() -> StringName:
	return &"objective_progress"
