class_name SaveRecoveryPanel
extends VBoxContainer

signal dismissed

var save_service: SaveService
var report: Dictionary

func configure(service: SaveService, recovery_report: Dictionary) -> void:
	save_service = service
	report = recovery_report.duplicate(true)

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var title := Label.new(); title.text = "SAVE RECOVERY"; title.add_theme_font_size_override("font_size", 24); add_child(title)
	var message := Label.new(); message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.text = String(report.get("message", "Save data could not be loaded. Your files have not been reset or deleted.")); add_child(message)
	for attempt in report.get("attempts", []):
		var row := Label.new(); row.text = "%s — %s" % [String(attempt.get("path", "unknown")), String(attempt.get("message", "invalid"))]; row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(row)
	var export := UIComponentLibrary.primary_button("Export Diagnostics")
	export.pressed.connect(func():
		var error := save_service.export_diagnostics()
		export.text = "Diagnostics exported" if error == OK else "Export failed (%d)" % error)
	add_child(export)
	var close := UIComponentLibrary.secondary_button("Continue Without Resetting")
	close.pressed.connect(func(): dismissed.emit())
	add_child(close)
