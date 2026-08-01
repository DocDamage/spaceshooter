class_name OnlineRolloutPolicy
extends RefCounted

const ROLLOUT_ORDER: Array[StringName] = [&"boss_practice", &"arcade", &"campaign_stage", &"operation_1", &"full_campaign"]

var validated_tiers: Array[StringName] = []

func mark_validated(tier: StringName) -> bool:
	var index := ROLLOUT_ORDER.find(tier)
	if index < 0 or index != validated_tiers.size(): return false
	validated_tiers.append(tier)
	return true

func is_available(tier: StringName) -> bool:
	var index := ROLLOUT_ORDER.find(tier)
	return index >= 0 and index < validated_tiers.size()

func next_tier() -> StringName:
	return ROLLOUT_ORDER[validated_tiers.size()] if validated_tiers.size() < ROLLOUT_ORDER.size() else &"complete"
