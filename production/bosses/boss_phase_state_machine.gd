class_name BossPhaseStateMachine
extends RefCounted

signal phase_changed(previous_index: int, current_index: int, phase: BossPhaseDefinition)
signal enraged(phase_id: StringName)

var phases: Array[BossPhaseDefinition] = []
var current_index := -1
var elapsed := 0.0
var is_enraged := false

func configure(phase_definitions: Array[BossPhaseDefinition], starting_index := 0) -> bool:
	phases = phase_definitions.duplicate()
	if phases.is_empty(): return false
	current_index = clampi(starting_index, 0, phases.size() - 1)
	elapsed = 0.0
	is_enraged = false
	return true

func current_phase() -> BossPhaseDefinition:
	return phases[current_index] if current_index >= 0 and current_index < phases.size() else null

func tick(delta: float, health_ratio: float, destroyed_parts: int, external_transition := false) -> bool:
	var phase := current_phase()
	if phase == null: return false
	elapsed += maxf(0.0, delta)
	if not is_enraged and phase.enrage_after > 0.0 and elapsed >= phase.enrage_after:
		is_enraged = true
		enraged.emit(phase.stable_id)
	if current_index >= phases.size() - 1: return false
	var next := phases[current_index + 1]
	var should_advance := false
	match phase.transition_condition:
		&"health": should_advance = health_ratio <= next.health_threshold
		&"duration": should_advance = phase.maximum_duration > 0.0 and elapsed >= phase.maximum_duration
		&"parts_destroyed": should_advance = destroyed_parts > 0 and (phase.active_part_ids.is_empty() or destroyed_parts >= phase.active_part_ids.size())
		&"external": should_advance = external_transition
	return advance() if should_advance else false

func advance() -> bool:
	if current_index < 0 or current_index >= phases.size() - 1: return false
	var previous := current_index
	current_index += 1
	elapsed = 0.0
	is_enraged = false
	phase_changed.emit(previous, current_index, current_phase())
	return true

func snapshot() -> Dictionary:
	return {"index": current_index, "elapsed": elapsed, "enraged": is_enraged}

func restore(data: Dictionary) -> void:
	current_index = clampi(int(data.get("index", current_index)), 0, maxi(0, phases.size() - 1))
	elapsed = maxf(0.0, float(data.get("elapsed", 0.0)))
	is_enraged = bool(data.get("enraged", false))
