extends Node

## Phase 1 compatibility wrapper for the donor AudioCenter API.
var muted := false

func play(_stream_name: StringName, _position := Vector2.ZERO) -> void:
	# Donor audio source files are unavailable; calls remain safe and silent.
	pass

func stop_all() -> void:
	pass

