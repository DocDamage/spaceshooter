extends SceneTree

const MANIFEST_PATH := "res://tools/asset_catalog/generated/manifest.json"
const EXPECTED_TEMPLATES := [
	"enemy_definition.template.tres",
	"ship_definition.template.tres",
	"projectile_definition.template.tres",
	"background_layer_definition.template.tres",
	"portrait_definition.template.tres",
	"ui_theme_asset_definition.template.tres",
	"effect_definition.template.tres",
]

var failures := PackedStringArray()
var passed_count := 0

func _init() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)

func _run() -> void:
	await process_frame
	_test_catalog()
	_test_templates()
	_test_definition_types()
	_test_export_exclusions()
	if failures.is_empty():
		print("PHASE 3 ACCEPTANCE: all %d checks passed" % passed_count)
		quit(0)
	else:
		print("PHASE 3 ACCEPTANCE: %d check(s) failed" % failures.size())
		quit(1)

func _test_catalog() -> void:
	_assert(FileAccess.file_exists(MANIFEST_PATH), "machine-readable asset manifest exists")
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	var manifest = JSON.parse_string(file.get_as_text()) if file != null else null
	_assert(manifest is Dictionary, "asset manifest parses as JSON")
	if not manifest is Dictionary:
		return
	var assets: Array = manifest.get("assets", [])
	_assert(assets.size() >= 4500, "full supplied archive is inventoried")
	var ids := {}
	var unique_ids := true
	var approved_count := 0
	var approved_are_licensed := true
	var approved_files_exist := true
	var searchable_pirate_enemy := false
	var animated_record := false
	for asset in assets:
		var stable_id: String = asset.get("stable_id", "")
		if stable_id.is_empty() or ids.has(stable_id):
			unique_ids = false
		ids[stable_id] = true
		if asset.get("import_status") == "approved":
			approved_count += 1
			approved_are_licensed = approved_are_licensed and asset.get("commercial_use", false)
			var runtime_path: String = asset.get("runtime_path", "")
			approved_files_exist = approved_files_exist and runtime_path.begins_with("res://assets_runtime/") and FileAccess.file_exists(runtime_path)
		if asset.get("faction") == "pirate" and asset.get("intended_role") == "enemy":
			searchable_pirate_enemy = true
		if asset.get("animation") is Dictionary:
			var animation: Dictionary = asset.get("animation", {})
			animated_record = animation.has_all(["frame_width", "frame_height", "frame_count", "rows", "columns", "fps", "loop", "event_frames", "damage_flash_compatible", "destruction_sequence"])
	_assert(unique_ids, "catalog stable IDs are present and unique")
	_assert(approved_count >= 7, "initial approved runtime asset set is cataloged")
	_assert(approved_are_licensed, "approved assets have verified commercial-use status")
	_assert(approved_files_exist, "approved normalized runtime copies exist")
	_assert(searchable_pirate_enemy, "assets can be found by faction and role")
	_assert(animated_record, "animation metadata format covers layout, timing, events, flash, and destruction")
	_assert(FileAccess.file_exists("res://tools/asset_catalog/generated/catalog.html"), "searchable thumbnail catalog exists")
	_assert(FileAccess.file_exists("res://tools/asset_catalog/generated/atlas_candidates.json"), "atlas candidates are generated")

func _test_templates() -> void:
	for template in EXPECTED_TEMPLATES:
		_assert(FileAccess.file_exists("res://tools/content_templates/" + template), "content template exists: %s" % template)

func _test_definition_types() -> void:
	var projectile := ProjectileDefinition.new()
	projectile.stable_id = &"projectile.acceptance"
	_assert(projectile.validate_definition().is_empty(), "projectile content definition validates")
	var effect := EffectDefinition.new()
	effect.stable_id = &"effect.acceptance"
	_assert(effect.validate_definition().is_empty(), "effect content definition validates")

func _test_export_exclusions() -> void:
	var file := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	var text := file.get_as_text() if file != null else ""
	for extension in ["psd", "eps", "scml", "ai", "aseprite"]:
		_assert("**/*.%s" % extension in text, "export excludes source format: %s" % extension)
