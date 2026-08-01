extends SceneTree

func _init() -> void:
	var level_error := ExperienceCurve.export_csv("res://docs/phase8_level_curve.csv")
	var economy_error := EconomyReporter.export_csv("res://docs/phase8_economy_report.csv", 30)
	if level_error != OK or economy_error != OK:
		push_error("Phase 8 report export failed: level=%s economy=%s" % [level_error, economy_error])
		quit(1)
	else:
		print("Exported Phase 8 level and economy balance reports")
		quit(0)
