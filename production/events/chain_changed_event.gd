class_name ChainChangedEvent
extends GameEvent

var chain_count: int

func _init(event_source_id: StringName = &"", event_target_id: StringName = &"", count := 0) -> void:
	super(event_source_id, event_target_id)
	chain_count = count

func get_event_type() -> StringName:
	return &"chain_changed"
