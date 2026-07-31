class_name BossActor
extends BaseActor2D

signal part_destroyed(part_id: StringName, effects: Dictionary)
signal phase_entered(phase_id: StringName, phase_index: int)
signal summon_requested(enemy_id: StringName, summon_index: int)
signal arena_behavior_requested(behavior: Dictionary)
signal dialogue_requested(dialogue_id: StringName)
signal music_state_requested(music_state: StringName)
signal rewards_ready(rewards: Dictionary, challenge_results: Dictionary)

var definition: BossDefinition
var phase_machine := BossPhaseStateMachine.new()
var summon_controller := BossSummonController.new()
var challenge_tracker := BossChallengeTracker.new()
var parts: Dictionary = {}
var arena_controller: BossArenaController
var hud: BossHUD
var attack_controller: EnemyAttackController
var movement_controller: EnemyMovementController
var practice_session: BossPracticeSession
var active_variant: BossVariantDefinition
var disabled_attack_ids: Array[StringName] = []
var damage_taken_multiplier := 1.0
var movement_multiplier := 1.0
var external_phase_transition := false
var combat_target: Node2D
var projectile_pool: ProjectilePoolManager
var difficulty: DifficultyProfileDefinition
var _visual: Sprite2D

func _init() -> void:
	super()
	_visual = Sprite2D.new()
	_visual.name = "VisualRoot"
	add_child(_visual)

func configure_boss(boss_definition: BossDefinition, session_registry: ActorRegistry, events: TypedEventBus, arena: BossArenaController = null, practice: BossPracticeSession = null, ng_plus_cycle := 0) -> bool:
	if boss_definition == null or not boss_definition.validate_definition().is_empty(): return false
	definition = boss_definition
	practice_session = practice
	arena_controller = arena
	configure_actor(definition.stable_id, &"miniboss" if definition.is_miniboss else &"boss", &"enemies", session_registry, events)
	health_component.configure(definition.maximum_health)
	armor_component.configure(definition.armor)
	shield_component.configure(definition.shield_capacity)
	hurtbox_component.configure(definition.collision_radius)
	hitbox_component.configure(definition.collision_radius, 40.0 if definition.is_miniboss else 70.0)
	_visual.texture = load(definition.visual_asset_path) as Texture2D if not definition.visual_asset_path.is_empty() and ResourceLoader.exists(definition.visual_asset_path) else null
	_visual.scale = Vector2.ONE * definition.visual_scale
	_visual.modulate = definition.visual_tint
	active_variant = _select_variant(ng_plus_cycle)
	if arena_controller != null and active_variant != null: arena_controller.apply_phase_behavior(active_variant.arena_overrides)
	phase_machine.configure(definition.phases, practice.starting_phase if practice != null else 0)
	challenge_tracker.configure(definition.challenges, practice != null)
	parts.clear()
	var authored_parts: Array[BossPartDefinition] = definition.parts.duplicate()
	if active_variant != null: authored_parts.append_array(active_variant.added_parts)
	for part_definition in authored_parts:
		if active_variant != null and part_definition.stable_id in active_variant.removed_part_ids: continue
		var part := BossPartRuntime.new(); part.configure(part_definition); part.destroyed.connect(_on_part_destroyed); parts[part_definition.stable_id] = part
	return true

func configure_combat_context(target: Node2D, pool: ProjectilePoolManager, difficulty_profile: DifficultyProfileDefinition = null) -> void:
	combat_target = target
	projectile_pool = pool
	difficulty = difficulty_profile
	_configure_phase_controllers()

