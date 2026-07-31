class_name ExperienceCurve
extends RefCounted

const MAX_LEVEL := 99

static func xp_to_next(level: int) -> int:
	if level >= MAX_LEVEL: return 0
	var value := 100.0 * pow(float(level), 1.42) + 35.0 * float(level - 1)
	return maxi(100, int(round(value / 10.0)) * 10)

static func total_xp_for_level(level: int) -> int:
	var total := 0
	for current in range(1, clampi(level, 1, MAX_LEVEL)):
		total += xp_to_next(current)
	return total

static func level_table() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for level in range(1, MAX_LEVEL + 1):
		rows.append({"level": level, "total_xp": total_xp_for_level(level), "xp_to_next": xp_to_next(level)})
	return rows

static func expected_level_for_stage(stage: int) -> Vector2i:
	var low := clampi(1 + int(floor(float(maxi(0, stage - 1)) * 1.5)), 1, MAX_LEVEL)
	return Vector2i(low, mini(MAX_LEVEL, low + 3))

static func campaign_completion_range() -> Vector2i:
	return Vector2i(42, 50)

static func export_csv(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_line("level,total_xp,xp_to_next,expected_stage")
	for row in level_table():
		var expected_stage := maxi(1, int(ceil(float(int(row.level) - 1) / 1.5)) + 1)
		file.store_csv_line(PackedStringArray([str(row.level), str(row.total_xp), str(row.xp_to_next), str(expected_stage)]))
	return OK
