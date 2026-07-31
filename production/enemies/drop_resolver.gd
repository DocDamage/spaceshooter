class_name DropResolver
extends RefCounted

static var _misses: Dictionary = {}

static func resolve(table: DropTableDefinition, seed_value: int, difficulty_multiplier := 1.0, owner_ids: Array[StringName] = [], source_player_id: StringName = &"") -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	if table == null: return drops
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for entry in table.guaranteed_entries: drops.append(_owned(entry, table, owner_ids, source_player_id, drops.size()))
	var total := 0.0
	for entry in table.weighted_entries: total += maxf(0.0, float(entry.get("weight", 0.0)))
	var hit := false
	for roll in table.rolls:
		if total <= 0.0: break
		var pick := rng.randf_range(0.0, total / maxf(0.01, difficulty_multiplier + table.difficulty_multiplier))
		for entry in table.weighted_entries:
			pick -= maxf(0.0, float(entry.get("weight", 0.0)))
			if pick <= 0.0:
				drops.append(_owned(entry, table, owner_ids, source_player_id, drops.size()))
				hit = true
				break
	var misses := int(_misses.get(table.stable_id, 0))
	if not hit: misses += 1
	else: misses = 0
	if table.pity_after_misses > 0 and misses >= table.pity_after_misses and not table.weighted_entries.is_empty():
		drops.append(_owned(table.weighted_entries[0], table, owner_ids, source_player_id, drops.size()))
		misses = 0
	_misses[table.stable_id] = misses
	return drops

static func _owned(entry: Dictionary, table: DropTableDefinition, owners: Array[StringName], source: StringName, index: int) -> Dictionary:
	var drop := entry.duplicate(true)
	if table.ownership == &"shared": drop.owner_id = &"shared"
	elif table.ownership == &"round_robin" and not owners.is_empty(): drop.owner_id = owners[index % owners.size()]
	else: drop.owner_id = source
	return drop
