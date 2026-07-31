class_name MissionHUD
extends CanvasLayer

var session: GameSession
var players: Array[Node2D] = []
var score_tracker: MissionScoreTracker
var stage_runtime: StageRuntime
var score_label: Label
var objective_label: Label
var status_label: Label
var branch_panel: PanelContainer
var branch_box: VBoxContainer

func configure(game_session: GameSession, player_nodes: Array[Node2D], tracker: MissionScoreTracker) -> void:
	session = game_session
	players.assign(player_nodes)
	score_tracker = tracker
	layer = 30

func _ready() -> void:
	var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	var top := MarginContainer.new(); top.set_anchors_preset(Control.PRESET_TOP_WIDE); top.offset_left = 18; top.offset_right = -18; top.offset_top = 14; top.offset_bottom = 90; root.add_child(top)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 18); top.add_child(row)
	score_label = Label.new(); score_label.text = "SCORE 000000  CHAIN x0"; score_label.add_theme_font_size_override("font_size", 18); row.add_child(score_label)
	objective_label = Label.new(); objective_label.text = "OBJECTIVE  ADVANCE"; objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; row.add_child(objective_label)
	status_label = Label.new(); status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; row.add_child(status_label)
	branch_panel = PanelContainer.new(); branch_panel.visible = false; branch_panel.set_anchors_preset(Control.PRESET_CENTER); branch_panel.position = Vector2(-190, -170); branch_panel.size = Vector2(380, 340); branch_panel.mouse_filter = Control.MOUSE_FILTER_STOP; root.add_child(branch_panel)
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 24); margin.add_theme_constant_override("margin_right", 24); margin.add_theme_constant_override("margin_top", 22); margin.add_theme_constant_override("margin_bottom", 22); branch_panel.add_child(margin)
	branch_box = VBoxContainer.new(); branch_box.add_theme_constant_override("separation", 12); margin.add_child(branch_box)
	if score_tracker != null: score_tracker.score_changed.connect(_on_score_changed)

func bind_stage(runtime: StageRuntime) -> void:
	stage_runtime = runtime
	stage_runtime.segment_changed.connect(_on_segment_changed)
	stage_runtime.objective_resolved.connect(_on_objective_resolved)
	stage_runtime.branch_choice_requested.connect(_on_branch_choice_requested)

func _process(_delta: float) -> void:
	var fragments: PackedStringArray = []
	for index in players.size():
		var player := players[index] as ProductionPlayer
		if not is_instance_valid(player): continue
		var energy := int(player.weapon_runtime.energy) if player.weapon_runtime != null else 0
		var super_charge := int(player.super_runtime.charge) if player.super_runtime != null else 0
		fragments.append("P%d HP %d SH %d EN %d OV %d" % [index + 1, int(player.health_component.current), int(player.shield_component.current), energy, super_charge])
	status_label.text = "  ".join(fragments)

func _on_score_changed(value: int, chain: int, multiplier: float) -> void:
	score_label.text = "SCORE %06d  CHAIN x%d  %.2f×" % [value, chain, multiplier]

func _on_segment_changed(_node_id: StringName, _segment_id: StringName) -> void:
	if stage_runtime != null and stage_runtime.current_segment != null:
		objective_label.text = stage_runtime.current_segment.definition.display_name.to_upper()
	if branch_panel != null: branch_panel.visible = false

func _on_objective_resolved(objective_id: StringName, succeeded: bool, _reward: Dictionary, _dialogue_hook: StringName) -> void:
	objective_label.text = "%s  %s" % [String(objective_id).get_slice("@", 0).trim_prefix("objective.").replace("_", " ").to_upper(), "COMPLETE" if succeeded else "FAILED"]

func _on_branch_choice_requested(_node_id: StringName, choices: Array[StringName]) -> void:
	for child in branch_box.get_children(): child.queue_free()
	var title := Label.new(); title.text = "CHOOSE ROUTE"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 24); branch_box.add_child(title)
	var first_button: Button
	for index in choices.size():
		var choice := choices[index]
		var button := Button.new()
		var definition := stage_runtime.plan.definition_for(choice) if stage_runtime != null else null
		button.text = "%d. %s" % [index + 1, definition.display_name if definition != null else String(choice)]
		button.custom_minimum_size.y = 52
		button.pressed.connect(_choose_branch.bind(choice))
		branch_box.add_child(button)
		if first_button == null: first_button = button
	branch_panel.visible = true
	if first_button != null: first_button.call_deferred("grab_focus")

func _choose_branch(choice: StringName) -> void:
	if stage_runtime != null and stage_runtime.choose_branch(choice): branch_panel.visible = false
