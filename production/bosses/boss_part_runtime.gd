class_name BossPartRuntime
extends RefCounted

signal health_changed(part_id: StringName, current: float, maximum: float)
signal destroyed(part_id: StringName)

var definition: BossPartDefinition
var current_health := 0.0
var active := true
var targetable := true

func configure(part_definition: BossPartDefinition) -> void:
	definition = part_definition
	current_health = definition.maximum_health if definition != null else 0.0
	active = definition != null
	targetable = active

func receive_damage(amount: float, armor_penetration := 0.0) -> float:
	if not active or not targetable or definition == null: return 0.0
	var reduction := definition.armor * (1.0 - clampf(armor_penetration, 0.0, 1.0))
	var applied := minf(current_health, maxf(0.0, amount - reduction))
	current_health -= applied
	health_changed.emit(definition.stable_id, current_health, definition.maximum_health)
	if current_health <= 0.0:
		active = false
		destroyed.emit(definition.stable_id)
	return applied

func snapshot() -> Dictionary:
	return {"part_id": definition.stable_id if definition != null else &"", "health": current_health, "active": active, "targetable": targetable}

func restore(data: Dictionary) -> void:
	current_health = clampf(float(data.get("health", current_health)), 0.0, definition.maximum_health if definition != null else 0.0)
	active = bool(data.get("active", current_health > 0.0)) and current_health > 0.0
	targetable = bool(data.get("targetable", active)) and active

func set_phase(phase_id: StringName) -> void:
	if definition == null or not active: return
	targetable = definition.active_phase_ids.is_empty() or phase_id in definition.active_phase_ids
