class_name PlayerMovementController
extends Node

var actor: BaseActor2D
var profile: MovementProfile
var state_machine: MovementStateMachine
var velocity := Vector2.ZERO
var last_direction := Vector2.UP

func configure(controlled_actor: BaseActor2D, movement_profile: MovementProfile) -> void:
	actor = controlled_actor
	profile = movement_profile
	state_machine = MovementStateMachine.new()
	state_machine.name = "MovementStateMachine"
	add_child(state_machine)

func simulate(input_vector: Vector2, delta: float) -> void:
	if actor == null or profile == null or not state_machine.allows_movement():
		velocity = Vector2.ZERO
		return
	state_machine.tick(delta)
	var direction := input_vector.limit_length()
	if direction != Vector2.ZERO:
		last_direction = direction.normalized()
	var target := direction * state_machine.speed_for(profile) * actor.status_component.movement_multiplier()
	if profile.regulation_direct:
		velocity = target
		actor.position += velocity * delta
		_apply_boundary()
		return
	var rate := profile.acceleration if direction != Vector2.ZERO else profile.deceleration
	velocity = velocity.move_toward(target, rate * delta)
	actor.position += velocity * delta
	_apply_boundary()

func dash(direction: Vector2) -> bool:
	var dash_direction := direction.normalized() if direction != Vector2.ZERO else last_direction
	if not state_machine.request(MovementStateMachine.DASH, profile.dash_time, profile.dash_cooldown):
		return false
	actor.position += dash_direction * profile.dash_distance
	actor.grant_invulnerability(profile.dash_invulnerability)
	_apply_boundary()
	return true

func roll() -> bool:
	if not state_machine.request(MovementStateMachine.ROLL, profile.roll_time, profile.roll_cooldown):
		return false
	actor.grant_invulnerability(profile.roll_invulnerability)
	return true

func teleport(direction: Vector2) -> bool:
	var teleport_direction := direction.normalized() if direction != Vector2.ZERO else last_direction
	if not state_machine.request(MovementStateMachine.TELEPORT, 0.01, profile.teleport_cooldown):
		return false
	actor.position += teleport_direction * profile.teleport_distance
	actor.grant_invulnerability(profile.teleport_invulnerability)
	_apply_boundary()
	return true

func set_focus(enabled: bool) -> bool:
	return state_machine.request(MovementStateMachine.FOCUS if enabled else MovementStateMachine.NORMAL)

func set_boost(enabled: bool) -> bool:
	return state_machine.request(MovementStateMachine.BOOST if enabled else MovementStateMachine.NORMAL)

func _apply_boundary() -> void:
	if profile.wrap_boundaries:
		actor.position.x = wrapf(actor.position.x, profile.boundary.position.x, profile.boundary.end.x)
		actor.position.y = wrapf(actor.position.y, profile.boundary.position.y, profile.boundary.end.y)
	else:
		actor.position.x = clampf(actor.position.x, profile.boundary.position.x, profile.boundary.end.x)
		actor.position.y = clampf(actor.position.y, profile.boundary.position.y, profile.boundary.end.y)
