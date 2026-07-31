class_name StatusComponent
extends Node

signal status_applied(status_id: StringName, stacks: int)
signal status_removed(status_id: StringName)

const VALID_STATUSES := [&"burn", &"freeze", &"slow", &"shock", &"emp", &"corrosion", &"marked", &"vulnerable", &"fortified", &"haste", &"regeneration", &"invulnerable"]

var status_resistances: Dictionary = {}
var _active: Dictionary = {}

func apply(application: StatusApplication) -> bool:
	if application == null or application.status_id not in VALID_STATUSES:
		return false
	var resistance := clampf(float(status_resistances.get(application.status_id, 0.0)), 0.0, 1.0)
	if resistance >= 1.0:
		return false
	var adjusted_duration := application.duration * (1.0 - resistance)
	if adjusted_duration <= 0.0:
		return false
	var existing: Dictionary = _active.get(application.status_id, {})
	if not existing.is_empty() and application.refresh_rule == StatusApplication.RefreshRule.IGNORE:
		return false
	var duration := adjusted_duration
	var stacks := mini(application.max_stacks, application.stacks)
	if not existing.is_empty():
		match application.refresh_rule:
			StatusApplication.RefreshRule.REFRESH_DURATION: duration = maxf(float(existing.duration), adjusted_duration)
			StatusApplication.RefreshRule.ADD_DURATION: duration = float(existing.duration) + adjusted_duration
			StatusApplication.RefreshRule.REPLACE: pass
		stacks = mini(application.max_stacks, int(existing.stacks) + application.stacks)
	_active[application.status_id] = {
		"source": application.source_actor_id, "duration": duration, "stacks": stacks,
		"strength": application.strength, "persists_at_checkpoint": application.persists_at_checkpoint
	}
	status_applied.emit(application.status_id, stacks)
	return true

func tick(delta: float) -> void:
	var expired: Array[StringName] = []
	for status_id in _active:
		_active[status_id].duration = maxf(0.0, float(_active[status_id].duration) - delta)
		if _active[status_id].duration <= 0.0:
			expired.append(status_id)
	for status_id in expired:
		remove(status_id)

func remove(status_id: StringName) -> void:
	if _active.erase(status_id):
		status_removed.emit(status_id)

func clear(keep_checkpoint_statuses := false) -> void:
	for status_id in _active.keys():
		if not keep_checkpoint_statuses or not bool(_active[status_id].persists_at_checkpoint):
			remove(status_id)

func has(status_id: StringName) -> bool:
	return _active.has(status_id)

func stacks(status_id: StringName) -> int:
	return int(_active.get(status_id, {}).get("stacks", 0))

func strength(status_id: StringName) -> float:
	var data: Dictionary = _active.get(status_id, {})
	return float(data.get("strength", 0.0)) * float(data.get("stacks", 0))

func movement_multiplier() -> float:
	if has(&"freeze"):
		return 0.0
	return maxf(0.0, 1.0 - strength(&"slow")) * (1.0 + strength(&"haste"))

func damage_taken_multiplier() -> float:
	return maxf(0.0, (1.0 + strength(&"vulnerable")) * (1.0 - clampf(strength(&"fortified"), 0.0, 0.9)))

func armor_multiplier() -> float:
	return maxf(0.0, 1.0 - clampf(strength(&"corrosion"), 0.0, 1.0))

func shield_recharge_multiplier() -> float:
	return 0.0 if has(&"emp") else 1.0

func abilities_blocked() -> bool:
	return has(&"emp") or has(&"freeze")

func controls_unstable() -> bool:
	return has(&"shock")

func active_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_active.keys())
	return result

func checkpoint_snapshot() -> Dictionary:
	var result := {}
	for status_id in _active:
		if bool(_active[status_id].persists_at_checkpoint):
			result[status_id] = _active[status_id].duplicate(true)
	return result

func restore_checkpoint(snapshot: Dictionary) -> void:
	clear()
	for status_id in snapshot:
		if StringName(status_id) in VALID_STATUSES:
			_active[StringName(status_id)] = (snapshot[status_id] as Dictionary).duplicate(true)