func _ready() -> void:
	super._ready()
	if definition == null: return
	collision_layer = 4
	collision_mask = 2
	if get_node_or_null("CollisionShape2D") == null:
		var collision := CollisionShape2D.new(); collision.name = "CollisionShape2D"
		var shape := CircleShape2D.new(); shape.radius = definition.collision_radius; collision.shape = shape; add_child(collision)
	phase_machine.phase_changed.connect(_on_phase_changed)
	phase_machine.enraged.connect(func(_phase_id): _configure_phase_controllers())
	summon_controller.summon_requested.connect(func(enemy_id, index): summon_requested.emit(enemy_id, index))
	if hud == null: hud = BossHUD.new(); hud.name = "BossHUD"; add_child(hud)
	hud.bind_boss(self)
	_apply_phase(phase_machine.current_phase())
	if not definition.intro_dialogue_id.is_empty(): dialogue_requested.emit(definition.intro_dialogue_id)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not active or definition == null: return
	var destroyed_count := 0
	for part in parts.values():
		if part.current_health <= 0.0: destroyed_count += 1
	phase_machine.tick(delta, health_component.current / health_component.maximum, destroyed_count, external_phase_transition)
	external_phase_transition = false
	challenge_tracker.tick(delta)
	var phase := phase_machine.current_phase()
	var extras: Array[StringName] = []
	if active_variant != null: extras.assign(active_variant.additional_summon_ids)
	summon_controller.tick(delta, phase, extras)
	if attack_controller != null: attack_controller.tick(delta)
	if movement_controller != null: movement_controller.tick(delta, movement_multiplier)
	if hud != null: hud.refresh(self)

func receive_part_damage(part_id: StringName, amount: float, armor_penetration := 0.0) -> float:
	var part: BossPartRuntime = parts.get(part_id)
	return part.receive_damage(amount, armor_penetration) if part != null else 0.0

func on_damage_resolved(packet: DamagePacket, result: DamageResult) -> void:
	if result.health_damage > 0.0 and damage_taken_multiplier > 1.0:
		var bonus := minf(health_component.current, result.health_damage * (damage_taken_multiplier - 1.0))
		health_component.apply_damage(bonus); result.health_damage += bonus
	super.on_damage_resolved(packet, result)

func destroy_actor(source_actor_id: StringName) -> void:
	if not active: return
	var challenges := challenge_tracker.complete_results()
	var rewards := definition.guaranteed_rewards.duplicate(true)
	if active_variant != null: _merge_rewards(rewards, active_variant.reward_overrides)
	for challenge in definition.challenges:
		if challenge != null and bool(challenges.get(challenge.stable_id, {}).get("passed", false)) and practice_session == null: _merge_rewards(rewards, challenge.reward_overrides)
	for part in parts.values():
		if part.current_health <= 0.0: _merge_rewards(rewards, part.definition.reward_bonus)
	if practice_session != null and not practice_session.rewards_enabled: rewards.clear()
	rewards_ready.emit(rewards, challenges)
	if arena_controller != null: arena_controller.clear_arena()
	if not definition.defeat_dialogue_id.is_empty(): dialogue_requested.emit(definition.defeat_dialogue_id)
	super.destroy_actor(source_actor_id)

func force_phase_transition() -> void:
	external_phase_transition = true

func snapshot_boss() -> Dictionary:
	var part_data := {}
	for part_id in parts: part_data[part_id] = parts[part_id].snapshot()
	return {"boss_id": definition.stable_id if definition != null else &"", "health": health_component.current, "shield": shield_component.current, "phase": phase_machine.snapshot(), "parts": part_data, "challenges": challenge_tracker.states.duplicate(true)}

func restore_boss(data: Dictionary) -> bool:
	if definition == null or StringName(data.get("boss_id", "")) != definition.stable_id: return false
	health_component.current = clampf(float(data.get("health", health_component.maximum)), 0.0, health_component.maximum)
	shield_component.current = clampf(float(data.get("shield", shield_component.capacity)), 0.0, shield_component.capacity)
	phase_machine.restore(data.get("phase", {}))
	for part_id in data.get("parts", {}):
		if parts.has(part_id): parts[part_id].restore(data.parts[part_id])
	challenge_tracker.states.merge(data.get("challenges", {}), true)
	_apply_phase(phase_machine.current_phase())
	return true

