extends Node

signal stage_started(stage_id: StringName)
signal stage_completed(stage_id: StringName)

var current_stage: StringName = &""
var completed_stages: Array[StringName] = []

func begin_stage(stage_id: StringName) -> void:
	current_stage = stage_id
	stage_started.emit(stage_id)

func complete_stage(stage_id: StringName) -> void:
	if not completed_stages.has(stage_id):
		completed_stages.append(stage_id)
	stage_completed.emit(stage_id)

