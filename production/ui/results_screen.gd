class_name ResultsScreen
extends Control

signal rewards_claimed(rewards: Dictionary)
signal continue_requested
signal decision_selected(decision_id: StringName, value: Variant)

var profile: ProgressionProfile
var transaction_id: StringName
var rewards: Dictionary = {}
var title_label: Label
var reward_label: Label
var continue_button: Button
var rewards_already_claimed := false
var narrative_text := ""
var decision_choices: Array = []
var decision_buttons: Array[Button] = []

func configure(owner_profile: ProgressionProfile, mission_result: Dictionary) -> void:
	profile = owner_profile
	transaction_id = StringName(mission_result.get("transaction_id", ""))
	rewards = RewardCalculator.calculate(mission_result)

func configure_persisted(owner_profile: ProgressionProfile, completion: Dictionary, narrative := "", choices: Array = []) -> void:
	profile = owner_profile
	transaction_id = &""
	rewards = completion.get("rewards", {}).duplicate(true)
	rewards_already_claimed = bool(completion.get("claimed", false))
	narrative_text = narrative
	decision_choices = choices.duplicate(true)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := VBoxContainer.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER); add_child(panel)
	title_label = Label.new(); title_label.text = "MISSION RESULTS"; panel.add_child(title_label)
	reward_label = Label.new(); reward_label.text = "%d XP   %d CREDITS" % [rewards.get("xp", 0), rewards.get("currency", 0)]; panel.add_child(reward_label)
	if not narrative_text.is_empty():
		var narrative := Label.new(); narrative.text = narrative_text; narrative.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; narrative.custom_minimum_size.x = 420; panel.add_child(narrative)
	if not decision_choices.is_empty():
		var choice_title := Label.new(); choice_title.text = "CAMPAIGN DECISION"; panel.add_child(choice_title)
		for choice in decision_choices:
			var choice_button := Button.new(); choice_button.text = String(choice.get("text", "Choose")); choice_button.pressed.connect(_select_decision.bind(choice)); panel.add_child(choice_button); decision_buttons.append(choice_button)
	continue_button = Button.new(); continue_button.text = "CONTINUE" if rewards_already_claimed else "CLAIM & CONTINUE"; continue_button.pressed.connect(_claim_and_continue); panel.add_child(continue_button)
	continue_button.disabled = not decision_choices.is_empty()

func _select_decision(choice: Dictionary) -> void:
	var decision_id := StringName(choice.get("decision_id", ""))
	if decision_id.is_empty(): return
	for button in decision_buttons: button.disabled = true
	continue_button.disabled = false
	decision_selected.emit(decision_id, choice.get("value"))

func _claim_and_continue() -> bool:
	var claimed := rewards_already_claimed or RewardCalculator.claim(profile, transaction_id, rewards)
	if claimed: rewards_claimed.emit(rewards)
	if continue_button != null: continue_button.disabled = true
	continue_requested.emit()
	return claimed
