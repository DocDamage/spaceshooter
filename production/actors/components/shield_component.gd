class_name ShieldComponent
extends Node

signal capacity_changed(current: float, maximum: float)
signal shield_broken
signal recharge_started
signal damage_reflected(amount: float, source_actor_id: StringName)
signal damage_absorbed(amount: float)

var capacity := 0.0
var current := 0.0
var recharge_delay := 2.0
var recharge_rate := 15.0
var overload_duration := 1.0
var reflection_ratio := 0.0
var absorption_ratio := 0.0
var damage_type_multipliers: Dictionary = {}
var _recharge_timer := 0.0
var _overload_timer := 0.0
var _was_recharging := false

func configure(maximum_capacity: float, delay := 2.0, rate := 15.0) -> void:
	capacity = maxf(0.0, maximum_capacity)
	current = capacity
	recharge_delay = maxf(0.0, delay)
	recharge_rate = maxf(0.0, rate)

func resolve_damage(amount: float, packet: DamagePacket, result: DamageResult) -> float:
	if amount <= 0.0 or current <= 0.0 or packet.shield_interaction == DamagePacket.ShieldInteraction.BYPASS:
		return amount
	var penetration := clampf(packet.shield_penetration, 0.0, 1.0) if packet.shield_interaction == DamagePacket.ShieldInteraction.PARTIAL_PENETRATION else 0.0
	var bypassed := amount * penetration
	var shield_bound := amount - bypassed
	var type_multiplier := maxf(0.0, float(damage_type_multipliers.get(packet.damage_type, 1.0)))
	var adjusted := shield_bound * type_multiplier
	var absorbed := adjusted * clampf(absorption_ratio, 0.0, 1.0)
	if packet.shield_interaction == DamagePacket.ShieldInteraction.ABSORB:
		absorbed = adjusted
	adjusted -= absorbed
	result.absorbed_damage += absorbed
	if absorbed > 0.0:
		damage_absorbed.emit(absorbed)
	var consumed := minf(current, adjusted)
	current -= consumed
	result.shield_damage += consumed
	var reflected := consumed * clampf(reflection_ratio, 0.0, 1.0)
	if packet.shield_interaction == DamagePacket.ShieldInteraction.REFLECT:
		reflected = consumed
	result.reflected_damage += reflected
	if reflected > 0.0:
		damage_reflected.emit(reflected, packet.source_actor_id)
	_recharge_timer = recharge_delay
	_was_recharging = false
	capacity_changed.emit(current, capacity)
	if current <= 0.0 and consumed > 0.0:
		_overload_timer = overload_duration
		shield_broken.emit()
	var unshielded_adjusted := maxf(0.0, adjusted - consumed)
	return bypassed + (unshielded_adjusted / type_multiplier if type_multiplier > 0.0 else shield_bound)

func interrupt_recharge(extra_delay := -1.0) -> void:
	_recharge_timer = recharge_delay if extra_delay < 0.0 else maxf(0.0, extra_delay)
	_was_recharging = false

func tick(delta: float, recharge_multiplier := 1.0) -> void:
	_overload_timer = maxf(0.0, _overload_timer - delta)
	_recharge_timer = maxf(0.0, _recharge_timer - delta)
	if current >= capacity or _recharge_timer > 0.0 or _overload_timer > 0.0:
		_was_recharging = false
		return
	if not _was_recharging:
		_was_recharging = true
		recharge_started.emit()
	current = minf(capacity, current + recharge_rate * maxf(0.0, recharge_multiplier) * delta)
	capacity_changed.emit(current, capacity)

func is_broken() -> bool:
	return capacity > 0.0 and current <= 0.0

func reset() -> void:
	current = capacity
	_recharge_timer = 0.0
	_overload_timer = 0.0
	capacity_changed.emit(current, capacity)
