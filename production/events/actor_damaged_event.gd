class_name ActorDamagedEvent
extends GameEvent

var amount: float
var shield_amount: float
var damage_type: int
var network_sequence_id: int

func _init(event_source_id: StringName = &"", event_target_id: StringName = &"", damage_amount := 0.0, shield_damage := 0.0, type := 0, sequence_id := 0) -> void:
	super(event_source_id, event_target_id)
	amount = damage_amount
	shield_amount = shield_damage
	damage_type = type
	network_sequence_id = sequence_id

func get_event_type() -> StringName:
	return &"actor_damaged"
