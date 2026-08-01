class_name ModeRunController
extends RefCounted

var definition: ModeDefinition
var run_id: StringName
var seed := 0
var score := 0
var lives := 0
var continues_used := 0
var elapsed_seconds := 0.0
var penalty_seconds := 0.0
var chain := 0
var score_breakdown: Dictionary = {}
var active_assists: Array[StringName] = []
var effective_difficulty := 50
var completed := false

func start(mode: ModeDefinition, requested_seed: int, difficulty: int, assists: Array[StringName] = []) -> bool:
	if mode == null or not mode.validate().is_empty(): return false
	definition = mode; seed = requested_seed if requested_seed != 0 else randi()
	effective_difficulty = clampi(difficulty, 0, 100); active_assists = assists.duplicate()
	lives = definition.starting_lives
	run_id = StringName("mode.%s.%d.%d" % [definition.mode_id, Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	return true

func advance(delta: float) -> void:
	if not completed: elapsed_seconds += maxf(0.0, delta)

func add_score(category: StringName, amount: int, chain_delta := 0) -> void:
	if completed or definition == null or not definition.score_enabled: return
	chain = maxi(0, chain + chain_delta)
	var awarded := maxi(0, amount) * maxi(1, chain)
	score += awarded; score_breakdown[category] = int(score_breakdown.get(category, 0)) + awarded
	var threshold := int(definition.rules.get("earned_continue_score", 0))
	if threshold > 0 and score / threshold > (score - awarded) / threshold: lives += 1

func register_defeat() -> StringName:
	if lives > 0: lives -= 1
	penalty_seconds += float(definition.rules.get("death_penalty_seconds", 0.0))
	if lives > 0: return &"respawn"
	if definition.continue_limit < 0 or continues_used < definition.continue_limit:
		continues_used += 1; lives = maxi(1, definition.starting_lives); chain = 0
		return &"continue"
	completed = true
	return &"game_over"

func finish(success: bool, leaderboard: LocalLeaderboard = null) -> Dictionary:
	completed = true
	var result := {"run_id": run_id, "mode_id": definition.mode_id, "success": success, "seed": seed, "score": score, "score_breakdown": score_breakdown.duplicate(true), "elapsed_seconds": elapsed_seconds + penalty_seconds, "penalty_seconds": penalty_seconds, "effective_difficulty": effective_difficulty, "active_assists": active_assists.duplicate(), "leaderboard_eligible": definition.leaderboard_eligible, "campaign_mutations": {}, "rewards_enabled": definition.rewards_enabled}
	if leaderboard != null and definition.leaderboard_eligible: leaderboard.submit(definition.mode_id, result)
	return result

func survival_scaling(wave: int, segment: int) -> Dictionary:
	if definition == null or definition.mode_id not in [&"survival", &"endless"]: return {}
	var raw := 1.0 + maxi(0, wave - 1) * float(definition.rules.wave_scaling) + maxi(0, segment) * float(definition.rules.segment_scaling)
	var cap := float(definition.rules.difficulty_cap)
	return {"difficulty_multiplier": minf(raw, cap), "active_enemy_cap": int(definition.rules.maximum_active_enemies), "active_projectile_cap": int(definition.rules.maximum_active_projectiles)}
