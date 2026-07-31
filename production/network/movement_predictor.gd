class_name MovementPredictor
extends RefCounted

const TELEPORT_THRESHOLD := 96.0
const RECONCILE_THRESHOLD := 2.0

var movement_speed := 320.0
var arena_bounds := Rect2(0, 0, 540, 960)
var pending_inputs: Array[Dictionary] = []
var predicted_state := {"position": Vector2.ZERO, "velocity": Vector2.ZERO, "dash_active": false, "paused": false}
var last_acknowledged_sequence := 0

func configure(initial_position: Vector2, speed: float, bounds: Rect2) -> void:
	movement_speed = maxf(1.0, speed)
	arena_bounds = bounds
	predicted_state.position = _clamp_position(initial_position)
	predicted_state.velocity = Vector2.ZERO
	pending_inputs.clear()
	last_acknowledged_sequence = 0

func predict(input_message: Dictionary) -> Dictionary:
	var input := input_message.duplicate(true)
	input["sequence"] = maxi(last_acknowledged_sequence + pending_inputs.size() + 1, int(input.get("sequence", 1)))
	pending_inputs.append(input)
	predicted_state = _simulate(predicted_state, input)
	return predicted_state.duplicate(true)

func reconcile(authoritative_state: Dictionary, acknowledged_sequence: int) -> Dictionary:
	last_acknowledged_sequence = maxi(last_acknowledged_sequence, acknowledged_sequence)
	while not pending_inputs.is_empty() and int(pending_inputs[0].get("sequence", 0)) <= last_acknowledged_sequence:
		pending_inputs.pop_front()
	var previous: Vector2 = predicted_state.position
	predicted_state = authoritative_state.duplicate(true)
	predicted_state.position = _clamp_position(predicted_state.get("position", Vector2.ZERO))
	for input in pending_inputs: predicted_state = _simulate(predicted_state, input)
	var distance := previous.distance_to(predicted_state.position)
	return {"state": predicted_state.duplicate(true), "corrected": distance > RECONCILE_THRESHOLD, "teleported": distance > TELEPORT_THRESHOLD, "distance": distance}

func interpolate(from_state: Dictionary, to_state: Dictionary, weight: float) -> Dictionary:
	var result := to_state.duplicate(true)
	result.position = (from_state.get("position", Vector2.ZERO) as Vector2).lerp(to_state.get("position", Vector2.ZERO), clampf(weight, 0.0, 1.0))
	result.velocity = (from_state.get("velocity", Vector2.ZERO) as Vector2).lerp(to_state.get("velocity", Vector2.ZERO), clampf(weight, 0.0, 1.0))
	return result

func _simulate(state: Dictionary, input: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	if bool(input.get("paused", false)):
		result.paused = true; result.velocity = Vector2.ZERO
		return result
	result.paused = false
	var direction: Vector2 = input.get("direction", Vector2.ZERO)
	if direction.length_squared() > 1.0: direction = direction.normalized()
	var dash := bool(input.get("dash", false))
	var delta := clampf(float(input.get("delta", 0.0)), 0.0, 0.1)
	result.velocity = direction * movement_speed * (2.2 if dash else 1.0)
	result.position = _clamp_position(result.get("position", Vector2.ZERO) + result.velocity * delta)
	result.dash_active = dash
	return result

func _clamp_position(value: Vector2) -> Vector2:
	return Vector2(clampf(value.x, arena_bounds.position.x, arena_bounds.end.x), clampf(value.y, arena_bounds.position.y, arena_bounds.end.y))
