class_name RewardGrantedEvent
extends GameEvent

var reward_id: StringName
var amount: int

func _init(event_source_id: StringName = &"", event_target_id: StringName = &"", granted_reward_id: StringName = &"", granted_amount := 0) -> void:
	super(event_source_id, event_target_id)
	reward_id = granted_reward_id
	amount = granted_amount

func get_event_type() -> StringName:
	return &"reward_granted"
