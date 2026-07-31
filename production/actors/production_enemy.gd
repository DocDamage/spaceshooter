class_name ProductionEnemy
extends BaseActor2D

signal defeated(actor_id: StringName, credits: int)
signal rewards_attributed(source_player_id: StringName, score: int, experience: int, drops: Array[Dictionary])
signal destruction_started(actor_id: StringName, effect_id: StringName)

var definition: EnemyDefinition
var movement_controller: EnemyMovementController
var attack_controller: EnemyAttackController
var formation: FormationRuntime
var formation_slot := -1
var difficulty: DifficultyProfileDefinition
var source_player_ids: Array[StringName] = []
var stage_seed := 0
var _last_damage_source: StringName
var _visual: Sprite2D
var _escaping := false
var presentation: PresentationActor

func _init() -> void:
	super()
	movement_controller = EnemyMovementController.new()
	movement_controller.name = "MovementController"
	add_child(movement_controller)
	attack_controller = EnemyAttackController.new()
	attack_controller.name = "AttackController"
	add_child(attack_controller)
	_visual = Sprite2D.new()
	_visual.name = "VisualRoot"
	add_child(_visual)
	presentation = PresentationActor.new()
	presentation.name = "PresentationActor"
	add_child(presentation)

func configure(id: StringName, enemy_definition: EnemyDefinition, session_registry: ActorRegistry, session_events: TypedEventBus, target: Node2D = null, projectile_pool: ProjectilePoolManager = null, difficulty_profile: DifficultyProfileDefinition = null, use_pool := false) -> void:
	configure_actor(id, &"enemy", &"enemies", session_registry, session_events, use_pool)
	definition = enemy_definition
	difficulty = difficulty_profile
	var health_scale := difficulty.health_multiplier if difficulty != null else 1.0
	var shield_scale := difficulty.shield_multiplier if difficulty != null else 1.0
	var speed_scale := difficulty.speed_multiplier if difficulty != null else 1.0
	if definition.elite_profile != null:
		health_scale *= definition.elite_profile.health_multiplier
		speed_scale *= definition.elite_profile.speed_multiplier
	health_component.configure(definition.max_health * health_scale)
	armor_component.configure(definition.armor + (definition.elite_profile.armor_bonus if definition.elite_profile != null else 0.0))
	shield_component.configure((definition.shield_capacity + (definition.elite_profile.shield_bonus if definition.elite_profile != null else 0.0)) * shield_scale)
	hurtbox_component.configure(definition.collision_radius * definition.collision_scale)
	hitbox_component.configure(definition.collision_radius * definition.collision_scale, 25.0)
	_initialize_visual()
	presentation.configure(_visual)
	presentation.targetability_changed.connect(func(value): hurtbox_component.enabled = value)
	var move := definition.movement_pattern if definition.movement_pattern != null else _fallback_movement(definition.move_speed * speed_scale)
	movement_controller.configure(self, move, target)
	if definition.attack_deck != null and projectile_pool != null:
		attack_controller.configure(self, definition.attack_deck, target, projectile_pool, session_registry, session_events)
		attack_controller.difficulty = difficulty
		attack_controller.elite = definition.elite_profile != null
	_escaping = false

func _ready() -> void:
	super()
	collision_layer = 4
	collision_mask = 2
	if get_node_or_null("CollisionShape2D") == null:
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape := CircleShape2D.new()
		shape.radius = definition.collision_radius if definition != null else 18.0
		collision.shape = shape
		add_child(collision)
	queue_redraw()

func _physics_process(delta: float) -> void:
	super(delta)
	if not active or definition == null: return
	if _escaping:
		position.y -= definition.move_speed * 1.5 * delta
	else:
		movement_controller.tick(delta, difficulty.speed_multiplier if difficulty != null else 1.0)
		attack_controller.tick(delta)

func receive_damage(packet: DamagePacket) -> DamageResult:
	_last_damage_source = packet.source_player_id if not packet.source_player_id.is_empty() else packet.source_actor_id
	return super(packet)

func destroy_actor(source_actor_id: StringName) -> void:
	if not active: return
	var credited := _last_damage_source if not _last_damage_source.is_empty() else source_actor_id
	var table := definition.elite_profile.drop_table if definition.elite_profile != null and definition.elite_profile.drop_table != null else definition.drop_table
	var drops := DropResolver.resolve(table, stage_seed + hash(actor_id), difficulty.drop_multiplier if difficulty != null else 1.0, source_player_ids, credited)
	var effect_id := definition.elite_profile.death_effect_id if definition.elite_profile != null else &"effect.enemy_destroyed"
	destruction_started.emit(actor_id, effect_id)
	defeated.emit(actor_id, definition.reward_credits)
	rewards_attributed.emit(credited, definition.reward_score, definition.reward_experience, drops)
	if event_bus != null:
		event_bus.publish(RewardGrantedEvent.new(actor_id, credited, &"score", definition.reward_score))
		event_bus.publish(RewardGrantedEvent.new(actor_id, credited, &"experience", definition.reward_experience))
	super(source_actor_id)

func set_formation_target(target_position: Vector2) -> void:
	movement_controller.formation_target = target_position

func leave_formation() -> void:
	formation = null
	formation_slot = -1

func request_escape() -> void:
	_escaping = true

func reset_for_pool() -> void:
	_last_damage_source = &""
	formation = null
	formation_slot = -1
	_escaping = false
	position = Vector2.ZERO
	rotation = 0.0
	modulate = Color.WHITE

func _initialize_visual() -> void:
	_visual.texture = null
	if not definition.visual_asset_path.is_empty() and ResourceLoader.exists(definition.visual_asset_path):
		_visual.texture = load(definition.visual_asset_path) as Texture2D
	_visual.scale = Vector2.ONE * definition.visual_scale
	_visual.modulate = definition.elite_profile.tint if definition.elite_profile != null else definition.visual_tint

func _fallback_movement(speed: float) -> MovementPatternDefinition:
	var pattern := MovementPatternDefinition.new()
	pattern.stable_id = &"movement.fallback"
	pattern.speed = speed
	return pattern

func _draw() -> void:
	if _visual.texture == null:
		draw_colored_polygon(PackedVector2Array([Vector2(0, 22), Vector2(22, -15), Vector2(0, -8), Vector2(-22, -15)]), Color("ff6783"))
		draw_circle(Vector2.ZERO, 5.0, Color("ffd36d"))
