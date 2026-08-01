class_name BossPracticeSession
extends RefCounted

var boss_id: StringName
var starting_phase := 0
var difficulty_rating := 50
var loadout: Dictionary = {}
var rewards_enabled := false
var campaign_completion_enabled := false
var clearly_marked_practice := true
var local_players := 1
var participants: Array[Dictionary] = []

func configure(id: StringName, phase: int, difficulty: int, selected_loadout: Dictionary, phase_count: int) -> bool:
	if id.is_empty() or phase_count <= 0: return false
	boss_id = id
	starting_phase = clampi(phase, 0, phase_count - 1)
	difficulty_rating = clampi(difficulty, 0, 100)
	loadout = selected_loadout.duplicate(true)
	return true

func result_policy() -> Dictionary:
	return {"practice": true, "grant_rewards": rewards_enabled, "complete_campaign": campaign_completion_enabled}

func configure_local_coop(roster: LocalCoopRoster) -> bool:
	if roster == null or roster.participants.size() != 2: return false
	local_players = 2
	participants = roster.participants.duplicate(true)
	return true
