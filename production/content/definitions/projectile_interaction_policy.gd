class_name ProjectileInteractionPolicy
extends Resource

enum Interaction { DESTROY, REFLECT, ABSORB, CONVERT_ENERGY, CONVERT_SCORE, FREEZE, SLOW, REDIRECT, PHASE_THROUGH, SPLIT, DETONATE }

@export var interaction: Interaction = Interaction.DESTROY
@export var required_tags: Array[StringName] = []
@export var excluded_tags: Array[StringName] = []
@export var magnitude := 1.0
@export var replacement_team: StringName
@export var split_count := 2

func accepts(tags: Array[StringName]) -> bool:
	for tag in required_tags:
		if tag not in tags:
			return false
	for tag in excluded_tags:
		if tag in tags:
			return false
	return true
