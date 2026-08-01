class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal depleted

var maximum := 100.0
var current := 100.0

func configure(maximum_health: float) -> void:
	maximum = maxf(1.0, maximum_health)
	current = maximum

func apply_damage(amount: float) -> float:
	var applied := minf(current, maxf(0.0, amount))
	current -= applied
	health_changed.emit(current, maximum)
	if current <= 0.0:
		depleted.emit()
	return applied

func heal(amount: float) -> float:
	var previous := current
	current = minf(maximum, current + maxf(0.0, amount))
	health_changed.emit(current, maximum)
	return current - previous

func reset() -> void:
	current = maximum
	health_changed.emit(current, maximum)

func is_depleted() -> bool:
	return current <= 0.0
