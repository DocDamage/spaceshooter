class_name BossHUD
extends CanvasLayer

var boss_name := ""
var health := 0.0
var maximum_health := 1.0
var shield := 0.0
var maximum_shield := 0.0
var armor := 0.0
var phase_index := 0
var phase_count := 1
var phase_divisions: PackedFloat32Array = []
var part_states: Dictionary = {}
var enrage_remaining := -1.0
var active_statuses: Array[StringName] = []
var challenge_states: Dictionary = {}
var compact := false
var name_label: Label
var phase_label: Label
var health_bar: ProgressBar
var shield_bar: ProgressBar
var detail_label: Label

func _ready() -> void:
	_build_interface()

func _build_interface() -> void:
	if name_label != null: return
	layer = 40
	var panel := MarginContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 48.0; panel.offset_top = 18.0; panel.offset_right = -48.0; panel.offset_bottom = 150.0
	var box := VBoxContainer.new(); panel.add_child(box)
	var heading := HBoxContainer.new(); box.add_child(heading)
	name_label = Label.new(); name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; heading.add_child(name_label)
	phase_label = Label.new(); heading.add_child(phase_label)
	health_bar = ProgressBar.new(); health_bar.show_percentage = false; health_bar.custom_minimum_size.y = 18.0; box.add_child(health_bar)
	shield_bar = ProgressBar.new(); shield_bar.show_percentage = false; shield_bar.custom_minimum_size.y = 8.0; box.add_child(shield_bar)
	detail_label = Label.new(); detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; box.add_child(detail_label)
	add_child(panel)

func bind_boss(boss: BossActor) -> void:
	if boss == null: return
	boss_name = boss.definition.display_name
	compact = boss.definition.is_miniboss
	maximum_health = boss.health_component.maximum
	health = boss.health_component.current
	maximum_shield = boss.shield_component.capacity
	shield = boss.shield_component.current
	armor = boss.armor_component.armor
	phase_count = boss.definition.phases.size()
	phase_divisions.clear()
	for phase in boss.definition.phases: phase_divisions.append(phase.health_threshold)
	refresh(boss)

func refresh(boss: BossActor) -> void:
	if boss == null: return
	health = boss.health_component.current
	shield = boss.shield_component.current
	phase_index = boss.phase_machine.current_index
	active_statuses = boss.status_component.active_ids()
	part_states.clear()
	for part_id in boss.parts: part_states[part_id] = boss.parts[part_id].snapshot()
	challenge_states = boss.challenge_tracker.complete_results()
	var phase := boss.phase_machine.current_phase()
	enrage_remaining = maxf(0.0, phase.enrage_after - boss.phase_machine.elapsed) if phase != null and phase.enrage_after > 0.0 and not boss.phase_machine.is_enraged else -1.0
	_refresh_interface()

func _refresh_interface() -> void:
	if name_label == null: _build_interface()
	name_label.text = boss_name
	phase_label.text = "MINIBOSS" if compact else "PHASE %d/%d" % [phase_index + 1, phase_count]
	health_bar.max_value = maximum_health; health_bar.value = health
	shield_bar.visible = maximum_shield > 0.0; shield_bar.max_value = maxf(1.0, maximum_shield); shield_bar.value = shield
	var intact := 0
	for state in part_states.values():
		if bool(state.active): intact += 1
	var details: Array[String] = ["ARMOR %.0f" % armor, "PARTS %d/%d" % [intact, part_states.size()]]
	if enrage_remaining >= 0.0: details.append("ENRAGE %.1fs" % enrage_remaining)
	detail_label.text = "  •  ".join(details)

func view_model() -> Dictionary:
	return {"name": boss_name, "health_ratio": health / maxf(1.0, maximum_health), "shield_ratio": shield / maxf(1.0, maximum_shield) if maximum_shield > 0.0 else 0.0, "armor": armor, "phase": phase_index, "phase_count": phase_count, "phase_divisions": phase_divisions, "parts": part_states.duplicate(true), "enrage_remaining": enrage_remaining, "statuses": active_statuses.duplicate(), "challenges": challenge_states.duplicate(true), "compact": compact}
