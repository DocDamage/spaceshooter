class_name GameFlowService
extends BaseGameService

signal state_changed(previous: StringName, current: StringName)

var current_state: StringName = &"booting"

func _init() -> void:
	service_id = &"game_flow"

func transition_to(next_state: StringName) -> void:
	if next_state.is_empty():
		report_error("Cannot transition to an empty state")
		return
	var previous := current_state
	current_state = next_state
	state_changed.emit(previous, current_state)
