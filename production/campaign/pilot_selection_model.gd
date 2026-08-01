class_name PilotSelectionModel
extends RefCounted

signal selection_changed(pilot_id: StringName)

var pilots: Dictionary = {}
var unlocked_ids: Array[StringName] = []
var selected_id: StringName

func configure(definitions: Array[PilotDefinition], story_flags: Dictionary, restored_unlocks: Array[StringName] = [], restored_selection: StringName = &"") -> void:
	pilots.clear(); unlocked_ids = restored_unlocks.duplicate()
	for pilot in definitions:
		pilots[pilot.stable_id] = pilot
		if _requirements_match(pilot.unlock_flags, story_flags) and pilot.stable_id not in unlocked_ids: unlocked_ids.append(pilot.stable_id)
	if restored_selection in unlocked_ids: selected_id = restored_selection
	elif not unlocked_ids.is_empty(): selected_id = unlocked_ids[0]

func select(pilot_id: StringName) -> bool:
	if pilot_id not in unlocked_ids or not pilots.has(pilot_id): return false
	selected_id = pilot_id; selection_changed.emit(pilot_id); return true

func selected_pilot() -> PilotDefinition:
	return pilots.get(selected_id)

func save_to_profile(profile: ProgressionProfile) -> void:
	if profile == null: return
	profile.unlocked_pilot_ids = unlocked_ids.duplicate(); profile.selected_pilot_id = selected_id
	var pilot := selected_pilot()
	if pilot != null: profile.narrative_selection = pilot.campaign_perspective

func _requirements_match(requirements: Dictionary, flags: Dictionary) -> bool:
	for key in requirements:
		if flags.get(key) != requirements[key]: return false
	return true
