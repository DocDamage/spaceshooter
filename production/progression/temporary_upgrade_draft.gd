class_name TemporaryUpgradeDraft
extends RefCounted

var definitions: Dictionary = {}
var active_upgrade_ids: Array[StringName] = []
var stage_seed := 0

func _init(upgrades: Array[TemporaryUpgradeDefinition] = [], seed := 0) -> void:
	stage_seed = seed
	for upgrade in upgrades:
		if upgrade != null: definitions[upgrade.stable_id] = upgrade

func offer(count: int, build_tags: Array[StringName] = [], safe_transition := false) -> Array[Dictionary]:
	if not safe_transition or count <= 0: return []
	var candidates: Array[TemporaryUpgradeDefinition] = []
	for upgrade in definitions.values():
		if _compatible(upgrade, build_tags): candidates.append(upgrade)
	candidates.sort_custom(func(a: TemporaryUpgradeDefinition, b: TemporaryUpgradeDefinition): return String(a.stable_id) < String(b.stable_id))
	var rng := RandomNumberGenerator.new(); rng.seed = stage_seed + active_upgrade_ids.size() * 7919
	var offers: Array[Dictionary] = []
	while not candidates.is_empty() and offers.size() < count:
		var index: int = rng.randi_range(0, candidates.size() - 1); var chosen: TemporaryUpgradeDefinition = candidates.pop_at(index)
		offers.append({"id": chosen.stable_id, "name": chosen.display_name, "rarity": chosen.rarity, "synergy": chosen.synergy_hint, "modifiers": chosen.modifiers.duplicate(true)})
	return offers

func select(upgrade_id: StringName, build_tags: Array[StringName] = []) -> bool:
	var upgrade: TemporaryUpgradeDefinition = definitions.get(upgrade_id)
	if upgrade == null or not _compatible(upgrade, build_tags): return false
	active_upgrade_ids.append(upgrade_id)
	return true

func modifiers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for upgrade_id in active_upgrade_ids:
		var upgrade: TemporaryUpgradeDefinition = definitions.get(upgrade_id)
		if upgrade != null: result.append(upgrade.modifiers)
	return result

func checkpoint_snapshot() -> Dictionary:
	return {"seed": stage_seed, "active_upgrade_ids": active_upgrade_ids.duplicate()}

func restore_checkpoint(snapshot: Dictionary) -> bool:
	var restored: Array[StringName] = []; restored.assign(snapshot.get("active_upgrade_ids", []))
	for upgrade_id in restored:
		if not definitions.has(upgrade_id): return false
	stage_seed = int(snapshot.get("seed", stage_seed)); active_upgrade_ids = restored
	return true

func reset_after_mission() -> void:
	active_upgrade_ids.clear()

func _compatible(upgrade: TemporaryUpgradeDefinition, build_tags: Array[StringName]) -> bool:
	for tag in upgrade.incompatible_tags:
		if tag in build_tags: return false
	return true
