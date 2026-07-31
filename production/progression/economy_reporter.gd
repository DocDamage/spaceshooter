class_name EconomyReporter
extends RefCounted

static func simulate(stage_count := 30) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for stage in range(1, stage_count + 1):
		var level_range := ExperienceCurve.expected_level_for_stage(stage)
		var xp := 400 + stage * 120; var credits := 250 + stage * 75
		rows.append({"stage": stage, "level_low": level_range.x, "level_high": level_range.y, "expected_xp": xp,
			"expected_currency": credits, "failure_xp": int(xp * RewardCalculator.FAILURE_REWARD_RATE),
			"replay_xp": int(xp * RewardCalculator.REPLAY_REWARD_RATE), "upgrade_cost": 300 + stage * stage * 35,
			"equipment_chance": minf(0.75, 0.18 + stage * 0.012), "boss_rare_chance": minf(0.50, 0.05 + stage * 0.01),
			"new_game_plus_multiplier": 1.0 + float(stage_count + stage) * 0.025})
	return rows

static func export_csv(path: String, stage_count := 30) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	var columns := PackedStringArray(["stage", "level_low", "level_high", "expected_xp", "expected_currency", "failure_xp", "replay_xp", "upgrade_cost", "equipment_chance", "boss_rare_chance", "new_game_plus_multiplier"])
	file.store_csv_line(columns)
	for row in simulate(stage_count):
		var values := PackedStringArray()
		for column in columns:
			values.append(str(row[column]))
		file.store_csv_line(values)
	return OK
