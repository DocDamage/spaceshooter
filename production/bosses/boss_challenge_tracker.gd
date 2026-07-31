class_name BossChallengeTracker
extends RefCounted

signal challenge_changed(challenge_id: StringName, passed: bool, progress: float)

var definitions: Array[BossChallengeDefinition] = []
var states: Dictionary = {}
var practice_mode := false
var elapsed := 0.0

func configure(challenges: Array[BossChallengeDefinition], is_practice := false) -> void:
	definitions = challenges.duplicate()
	practice_mode = is_practice
	elapsed = 0.0
	states.clear()
	for challenge in definitions:
		if challenge != null:
			var starts_passed := challenge.challenge_type not in [BossChallengeDefinition.ChallengeType.CHAIN_THRESHOLD, BossChallengeDefinition.ChallengeType.DESTROY_ALL_PARTS, BossChallengeDefinition.ChallengeType.REFLECT_FINAL_ATTACK, BossChallengeDefinition.ChallengeType.SECRET_MECHANIC]
			states[challenge.stable_id] = {"passed": starts_passed, "progress": 0.0}

func tick(delta: float) -> void:
	elapsed += maxf(0.0, delta)
	for challenge in definitions:
		if challenge != null and challenge.challenge_type == BossChallengeDefinition.ChallengeType.TIME_LIMIT:
			_update_state(challenge, elapsed <= challenge.target_value, minf(1.0, elapsed / maxf(0.001, challenge.target_value)))

func record(event_type: StringName, value: Variant = true) -> void:
	for challenge in definitions:
		if challenge == null: continue
		match challenge.challenge_type:
			BossChallengeDefinition.ChallengeType.NO_DAMAGE:
				if event_type == &"player_damaged": _update_state(challenge, false, 1.0)
			BossChallengeDefinition.ChallengeType.CHAIN_THRESHOLD:
				if event_type == &"chain":
					var progress := minf(1.0, float(value) / challenge.target_value)
					_update_state(challenge, progress >= 1.0, progress)
			BossChallengeDefinition.ChallengeType.DESTROY_ALL_PARTS:
				if event_type == &"parts_progress": _update_state(challenge, bool(value >= 1.0), float(value))
			BossChallengeDefinition.ChallengeType.PRESERVE_TARGET:
				if event_type == &"target_destroyed": _update_state(challenge, false, 1.0)
			BossChallengeDefinition.ChallengeType.RESTRICTED_WEAPON:
				if event_type == &"weapon_used" and StringName(value) not in challenge.allowed_weapon_ids: _update_state(challenge, false, 1.0)
			BossChallengeDefinition.ChallengeType.REFLECT_FINAL_ATTACK:
				if event_type == &"final_attack_reflected": _update_state(challenge, bool(value), 1.0)
			BossChallengeDefinition.ChallengeType.NO_SPELL:
				if event_type == &"spell_used": _update_state(challenge, false, 1.0)
			BossChallengeDefinition.ChallengeType.NO_CONTINUE:
				if event_type == &"continue_used": _update_state(challenge, false, 1.0)
			BossChallengeDefinition.ChallengeType.SECRET_MECHANIC:
				if event_type == &"secret" and StringName(value) == challenge.required_tag: _update_state(challenge, true, 1.0)

func complete_results() -> Dictionary:
	var result := {}
	for challenge in definitions:
		if challenge == null: continue
		var state: Dictionary = states[challenge.stable_id]
		var passed := bool(state.passed)
		if challenge.challenge_type == BossChallengeDefinition.ChallengeType.CHAIN_THRESHOLD: passed = float(state.progress) >= 1.0
		if challenge.challenge_type == BossChallengeDefinition.ChallengeType.DESTROY_ALL_PARTS: passed = float(state.progress) >= 1.0
		result[challenge.stable_id] = {"passed": passed, "progress": state.progress, "rewards_enabled": not practice_mode}
	return result

func _update_state(challenge: BossChallengeDefinition, passed: bool, progress: float) -> void:
	var old: Dictionary = states[challenge.stable_id]
	old.passed = bool(old.passed) and passed
	if challenge.challenge_type in [BossChallengeDefinition.ChallengeType.CHAIN_THRESHOLD, BossChallengeDefinition.ChallengeType.DESTROY_ALL_PARTS, BossChallengeDefinition.ChallengeType.REFLECT_FINAL_ATTACK, BossChallengeDefinition.ChallengeType.SECRET_MECHANIC]: old.passed = passed
	old.progress = maxf(float(old.progress), clampf(progress, 0.0, 1.0))
	states[challenge.stable_id] = old
	challenge_changed.emit(challenge.stable_id, old.passed, old.progress)