func _on_part_destroyed(part_id: StringName) -> void:
	var part: BossPartRuntime = parts[part_id]
	for attack_id in part.definition.removed_attack_ids:
		if attack_id not in disabled_attack_ids: disabled_attack_ids.append(attack_id)
	damage_taken_multiplier = maxf(damage_taken_multiplier, part.definition.exposes_weakness_multiplier)
	movement_multiplier *= part.definition.movement_multiplier_after_destroyed
	var destroyed_count := 0
	for candidate in parts.values():
		if candidate.current_health <= 0.0: destroyed_count += 1
	challenge_tracker.record(&"parts_progress", float(destroyed_count) / maxf(1.0, parts.size()))
	part_destroyed.emit(part_id, {"removed_attacks": part.definition.removed_attack_ids, "weakness_multiplier": damage_taken_multiplier, "movement_multiplier": movement_multiplier, "retaliation_attack_id": part.definition.retaliation_attack_id})

func _on_phase_changed(previous: int, current: int, phase: BossPhaseDefinition) -> void:
	_apply_phase(phase)
	phase_entered.emit(phase.stable_id, current)
	if event_bus != null: event_bus.publish(BossPhaseChangedEvent.new(actor_id, actor_id, current))

func _apply_phase(phase: BossPhaseDefinition) -> void:
	if phase == null: return
	for part in parts.values(): part.set_phase(phase.stable_id)
	_configure_phase_controllers()
	if arena_controller != null: arena_controller.apply_phase_behavior(phase.arena_behavior)
	arena_behavior_requested.emit(phase.arena_behavior)
	if not phase.dialogue_id.is_empty(): dialogue_requested.emit(phase.dialogue_id)
	if not phase.music_state.is_empty(): music_state_requested.emit(phase.music_state)
	if phase.transition_behavior == &"brief_invulnerability": grant_invulnerability(0.5)

func _configure_phase_controllers() -> void:
	var phase := phase_machine.current_phase()
	if phase == null: return
	var decks := phase.attack_decks.duplicate()
	if active_variant != null:
		decks.append_array(active_variant.added_attack_decks)
	var selected_deck: AttackDeckDefinition = phase.enrage_attack_deck if phase_machine.is_enraged and phase.enrage_attack_deck != null else (decks[0] if not decks.is_empty() else null)
	if active_variant != null and active_variant.replacement_attack_decks.has(phase.stable_id): selected_deck = active_variant.replacement_attack_decks[phase.stable_id]
	if selected_deck != null:
		if attack_controller == null: attack_controller = EnemyAttackController.new(); attack_controller.name = "AttackController"; add_child(attack_controller)
		attack_controller.configure(self, selected_deck, combat_target, projectile_pool, registry, event_bus)
		attack_controller.difficulty = difficulty
		attack_controller.disabled_pattern_ids = disabled_attack_ids
		attack_controller.cadence_multiplier = active_variant.cadence_multiplier if active_variant != null else 1.0
	if not phase.movement_patterns.is_empty():
		if movement_controller == null: movement_controller = EnemyMovementController.new(); movement_controller.name = "MovementController"; add_child(movement_controller)
		movement_controller.configure(self, phase.movement_patterns[0])

func _select_variant(ng_plus_cycle: int) -> BossVariantDefinition:
	var selected: BossVariantDefinition
	for variant in definition.variants:
		if variant != null and ng_plus_cycle >= variant.minimum_new_game_plus_cycle and (selected == null or variant.minimum_new_game_plus_cycle > selected.minimum_new_game_plus_cycle): selected = variant
	return selected

func _merge_rewards(target_rewards: Dictionary, additions: Dictionary) -> void:
	for key in additions:
		if additions[key] is int or additions[key] is float:
			target_rewards[key] = float(target_rewards.get(key, 0.0)) + float(additions[key])
			if additions[key] is int and target_rewards[key] == floorf(target_rewards[key]): target_rewards[key] = int(target_rewards[key])
		else:
			target_rewards[key] = additions[key]
