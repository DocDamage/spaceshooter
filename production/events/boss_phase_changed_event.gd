class_name BossPhaseChangedEvent
extends GameEvent

var phase: int

func _init(event_source_id: StringName = &"", event_target_id: StringName = &"", next_phase := 0) -> void:
	super(event_source_id, event_target_id)
	phase = next_phase

func get_event_type() -> StringName:
	return &"boss_phase_changed"
