class_name SuperModeRuntime
extends Node

signal charge_changed(current: float, required: float)
signal activated(super_id: StringName)
signal cancelled(super_id: StringName)
signal ended(super_id: StringName)
signal recovery_started(super_id: StringName, seconds: float)

var owner_actor: BaseActor2D
var weapon_runtime: WeaponRuntime
var definition: SuperModeDefinition
var charge := 0.0
var remaining := 0.0
var active := false
var recovery_remaining := 0.0
var rank_pips := 0
var _previous_weapon_index := -1
var _conversion_service: BulletConversionService

func configure(actor: BaseActor2D, weapons: WeaponRuntime, super_definition: SuperModeDefinition, conversion_service: BulletConversionService = null) -> void:
	owner_actor = actor
	weapon_runtime = weapons
	definition = super_definition
	_conversion_service = conversion_service

func add_charge(amount: float) -> void:
	if definition == null or active or recovery_remaining > 0.0:
		return
	charge = clampf(charge + maxf(0.0, amount), 0.0, definition.charge_required)
	charge_changed.emit(charge, definition.charge_required)

func activate() -> bool:
	if definition == null or owner_actor == null or active or recovery_remaining > 0.0 or charge < definition.charge_required:
		return false
	charge = 0.0
	remaining = definition.duration_seconds
	active = true
	if definition.invulnerable or definition.activation_invulnerability_seconds > 0.0:
		owner_actor.grant_invulnerability(maxf(definition.activation_invulnerability_seconds, definition.duration_seconds if definition.invulnerable else 0.0))
	if _conversion_service != null:
		_conversion_service.convert_active(owner_actor.actor_id)
	rank_pips = clampi(rank_pips + definition.rank_gain, 0, 3)
	if definition.replacement_weapon != null and weapon_runtime != null:
		_previous_weapon_index = weapon_runtime.current_index
		var replacement_index := weapon_runtime.inventory.find(definition.replacement_weapon)
		if replacement_index < 0:
			replacement_index = weapon_runtime.add_weapon(definition.replacement_weapon)
		weapon_runtime.switch_to(replacement_index)
	activated.emit(definition.stable_id)
	return true

func tick(delta: float) -> void:
	if recovery_remaining > 0.0: recovery_remaining = maxf(0.0, recovery_remaining - delta)
	if not active: return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		_finish(false)

func cancel() -> bool:
	if not active:
		return false
	charge = definition.charge_required * clampf(definition.cancel_refund_ratio, 0.0, 1.0)
	_finish(true)
	return true

func on_stage_transition() -> void:
	if active:
		_finish(false)

func damage_multiplier() -> float:
	return definition.damage_multiplier if active and definition != null else 1.0

func _finish(was_cancelled: bool) -> void:
	active = false
	remaining = 0.0
	if definition != null and not was_cancelled:
		recovery_remaining = definition.recovery_seconds
		recovery_started.emit(definition.stable_id, recovery_remaining)
	if weapon_runtime != null and _previous_weapon_index >= 0 and _previous_weapon_index < weapon_runtime.inventory.size():
		weapon_runtime.switch_to(_previous_weapon_index)
	if was_cancelled:
		cancelled.emit(definition.stable_id)
	else:
		ended.emit(definition.stable_id)

func snapshot() -> Dictionary:
	return {&"charge": charge, &"remaining": remaining, &"active": active, &"recovery": recovery_remaining, &"rank_pips": rank_pips}
