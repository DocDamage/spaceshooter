class_name EnemyAttackController
extends Node

signal pattern_fired(pattern_id: StringName, projectile_count: int)
signal telegraph_started(phrase_id: StringName, seconds: float)

var actor: BaseActor2D
var deck: AttackDeckDefinition
var target: Node2D
var pool: ProjectilePoolManager
var registry: ActorRegistry
var event_bus: TypedEventBus
var difficulty: DifficultyProfileDefinition
var player_count := 1
var elite := false
var formation_ready := true
var cooldown := 0.0
var sequence := 0
var deck_index := 0
var burst_remaining := 0
var burst_timer := 0.0
var burst_pattern: AttackPatternDefinition
var disabled_pattern_ids: Array[StringName] = []
var cadence_multiplier := 1.0
var telegraph_remaining := 0.0
var pending_pattern: AttackPatternDefinition
var pending_phrase: AttackPhraseDefinition
var phrase_index := 0
var sampled_rank_pips := 0

func configure(owner_actor: BaseActor2D, attack_deck: AttackDeckDefinition, injected_target: Node2D, projectile_pool: ProjectilePoolManager, actor_registry: ActorRegistry, events: TypedEventBus) -> void:
	actor = owner_actor
	deck = attack_deck
	target = injected_target
	pool = projectile_pool
	registry = actor_registry
	event_bus = events

func tick(delta: float) -> void:
	if actor == null or deck == null or pool == null or not actor.active:
		return
	cooldown = maxf(0.0, cooldown - delta)
	burst_timer = maxf(0.0, burst_timer - delta)
	if telegraph_remaining > 0.0:
		telegraph_remaining = maxf(0.0, telegraph_remaining - delta)
		if telegraph_remaining <= 0.0 and pending_pattern != null:
			_fire(pending_pattern)
			cooldown = pending_pattern.cooldown / _cadence_multiplier() + (pending_phrase.recovery_seconds if pending_phrase != null else 0.0)
			pending_pattern = null; pending_phrase = null
		return
	if burst_remaining > 0 and burst_timer <= 0.0 and burst_pattern != null:
		_fire(burst_pattern, false)
		burst_remaining -= 1
		burst_timer = burst_pattern.burst_interval
	if cooldown > 0.0 or not _conditions_met(): return
	var phrase := _select_phrase()
	var pattern := phrase.pattern_for_rating((difficulty.rating if difficulty != null else 50) + sampled_rank_pips * 10) if phrase != null else _select_pattern()
	if pattern == null: return
	var telegraph := phrase.telegraph_seconds if phrase != null else pattern.telegraph_seconds
	if telegraph > 0.0:
		pending_pattern = pattern; pending_phrase = phrase; telegraph_remaining = telegraph
		telegraph_started.emit(phrase.stable_id if phrase != null else pattern.stable_id, telegraph)
		if delta >= telegraph:
			telegraph_remaining = 0.0
			_fire(pending_pattern)
			cooldown = pending_pattern.cooldown / _cadence_multiplier() + (pending_phrase.recovery_seconds if pending_phrase != null else 0.0)
			pending_pattern = null; pending_phrase = null
		return
	_fire(pattern)
	cooldown = pattern.cooldown / _cadence_multiplier() + (phrase.recovery_seconds if phrase != null else 0.0)

func _conditions_met() -> bool:
	var distance := actor.global_position.distance_to(target.global_position) if is_instance_valid(target) else 9999.0
	var ratio := actor.health_component.current / maxf(1.0, actor.health_component.maximum)
	var rating := difficulty.rating if difficulty != null else 50
	return distance >= deck.minimum_distance and distance <= deck.maximum_distance and ratio <= deck.maximum_health_ratio and rating >= deck.minimum_difficulty and player_count >= deck.minimum_player_count and (not deck.elite_only or elite) and formation_ready

func _select_pattern() -> AttackPatternDefinition:
	if deck.attack_patterns.is_empty(): return null
	var available: Array[AttackPatternDefinition] = []
	for candidate in deck.attack_patterns:
		if candidate != null and candidate.stable_id not in disabled_pattern_ids: available.append(candidate)
	if available.is_empty(): return null
	var index := deck_index % available.size()
	if deck.selection_mode == &"random": index = abs(hash("%s:%d" % [actor.actor_id, sequence])) % deck.attack_patterns.size()
	elif deck.selection_mode == &"distance" and is_instance_valid(target): index = clampi(int(actor.position.distance_to(target.position) / 160.0), 0, available.size() - 1)
	index %= available.size()
	deck_index = (index + 1) % available.size()
	return available[index]

