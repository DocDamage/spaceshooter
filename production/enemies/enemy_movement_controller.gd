class_name EnemyMovementController
extends Node

var actor: Node2D
var definition: MovementPatternDefinition
var target: Node2D
var formation_target := Vector2.ZERO
var arena := Rect2(0, 0, 540, 960)
var elapsed := 0.0
var origin := Vector2.ZERO
var phase := 0.0

func configure(owner_actor: Node2D, pattern: MovementPatternDefinition, injected_target: Node2D = null) -> void:
	actor = owner_actor
	definition = pattern
	target = injected_target
	elapsed = 0.0
	origin = actor.position if actor != null else Vector2.ZERO
	phase = float(abs(hash(actor.name if actor != null else "enemy")) % 628) / 100.0

func tick(delta: float, speed_multiplier := 1.0) -> void:
	if actor == null or definition == null or elapsed < definition.delay:
		elapsed += delta
		return
	elapsed += delta
	if definition.path != null:
		var progress := (elapsed - definition.delay) / definition.path.duration
		var destination := definition.path.position_at(progress)
		actor.position = origin + destination if definition.path.relative_to_spawn else destination
		_clamp_to_arena()
		return
	var speed := definition.speed * speed_multiplier
	var velocity := Vector2.DOWN * speed
	var wave := sin(elapsed * TAU * definition.frequency + phase)
	match definition.pattern:
		MovementPatternDefinition.Pattern.SINE:
			velocity = Vector2(wave * definition.amplitude * definition.frequency, speed)
		MovementPatternDefinition.Pattern.ZIGZAG:
			velocity = Vector2(signf(wave) * definition.amplitude, speed)
		MovementPatternDefinition.Pattern.FORMATION_FOLLOW, MovementPatternDefinition.Pattern.GUARD, MovementPatternDefinition.Pattern.BOSS_ANCHOR:
			velocity = actor.position.direction_to(formation_target) * minf(speed, actor.position.distance_to(formation_target) * 4.0)
		MovementPatternDefinition.Pattern.DIVE:
			velocity = _toward_target(Vector2.DOWN, speed * 1.35)
		MovementPatternDefinition.Pattern.CHASE:
			velocity = _toward_target(Vector2.DOWN, speed)
		MovementPatternDefinition.Pattern.FLANK:
			velocity = _toward_target(Vector2(1 if actor.position.x < arena.get_center().x else -1, 0.4), speed)
		MovementPatternDefinition.Pattern.ORBIT:
			var center := target.position if is_instance_valid(target) else formation_target
			var radial := center.direction_to(actor.position)
			velocity = (radial.rotated(PI * 0.5) + radial * (actor.position.distance_to(center) - definition.amplitude) * -0.02).normalized() * speed
		MovementPatternDefinition.Pattern.STOP_AND_FIRE:
			velocity = Vector2.DOWN * speed if elapsed < definition.duration * 0.35 else Vector2.ZERO
		MovementPatternDefinition.Pattern.CROSS_SCREEN:
			velocity = Vector2(speed if origin.x < arena.get_center().x else -speed, speed * 0.2)
		MovementPatternDefinition.Pattern.RETREAT:
			velocity = Vector2.UP * speed
		MovementPatternDefinition.Pattern.AMBUSH:
			velocity = Vector2.ZERO if elapsed < definition.duration * 0.5 else _toward_target(Vector2.DOWN, speed * 1.4)
		MovementPatternDefinition.Pattern.TELEPORT:
			if fmod(elapsed, maxf(0.25, definition.duration)) < delta:
				actor.position = Vector2(arena.position.x + definition.arena_margin + fmod(float(abs(hash("%s:%f" % [actor.name, elapsed]))), arena.size.x - definition.arena_margin * 2.0), actor.position.y)
			velocity = Vector2.ZERO
		MovementPatternDefinition.Pattern.CARRIER_PATH:
			velocity = Vector2(wave * speed * 0.35, speed * 0.45)
	actor.position += velocity * delta
	_clamp_to_arena()

func _toward_target(fallback: Vector2, speed: float) -> Vector2:
	return actor.position.direction_to(target.position) * speed if is_instance_valid(target) else fallback.normalized() * speed

func _clamp_to_arena() -> void:
	var margin := definition.arena_margin
	actor.position.x = clampf(actor.position.x, arena.position.x + margin, arena.end.x - margin)
	actor.position.y = clampf(actor.position.y, arena.position.y - margin * 4.0, arena.end.y + margin * 4.0)
