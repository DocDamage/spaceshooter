class_name EnemyLaboratory
extends Node2D

var database: ContentDatabase
var registry: ActorRegistry
var events: TypedEventBus
var projectile_pool: ProjectilePoolManager
var enemy_pool: EnemyPoolManager
var target: Node2D
var selected_index := 0
var roster: Array[ContentDefinition] = []
var status_label: Label

func _ready() -> void:
	database = ContentDatabase.new()
	add_child(database)
	registry = ActorRegistry.new()
	add_child(registry)
	events = TypedEventBus.new()
	projectile_pool = ProjectilePoolManager.new()
	add_child(projectile_pool)
	enemy_pool = EnemyPoolManager.new()
	add_child(enemy_pool)
	target = Node2D.new()
	target.position = Vector2(270, 800)
	add_child(target)
	status_label = Label.new()
	status_label.position = Vector2(16, 16)
	add_child(status_label)
	if database.initialize():
		roster = database.get_definitions_by_type(&"enemy")
	_spawn_selected()

func _unhandled_input(event: InputEvent) -> void:
	if roster.is_empty(): return
	if event.is_action_pressed("game_left"):
		selected_index = posmod(selected_index - 1, roster.size())
		_spawn_selected()
	elif event.is_action_pressed("game_right"):
		selected_index = posmod(selected_index + 1, roster.size())
		_spawn_selected()
	elif event.is_action_pressed("game_a"):
		_spawn_selected()

func _spawn_selected() -> void:
	if roster.is_empty():
		status_label.text = "No enemy definitions found"
		return
	enemy_pool.release_all()
	var definition := roster[selected_index] as EnemyDefinition
	var normal := database.get_definition(&"difficulty.normal", &"difficulty_profile") as DifficultyProfileDefinition
	var enemy := enemy_pool.acquire({"actor_id": StringName("lab.%d" % selected_index), "definition": definition, "registry": registry, "event_bus": events, "target": target, "projectile_pool": projectile_pool, "difficulty": normal}, Vector2(270, 160))
	var role := definition.resolved_archetype().role_name() if definition.resolved_archetype() != null else &"legacy"
	var score := definition.resolved_behavior_score()
	var phrase_state := "legacy deck" if score == null else "%d phrases • %s" % [score.phrases.size(), "VALID" if EnemyPhraseValidator.validate_behavior(score).is_empty() else "CHECK LANES"]
	status_label.text = "%s  [%d/%d]\nLeft/Right: roster   Fire: respawn\nRole: %s   Movement: %s\nChoreography: %s   Telegraph: %.2fs" % [definition.display_name, selected_index + 1, roster.size(), role, definition.movement_pattern.display_name if definition.movement_pattern else "fallback", phrase_state, enemy.attack_controller.telegraph_remaining if enemy != null else 0.0]
	if enemy != null: enemy.stage_seed = 7007