func _select_phrase() -> AttackPhraseDefinition:
	if deck.attack_phrases.is_empty(): return null
	var available: Array[AttackPhraseDefinition] = []
	for phrase in deck.attack_phrases:
		if phrase != null: available.append(phrase)
	if available.is_empty(): return null
	var index := phrase_index % available.size()
	phrase_index = (index + 1) % available.size()
	return available[index]

func sample_rank(rank_pips: int) -> void:
	# Rank is sampled only between phrases; an active warning/pattern never changes topology.
	if telegraph_remaining <= 0.0 and burst_remaining <= 0: sampled_rank_pips = clampi(rank_pips, 0, 3)

func _fire(pattern: AttackPatternDefinition, begin_burst := true) -> void:
	var directions := _directions(pattern)
	var spawned := 0
	for direction in directions:
		sequence += 1
		var config := {"actor_id": StringName("projectile.%s.%d" % [actor.actor_id, sequence]), "source_id": actor.actor_id, "source_ability_id": pattern.stable_id, "damage": pattern.damage, "speed": pattern.projectile_speed * _projectile_speed_multiplier(), "team": &"enemies", "direction": direction, "interaction_tags": [&"cancelable"], "registry": registry, "event_bus": event_bus}
		if pool.acquire(_category(pattern), config, Transform2D(direction.angle() + PI * 0.5, actor.global_position)) != null: spawned += 1
	pattern_fired.emit(pattern.stable_id, spawned)
	if begin_burst and pattern.burst_count > 1:
		burst_pattern = pattern
		burst_remaining = pattern.burst_count - 1
		burst_timer = pattern.burst_interval

func _directions(pattern: AttackPatternDefinition) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var aim := actor.global_position.direction_to(target.global_position) if is_instance_valid(target) else Vector2.DOWN
	if pattern.pattern == AttackPatternDefinition.Pattern.PREDICTIVE_BURST and is_instance_valid(target):
		var target_velocity: Vector2 = target.get("velocity") if "velocity" in target else Vector2.ZERO
		var travel_time := actor.global_position.distance_to(target.global_position) / maxf(1.0, pattern.projectile_speed)
		aim = actor.global_position.direction_to(target.global_position + target_velocity * travel_time)
	var count := maxi(1, pattern.projectile_count)
	if pattern.pattern in [AttackPatternDefinition.Pattern.RING, AttackPatternDefinition.Pattern.RADIAL_PULSE]:
		for index in count: result.append(Vector2.DOWN.rotated(TAU * float(index) / count))
	elif pattern.pattern == AttackPatternDefinition.Pattern.WALL_WITH_GAPS:
		for index in count:
			if index % maxi(2, int(ceil(float(count) / pattern.gap_count))) != 0: result.append(Vector2.DOWN)
	else:
		if pattern.pattern == AttackPatternDefinition.Pattern.FIXED_SPREAD: aim = Vector2.DOWN
		elif pattern.pattern == AttackPatternDefinition.Pattern.SPIRAL: aim = Vector2.DOWN.rotated(float(sequence) * 0.31)
		elif pattern.pattern == AttackPatternDefinition.Pattern.ALTERNATING_SPREAD: aim = aim.rotated((-1.0 if sequence % 2 == 0 else 1.0) * deg_to_rad(pattern.spread_degrees * 0.5))
		elif pattern.pattern == AttackPatternDefinition.Pattern.SWEEPING_LASER: aim = Vector2.DOWN.rotated(sin(float(sequence) * 0.35) * deg_to_rad(maxf(15.0, pattern.spread_degrees)))
		for index in count:
			var fraction := 0.5 if count == 1 else float(index) / float(count - 1)
			result.append(aim.rotated(deg_to_rad(lerpf(-pattern.spread_degrees * 0.5, pattern.spread_degrees * 0.5, fraction))))
	return result

func _category(pattern: AttackPatternDefinition) -> StringName:
	if pattern.pattern == AttackPatternDefinition.Pattern.MISSILE_VOLLEY: return &"missile"
	if pattern.pattern == AttackPatternDefinition.Pattern.MINE_FIELD: return &"mine"
	return &"enemy_bullet"

func _cadence_multiplier() -> float:
	var value := difficulty.attack_cadence_multiplier if difficulty != null else 1.0
	if actor is ProductionEnemy and actor.definition != null and actor.definition.elite_profile != null:
		value *= actor.definition.elite_profile.attack_cadence_multiplier
	return value * maxf(0.01, cadence_multiplier)

func _projectile_speed_multiplier() -> float:
	return difficulty.projectile_speed_multiplier if difficulty != null else 1.0
