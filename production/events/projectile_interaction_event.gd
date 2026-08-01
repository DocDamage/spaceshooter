class_name ProjectileInteractionEvent
extends GameEvent

var interaction: StringName

func _init(event_source_id: StringName = &"", event_target_id: StringName = &"", interaction_type: StringName = &"hit") -> void:
	super(event_source_id, event_target_id)
	interaction = interaction_type

func get_event_type() -> StringName:
	return &"projectile_interaction"
