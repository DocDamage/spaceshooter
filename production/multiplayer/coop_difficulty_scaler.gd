class_name CoopDifficultyScaler
extends RefCounted

static func profile(local_players: int, active_ai_wingmen := 0) -> Dictionary:
	var extra := maxi(0, local_players - 1)
	return {
		"local_players": maxi(1, local_players),
		"enemy_count_multiplier": 1.0 + 0.28 * extra,
		"boss_health_multiplier": 1.0 + 0.35 * extra,
		"boss_attack_additions": extra,
		"target_switch_bias": 0.35 * extra,
		"pickup_multiplier": 1.0 + 0.20 * extra,
		"arena_margin": 18.0 * extra,
		"revive_pressure_multiplier": 1.0 + 0.15 * extra,
		"wingman_effectiveness": 1.0 / maxf(1.0, float(local_players + active_ai_wingmen) * 0.72)
	}

static func remaining_wingman_slots(mission_capacity: int, human_players: int) -> int:
	return maxi(0, mission_capacity - maxi(1, human_players))
