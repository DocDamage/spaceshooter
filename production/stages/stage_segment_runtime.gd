class_name StageSegmentRuntime
extends Node2D

signal enemy_spawn_requested(enemy_id: StringName, position: Vector2, formation: FormationRuntime, slot: int)
signal segment_completed(segment_id: StringName)
signal checkpoint_ready(checkpoint_kind: StringName, safe_spawn: Vector2, snapshot: Dictionary)

var definition: StageSegmentDefinition
var objective_controller: ObjectiveController
var secret_controller: SecretController
var wave_scheduler: WaveScheduler
var elapsed := 0.0
var active := false
var _objective_ids: Array[StringName] = []
var _completion_emitted := false
var _external_gates: Dictionary = {}
var parallax: ParallaxPresentation

func configure(segment_definition: StageSegmentDefinition, objectives: ObjectiveController, secrets: SecretController) -> bool:
	if is_inside_tree() or segment_definition == null: return false
	definition = segment_definition
	objective_controller = objectives
	secret_controller = secrets
	return definition.validate_definition().is_empty()

func _ready() -> void:
	if definition == null: return
	_build_backgrounds()
	_build_hazards()
	for objective in definition.objectives: _objective_ids.append(objective.stable_id)
	objective_controller.register(definition.objectives)
	secret_controller.register(definition.secrets)
	objective_controller.start(&"segment_start")
	wave_scheduler = WaveScheduler.new()
	wave_scheduler.name = "WaveScheduler"
	wave_scheduler.configure(definition.waves)
	wave_scheduler.enemy_spawn_requested.connect(func(enemy_id, spawn_position, formation, slot): enemy_spawn_requested.emit(enemy_id, spawn_position, formation, slot))
	add_child(wave_scheduler)
	active = true
	if not definition.waves.is_empty(): wave_scheduler.start()

func _process(delta: float) -> void:
	if not active or _completion_emitted: return
	elapsed += delta
	if parallax != null: parallax.tick(delta)
	objective_controller.tick(delta)
	if wave_scheduler != null: wave_scheduler.tick(delta)
	var waves_complete := definition.waves.is_empty() or not wave_scheduler.running
	if elapsed >= definition.minimum_duration and waves_complete and objective_controller.required_complete(_objective_ids) and _external_gates.is_empty():
		complete()

func acquire_external_gate(gate_id: StringName) -> bool:
	if gate_id.is_empty() or _completion_emitted: return false
	_external_gates[gate_id] = true
	return true

func release_external_gate(gate_id: StringName) -> bool:
	return _external_gates.erase(gate_id)

func complete() -> void:
	if _completion_emitted: return
	_completion_emitted = true
	active = false
	if definition.checkpoint_kind != "none":
		checkpoint_ready.emit(StringName(definition.checkpoint_kind), definition.safe_spawn_points[0], snapshot())
	segment_completed.emit(definition.stable_id)

func snapshot() -> Dictionary:
	return {"segment_id": definition.stable_id, "elapsed": elapsed, "active": active, "wave": wave_scheduler.snapshot() if wave_scheduler != null else {}, "objectives": objective_controller.snapshot(), "secrets": secret_controller.snapshot(), "external_gates": _external_gates.keys()}

func restore(data: Dictionary) -> bool:
	if definition == null or StringName(data.get("segment_id", "")) != definition.stable_id: return false
	elapsed = maxf(0.0, float(data.get("elapsed", 0.0)))
	active = bool(data.get("active", true))
	objective_controller.restore(data.get("objectives", {}))
	secret_controller.restore(data.get("secrets", {}))
	_external_gates.clear()
	for gate_id in data.get("external_gates", []): _external_gates[StringName(gate_id)] = true
	if wave_scheduler != null and not data.get("wave", {}).is_empty(): wave_scheduler.restore(data.wave)
	return true

func validate_local_multiplayer(local_players: int) -> bool:
	return StageValidator._supports_local_players(definition, local_players)

func unload() -> void:
	active = false
	queue_free()

func _build_backgrounds() -> void:
	parallax = ParallaxPresentation.new()
	parallax.name = "ParallaxPresentation"
	var settings_service: SettingsService = null
	var stage := get_parent() as StageRuntime
	if stage != null and stage.session != null: settings_service = stage.session.services.settings
	parallax.configure(definition.background_layers, settings_service)
	add_child(parallax)

func _build_hazards() -> void:
	for hazard_id in definition.hazard_ids:
		var hazard := Node2D.new()
		hazard.name = "Hazard_%s" % hazard_id
		hazard.set_meta(&"hazard_id", hazard_id)
		add_child(hazard)
