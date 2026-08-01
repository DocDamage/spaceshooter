class_name CoopRewardDistributor
extends RefCounted

var item_owner_cursor := 0

func distribute(transaction_id: StringName, rewards: Dictionary, roster: LocalCoopRoster, profiles: Dictionary) -> Dictionary:
	var result := {"claimed_profiles": [], "guest_summary": {}, "item_owners": {}, "duplicate_salvage": 0}
	if transaction_id.is_empty() or roster == null: return result
	var persistent := roster.persistent_profile_ids()
	for participant in roster.participants:
		var profile_id := StringName(participant.profile_id)
		if bool(participant.guest):
			result.guest_summary[profile_id] = {"xp": int(rewards.get("xp", 0)), "currency": int(rewards.get("currency", 0)), "persistent": false}
			continue
		var profile: ProgressionProfile = profiles.get(profile_id)
		var per_profile_id := StringName("%s.%s" % [transaction_id, profile_id])
		if profile != null and RewardCalculator.claim(profile, per_profile_id, rewards): result.claimed_profiles.append(profile_id)
	var items: Array = rewards.get("items", [])
	for raw_item_id in items:
		if persistent.is_empty(): break
		var item_id := StringName(raw_item_id)
		var owner_id := persistent[item_owner_cursor % persistent.size()]
		item_owner_cursor += 1
		var owner: ProgressionProfile = profiles.get(owner_id)
		var duplicate := owner != null and owner.inventory.any(func(entry): return StringName(entry.get("definition_id", "")) == item_id)
		if duplicate:
			owner.currency += 100
			result.duplicate_salvage += 100
		else:
			result.item_owners[item_id] = owner_id
	return result
