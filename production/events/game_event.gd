class_name GameEvent
extends RefCounted

var source_id: StringName
var target_id: StringName
var occurred_at_msec: int

func _init(event_source_id: StringName = &"", event_target_id: StringName = &"") -> void:
	source_id = event_source_id
	target_id = event_target_id
	occurred_at_msec = Time.get_ticks_msec()

func get_event_type() -> StringName:
	return &"game_event"
