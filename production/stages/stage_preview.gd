class_name StagePreview
extends Control

signal launch_segment_requested(segment_id: StringName, seed: int)
signal launch_stage_requested(plan: StagePlan)

var mission: MissionDefinition
var generator := StageGraphGenerator.new()
var seed_input: SpinBox
var output: RichTextLabel
var plans: Array[StagePlan] = []
var selected_plan := 0
var choreography_notes := PackedStringArray()

func configure(mission_definition: MissionDefinition) -> void:
	mission = mission_definition

func set_choreography_notes(behavior: EnemyBehaviorScoreDefinition) -> void:
	choreography_notes.clear()
	if behavior == null: return
	choreography_notes.append("%s — %s" % [behavior.display_name, "SAFE LANES VALID" if EnemyPhraseValidator.validate_behavior(behavior).is_empty() else "SAFE LANE REVIEW REQUIRED"])
	choreography_notes.append("Replay fingerprint: %s" % behavior.fingerprint(mission.default_seed if mission != null else 0))

func _ready() -> void:
	_build_ui()
	if mission != null: generate_previews(3)

func generate_previews(count := 3) -> Array[StagePlan]:
	plans.clear()
	if mission == null: return plans
	var base_seed := int(seed_input.value) if seed_input != null else mission.default_seed
	for offset in clampi(count, 1, 20):
		var plan := generator.generate(mission, base_seed + offset)
		if plan != null: plans.append(plan)
	selected_plan = 0
	_render()
	return plans

func select_plan(index: int) -> bool:
	if index < 0 or index >= plans.size(): return false
	selected_plan = index
	_render()
	return true

func launch_selected_stage() -> bool:
	if plans.is_empty(): return false
	launch_stage_requested.emit(plans[selected_plan])
	return true

func launch_selected_segment(node_index := 0) -> bool:
	if plans.is_empty() or node_index < 0 or node_index >= plans[selected_plan].nodes.size(): return false
	var node := plans[selected_plan].nodes[node_index]
	launch_segment_requested.emit(StringName(node.segment_id), int(node.seed))
	return true

func _build_ui() -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	add_child(panel)
	var title := Label.new(); title.text = "STAGE GENERATION PREVIEW"; panel.add_child(title)
	seed_input = SpinBox.new(); seed_input.min_value = 1; seed_input.max_value = 2147483647; seed_input.value = mission.default_seed if mission != null else 20260731; panel.add_child(seed_input)
	var generate_button := Button.new(); generate_button.text = "Generate 3 Seeds"; generate_button.pressed.connect(func(): generate_previews(3)); panel.add_child(generate_button)
	output = RichTextLabel.new(); output.fit_content = true; output.custom_minimum_size = Vector2(500, 500); panel.add_child(output)
	var launch_button := Button.new(); launch_button.text = "Launch Selected Stage"; launch_button.pressed.connect(launch_selected_stage); panel.add_child(launch_button)

func _render() -> void:
	if output == null: return
	output.clear()
	for index in plans.size():
		var plan := plans[index]
		var report := StageValidator.validate(plan, mission)
		output.append_text("%s Seed %d — %d nodes — %s\n" % [">" if index == selected_plan else " ", plan.seed, plan.nodes.size(), "VALID" if report.valid else "INVALID"])
		for node in plan.nodes:
			var beat_label := String(node.get("beat_label", node.segment_id))
			var timing := ""
			if node.has("timeline_start"):
				timing = "  %05.1fs +%04.1fs" % [float(node.timeline_start), float(node.get("timeline_duration", 0.0))]
			var practice := String(node.get("practice_id", ""))
			var pressure: Dictionary = node.get("pressure", {})
			var pressure_text := "" if pressure.is_empty() else "  cap E%d/P%d/R%d" % [int(pressure.get("enemy_cap", 0)), int(pressure.get("projectile_cap", 0)), int(pressure.get("high_attention_roles", 0))]
			output.append_text("  %s [%s]%s%s%s%s -> %s\n" % [beat_label, node.category, timing, pressure_text, "  practice " + practice if not practice.is_empty() else "", "  variant " + String(node.get("variation_id", "")) if node.has("variation_id") else "", node.next_ids])
		for warning in report.warnings: output.append_text("  WARNING: %s\n" % warning)
		for error in report.errors: output.append_text("  ERROR: %s\n" % error)
	for note in choreography_notes: output.append_text("%s\n" % note)
