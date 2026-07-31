class_name BossSummonController
extends RefCounted

signal summon_requested(enemy_id: StringName, summon_index: int)

var active_summons: Dictionary = {}
var elapsed := 0.0
var sequence := 0

func tick(delta: float, phase: BossPhaseDefinition, extra_summons: Array[StringName] = []) -> void:
	if phase == null or phase.summon_interval <= 0.0 or phase.maximum_active_summons <= active_summons.size(): return
	elapsed += maxf(0.0, delta)
	if elapsed < phase.summon_interval: return
	elapsed = 0.0
	var choices: Array[StringName] = phase.summon_enemy_ids.duplicate()
	choices.append_array(extra_summons)
	if choices.is_empty(): return
	var enemy_id := choices[sequence % choices.size()]
	sequence += 1
	active_summons[sequence] = enemy_id
	summon_requested.emit(enemy_id, sequence)

func summon_defeated(summon_index: int) -> void:
	active_summons.erase(summon_index)

func clear() -> void:
	active_summons.clear()
	elapsed = 0.0
