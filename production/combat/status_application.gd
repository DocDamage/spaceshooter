class_name StatusApplication
extends RefCounted

enum RefreshRule { REFRESH_DURATION, ADD_DURATION, REPLACE, IGNORE }

var status_id: StringName
var source_actor_id: StringName
var duration: float
var stacks: int
var max_stacks: int
var refresh_rule: RefreshRule
var strength: float
var persists_at_checkpoint: bool

func _init(id: StringName = &"", source_id: StringName = &"", seconds := 0.0, stack_count := 1) -> void:
	status_id = id
	source_actor_id = source_id
	duration = maxf(0.0, seconds)
	stacks = maxi(1, stack_count)
	max_stacks = 1
	refresh_rule = RefreshRule.REFRESH_DURATION
	strength = 1.0
	persists_at_checkpoint = false
