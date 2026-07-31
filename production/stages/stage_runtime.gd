class_name StageRuntime
extends Node2D

signal stage_started(mission_id: StringName, seed: int)
signal segment_changed(node_id: StringName, segment_id: StringName)
signal stage_completed
signal enemy_spawn_requested(enemy_id: StringName, position: Vector2, formation: FormationRuntime, slot: int)

var session: GameSession
var database: ContentDatabase
var plan: StagePlan
var objectives: ObjectiveController
var secrets: SecretController
var current_segment: StageSegmentRuntime
var route_index := 0
var current_node_id: StringName
var cleared_segment_ids: Array[StringName] = []
var route_choices: Dictionary = {}

func configure(game_session: GameSession, content_database: ContentDatabase, stage_plan: StagePlan) -> bool:
	if is_inside_tree() or game_session == null or content_database == null or stage_plan == null: return false
	session = game_session
	database = content_database
	plan = stage_plan
	return StageValidator.validate(plan, session.config.mission_definition, session.config.effective_player_count()).valid

func _ready() -> void:
	objectives = ObjectiveController.new()
	objectives.name = "ObjectiveController"
	add_child(objectives)
	secrets = SecretController.new()
	secrets.name = "SecretController"
	add_child(secrets)
	session.stage_plan_snapshot = plan.to_snapshot()
	stage_started.emit(plan.mission_id, plan.seed)
	_activate_route_index(route_index)

func choose_branch(next_node_id: StringName) -> bool:
	if current_segment == null: return false
	var node := plan.node_for(current_node_id)
	if next_node_id not in node.get("next_ids", []): return false
	route_choices[current_node_id] = next_node_id
	secrets.trigger(&"branch", next_node_id)
	return true

func restore_from_checkpoint(snapshot: Dictionary) -> bool:
	if not session.restore_checkpoint(snapshot): return false
	plan = StagePlan.from_snapshot(snapshot.get("stage_plan", {}), database)
	cleared_segment_ids.assign(snapshot.get("cleared_segment_ids", []))
	route_choices = snapshot.get("route_choices", {}).duplicate(true)
	objectives.restore(snapshot.get("objective_state", {}))
	secrets.restore(snapshot.get("secret_state", {}))
	var next_id := StringName(snapshot.get("next_segment_id", ""))
	route_index = plan.main_route.find(next_id)
	if route_index < 0: route_index = clampi(int(snapshot.get("segment", 0)), 0, plan.main_route.size() - 1)
	if current_segment != null: current_segment.unload()
	_activate_node(next_id if not next_id.is_empty() else plan.main_route[route_index], snapshot.get("segment_runtime", {}))
	return true

func _activate_route_index(index: int, runtime_snapshot: Dictionary = {}) -> void:
	if index >= plan.main_route.size():
		stage_completed.emit()
		return
	_activate_node(plan.main_route[index], runtime_snapshot)

func _activate_node(node_id: StringName, runtime_snapshot: Dictionary = {}) -> void:
	if node_id.is_empty():
		stage_completed.emit()
		return
	current_node_id = node_id
	route_index = plan.main_route.find(node_id)
	var definition := plan.definition_for(node_id)
	if definition == null: return
	current_segment = StageSegmentRuntime.new()
	current_segment.name = "Segment_%s" % definition.stable_id
	current_segment.configure(definition, objectives, secrets)
	current_segment.segment_completed.connect(_on_segment_completed)
	current_segment.checkpoint_ready.connect(_on_checkpoint_ready)
	current_segment.enemy_spawn_requested.connect(func(enemy_id, spawn_position, formation, slot): enemy_spawn_requested.emit(enemy_id, spawn_position, formation, slot))
	add_child(current_segment)
	if not runtime_snapshot.is_empty(): current_segment.restore(runtime_snapshot)
	session.current_segment = session.current_route.size()
	if session.current_route.is_empty() or session.current_route[-1] != node_id: session.current_route.append(node_id)
	session.active_waves = definition.waves.size()
	segment_changed.emit(node_id, definition.stable_id)

func _on_segment_completed(segment_id: StringName) -> void:
	if segment_id not in cleared_segment_ids: cleared_segment_ids.append(segment_id)
	session.active_waves = 0
	var finished := current_segment
	current_segment = null
	finished.unload()
	var next_id := _next_node_id()
	call_deferred("_activate_node", next_id)

func _on_checkpoint_ready(kind: StringName, safe_spawn: Vector2, runtime_snapshot: Dictionary) -> void:
	var cleared_id := StringName(runtime_snapshot.get("segment_id", ""))
	if not cleared_id.is_empty() and cleared_id not in cleared_segment_ids: cleared_segment_ids.append(cleared_id)
	session.stage_plan_snapshot = plan.to_snapshot()
	session.cleared_segment_ids = cleared_segment_ids.duplicate()
	session.next_segment_id = _next_node_id()
	session.route_choices = route_choices.duplicate(true)
	session.safe_spawn = safe_spawn
	session.segment_runtime_snapshot = {}
	session.objective_state = objectives.snapshot()
	session.secret_state = secrets.snapshot()
	session.create_checkpoint(kind)

func _next_node_id() -> StringName:
	var node := plan.node_for(current_node_id)
	var next_ids: Array = node.get("next_ids", [])
	if next_ids.is_empty(): return &""
	var chosen := StringName(route_choices.get(current_node_id, ""))
	if not chosen.is_empty() and chosen in next_ids: return chosen
	if route_index >= 0 and route_index + 1 < plan.main_route.size() and plan.main_route[route_index + 1] in next_ids:
		return plan.main_route[route_index + 1]
	return StringName(next_ids[0])
