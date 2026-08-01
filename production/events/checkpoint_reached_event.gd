class_name CheckpointReachedEvent
extends GameEvent

var checkpoint_id: StringName

func _init(event_source_id: StringName = &"", event_target_id: StringName = &"", reached_checkpoint_id: StringName = &"") -> void:
	super(event_source_id, event_target_id)
	checkpoint_id = reached_checkpoint_id

func get_event_type() -> StringName:
	return &"checkpoint_reached"
