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

func configure(mission_definition: MissionDefinition) -> void:
	mission = mission_definition

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
			output.append_text("  %s [%s] waves/objectives %d, projectile budget %d -> %s\n" % [node.segment_id, node.category, node.objective_ids.size(), node.estimated_projectiles, node.next_ids])
		for warning in report.warnings: output.append_text("  WARNING: %s\n" % warning)
		for error in report.errors: output.append_text("  ERROR: %s\n" % error)
