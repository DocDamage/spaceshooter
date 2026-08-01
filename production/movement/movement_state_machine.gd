class_name MovementStateMachine
extends Node

signal state_changed(previous: StringName, current: StringName)

const NORMAL := &"normal"
const FOCUS := &"focus"
const BOOST := &"boost"
const DASH := &"dash"
const ROLL := &"roll"
const TELEPORT := &"teleport"
const PAUSED := &"paused"
const DIALOGUE := &"dialogue"
const DESTROYED := &"destroyed"

var current_state: StringName = NORMAL
var state_time_remaining := 0.0
var cooldowns: Dictionary = {DASH: 0.0, ROLL: 0.0, TELEPORT: 0.0}
var dialogue_pauses_movement := true
var can_fire_while_rolling := false

func request(state: StringName, duration := 0.0, cooldown := 0.0) -> bool:
	if current_state == DESTROYED:
		return false
	if state == DESTROYED:
		_transition(DESTROYED, 0.0)
		return true
	if state == PAUSED or state == DIALOGUE:
		_transition(state, 0.0)
		return true
	if current_state == PAUSED or (current_state == DIALOGUE and dialogue_pauses_movement):
		return false
	if current_state in [DASH, ROLL, TELEPORT] and state in [NORMAL, FOCUS, BOOST]:
		return false
	if current_state == BOOST and state == FOCUS:
		return false
	if state in [DASH, ROLL, TELEPORT] and float(cooldowns.get(state, 0.0)) > 0.0:
		return false
	if state == TELEPORT and current_state == DASH:
		_transition(NORMAL, 0.0)
	if state in [DASH, ROLL, TELEPORT]:
		cooldowns[state] = maxf(0.0, cooldown)
	_transition(state, maxf(0.0, duration))
	return true

func tick(delta: float) -> void:
	for state in cooldowns:
		cooldowns[state] = maxf(0.0, float(cooldowns[state]) - delta)
	if current_state in [DASH, ROLL, TELEPORT]:
		state_time_remaining = maxf(0.0, state_time_remaining - delta)
		if state_time_remaining <= 0.0:
			_transition(NORMAL, 0.0)

func resume() -> void:
	if current_state in [PAUSED, DIALOGUE]:
		_transition(NORMAL, 0.0)

func allows_movement() -> bool:
	return current_state not in [PAUSED, DESTROYED] and not (current_state == DIALOGUE and dialogue_pauses_movement)

func allows_firing() -> bool:
	return current_state not in [PAUSED, DIALOGUE, DESTROYED] and (current_state != ROLL or can_fire_while_rolling)

func speed_for(profile: MovementProfile) -> float:
	match current_state:
		FOCUS: return profile.focus_speed
		BOOST: return profile.boost_speed
		_: return profile.maximum_speed

func _transition(next: StringName, duration: float) -> void:
	var previous := current_state
	current_state = next
	state_time_remaining = duration
	if previous != next:
		state_changed.emit(previous, next)
