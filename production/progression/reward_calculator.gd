class_name RewardCalculator
extends RefCounted

const FAILURE_REWARD_RATE := 0.30
const REPLAY_REWARD_RATE := 0.70

static func calculate(result: Dictionary) -> Dictionary:
	var completed := bool(result.get("completed", result.get("success", false)))
	var base_xp := maxi(0, int(result.get("base_xp", 0))); var base_currency := maxi(0, int(result.get("base_currency", 0)))
	var multiplier := float(result.get("difficulty_multiplier", 1.0))
	multiplier += float(result.get("objectives_completed", 0)) * 0.05
	multiplier += minf(0.35, float(result.get("max_chain", 0)) * 0.005)
	multiplier += minf(0.25, float(result.get("score", 0)) / 1000000.0)
	multiplier += 0.10 if int(result.get("damage_taken", 1)) == 0 else 0.0
	multiplier -= minf(0.50, float(result.get("continues_used", 0)) * 0.10)
	multiplier += 0.15 if bool(result.get("boss_challenge", false)) else 0.0
	multiplier += 0.15 if bool(result.get("secret_route", false)) else 0.0
	if not completed: multiplier *= FAILURE_REWARD_RATE
	if bool(result.get("replay", false)): multiplier *= REPLAY_REWARD_RATE
	multiplier = maxf(0.0, multiplier)
	return {"xp": int(round(base_xp * multiplier)), "currency": int(round(base_currency * multiplier)), "multiplier": multiplier}

static func claim(profile: ProgressionProfile, transaction_id: StringName, rewards: Dictionary) -> bool:
	if profile == null or transaction_id.is_empty() or transaction_id in profile.claimed_reward_ids: return false
	var xp := maxi(0, int(rewards.get("xp", 0))); var credits := maxi(0, int(rewards.get("currency", 0)))
	profile.add_experience(xp); profile.currency += credits; profile.claimed_reward_ids.append(transaction_id)
	return true
