class_name BaseGameService
extends Node

signal service_error(service_id: StringName, message: String)

var service_id: StringName
var is_initialized := false

func initialize(_context: Dictionary = {}) -> bool:
	is_initialized = true
	return true

func report_error(message: String) -> void:
	push_error("[%s] %s" % [service_id, message])
	service_error.emit(service_id, message)
