class_name StageRuntime
extends Node2D

signal stage_started(mission_id: StringName, seed: int)
signal segment_changed(node_id: StringName, segment_id: StringName)
signal stage_completed
signal segment_cleared(segment_id: StringName)
signal enemy_spawn_requested(enemy_id: StringName, position: Vector2, formation: FormationRuntime, slot: int)
signal branch_choice_requested(node_id: StringName, choices: Array[StringName])
signal objective_resolved(objective_id: StringName, succeeded: bool, reward: Dictionary, dialogue_hook: StringName)

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
var runtime_context: Dictionary = {}
var _branch_gate_id: StringName
var _mode_segments_cleared := 0

func configure(game_session: GameSession, content_database: ContentDatabase, stage_plan: StagePlan, context: Dictionary = {}) -> bool:
	if is_inside_tree() or game_session == null or content_database == null or stage_plan == null: return false
	session = game_session
	database = content_database
	plan = stage_plan
	runtime_context = context.duplicate()
	if bool(session.config.mode_rules.get("campaign", true)): return StageValidator.validate(plan, session.config.mission_definition, session.config.effective_player_count()).valid
	return _validate_mode_plan()

func _ready() -> void:
	objectives = ObjectiveController.new()
	objectives.name = "ObjectiveController"
	add_child(objectives)
	objectives.objective_resolved.connect(_on_objective_resolved)
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
	if not _branch_gate_id.is_empty():
		current_segment.release_external_gate(_branch_gate_id)
		_branch_gate_id = &""
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
	var source_definition := plan.definition_for(node_id)
	if source_definition == null: return
	var difficulty := database.get_definition(session.difficulty_profile, &"difficulty_profile") as DifficultyProfileDefinition
	if difficulty == null: difficulty = database.get_definition(StringName("difficulty.%s" % session.difficulty_profile), &"difficulty_profile") as DifficultyProfileDefinition
	var rating := int(session.config.mode_rules.get("difficulty_rating", difficulty.rating if difficulty != null else 50))
	if StringName(session.config.mode_rules.get("mode_id", "")) in [&"survival", &"endless"]:
		rating = mini(100, rating + _mode_segments_cleared * int(session.config.mode_rules.get("difficulty_per_segment", 3)))
	var definition := EncounterPackageResolver.resolve(source_definition, session.config.mission_definition, node_id, plan.seed, rating, session.config.effective_player_count())
	current_segment = StageSegmentRuntime.new()
	current_segment.name = "Segment_%s" % definition.stable_id
	current_segment.configure(definition, objectives, secrets, runtime_context)
	current_segment.segment_completed.connect(_on_segment_completed)
	current_segment.checkpoint_ready.connect(_on_checkpoint_ready)
	current_segment.enemy_spawn_requested.connect(func(enemy_id, spawn_position, formation, slot): enemy_spawn_requested.emit(enemy_id, spawn_position, formation, slot))
	add_child(current_segment)
	if not runtime_snapshot.is_empty(): current_segment.restore(runtime_snapshot)
	var node := plan.node_for(node_id)
	var branch_choices: Array[StringName] = []
	branch_choices.assign(node.get("next_ids", []))
	var branch_required := branch_choices.size() > 1 and not route_choices.has(node_id)
	if branch_required:
		_branch_gate_id = StringName("branch.%s" % node_id)
		current_segment.acquire_external_gate(_branch_gate_id)
	session.current_segment = session.current_route.size()
	if session.current_route.is_empty() or session.current_route[-1] != node_id: session.current_route.append(node_id)
	session.active_waves = definition.waves.size()
	segment_changed.emit(node_id, definition.stable_id)
	if branch_required: branch_choice_requested.emit(node_id, branch_choices)

func _on_objective_resolved(objective_id: StringName, succeeded: bool, reward: Dictionary, dialogue_hook: StringName) -> void:
	if succeeded:
		session.reward_state.credits = int(session.reward_state.get("credits", 0)) + int(reward.get("credits", 0))
		if reward.has("item_id"): session.reward_state.items.append(reward.item_id)
	elif objectives.definition_for(objective_id) != null and not objectives.definition_for(objective_id).optional:
		session.complete_session(false, &"objective_failed")
	if not dialogue_hook.is_empty() and database.get_definition(dialogue_hook, &"dialogue") != null:
		session.services.story.start_dialogue(dialogue_hook, {"objective_id": objective_id, "succeeded": succeeded})
	objective_resolved.emit(objective_id, succeeded, reward, dialogue_hook)

func _on_segment_completed(segment_id: StringName) -> void:
	if segment_id not in cleared_segment_ids: cleared_segment_ids.append(segment_id)
	session.active_waves = 0
	var finished := current_segment
	current_segment = null
	finished.unload()
	segment_cleared.emit(segment_id)
	var next_id := _next_node_id()
	_mode_segments_cleared += 1
	var mode_id := StringName(session.config.mode_rules.get("mode_id", ""))
	if next_id.is_empty() and mode_id in [&"survival", &"endless"]:
		var target := maxi(1, int(session.config.mode_rules.get("survival_segments", 12)))
		if mode_id == &"endless" or _mode_segments_cleared < target:
			next_id = plan.main_route[0]
	call_deferred("_activate_node", next_id)

func _on_checkpoint_ready(kind: StringName, safe_spawn: Vector2, runtime_snapshot: Dictionary) -> void:
	if not bool(session.config.mode_rules.get("campaign", true)) and not bool(session.config.mode_rules.get("checkpoints_enabled", false)): return
	var cleared_id := StringName(runtime_snapshot.get("segment_id", ""))
	if not cleared_id.is_empty() and cleared_id not in cleared_segment_ids: cleared_segment_ids.append(cleared_id)
	session.stage_plan_snapshot = plan.to_snapshot()
	session.cleared_segment_ids = cleared_segment_ids.duplicate()
	session.next_segment_id = _next_node_id()
	session.route_choices = route_choices.duplicate(true)
	session.safe_spawn = safe_spawn
	session.segment_runtime_snapshot = runtime_snapshot.duplicate(true)
	var tracker := runtime_context.get("score_tracker") as MissionScoreTracker
	if tracker != null: session.mission_state.score_snapshot = tracker.snapshot()
	session.mission_state.combat_replay = CombatReplayState.snapshot(tracker, runtime_context.get("players", []))
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

func _validate_mode_plan() -> bool:
	if plan.nodes.is_empty() or plan.main_route.is_empty(): return false
	var ids := {}
	for node in plan.nodes:
		var node_id := StringName(node.get("node_id", ""))
		var definition := plan.definition_for(node_id)
		if node_id.is_empty() or ids.has(node_id) or definition == null or not definition.validate_definition().is_empty(): return false
		if session.config.effective_player_count() > 1 and not StageValidator._supports_local_players(definition, session.config.effective_player_count()): return false
		ids[node_id] = true
	for node in plan.nodes:
		for next_id in node.get("next_ids", []):
			if not ids.has(StringName(next_id)): return false
	return true
