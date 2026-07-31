class_name ArmorComponent
extends Node

signal subsystem_damaged(subsystem: StringName, condition: float)

const SUBSYSTEMS := [&"engine", &"weapons", &"shield_generator", &"controls", &"reactor", &"wingman_command"]

var armor := 0.0
var flat_reduction_cap_ratio := 0.8
var resistances: Dictionary = {}
var subsystem_conditions: Dictionary = {}
var system_damage_enabled := true
var subsystem_damage_enabled: Dictionary = {}

func _ready() -> void:
	reset_subsystems()

func configure(armor_value: float, damage_resistances: Dictionary = {}) -> void:
	armor = maxf(0.0, armor_value)
	resistances = damage_resistances.duplicate(true)
	reset_subsystems()

func reduce_damage(amount: float, penetration: float, armor_multiplier := 1.0) -> Dictionary:
	var effective_armor := armor * maxf(0.0, armor_multiplier) * (1.0 - clampf(penetration, 0.0, 1.0))
	var reduction := minf(effective_armor, amount * flat_reduction_cap_ratio)
	return {"damage": maxf(0.0, amount - reduction), "reduction": reduction}

func resistance_multiplier(damage_type: int) -> float:
	return clampf(1.0 - float(resistances.get(damage_type, 0.0)), 0.0, 4.0)

func damage_subsystem(subsystem: StringName, amount: float) -> bool:
	if not system_damage_enabled or subsystem not in SUBSYSTEMS or not bool(subsystem_damage_enabled.get(subsystem, true)):
		return false
	subsystem_conditions[subsystem] = clampf(float(subsystem_conditions.get(subsystem, 1.0)) - maxf(0.0, amount), 0.0, 1.0)
	subsystem_damaged.emit(subsystem, subsystem_conditions[subsystem])
	return true

func get_condition(subsystem: StringName) -> float:
	return float(subsystem_conditions.get(subsystem, 1.0))

func reset_subsystems() -> void:
	for subsystem in SUBSYSTEMS:
		subsystem_conditions[subsystem] = 1.0
		if not subsystem_damage_enabled.has(subsystem):
			subsystem_damage_enabled[subsystem] = true

func set_subsystem_enabled(subsystem: StringName, enabled: bool) -> void:
	if subsystem in SUBSYSTEMS:
		subsystem_damage_enabled[subsystem] = enabled
