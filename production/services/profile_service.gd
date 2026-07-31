class_name ProfileService
extends BaseGameService

signal profiles_changed
signal profile_selected(profile_ids: Array[StringName])

const MAX_PROFILES := 12

var selected_profile_ids: Array[StringName] = []
var progression_profiles: Dictionary = {}
var save_service: SaveService
var content_database: ContentDatabase

func _init() -> void:
	service_id = &"profiles"

func initialize(context: Dictionary = {}) -> bool:
	var hub: ServiceHub = context.get("hub")
	if hub != null:
		save_service = hub.saves
		content_database = hub.content_database
	var index_path := "%s/profiles.json" % save_service.storage_root if save_service != null else ""
	var had_index := not index_path.is_empty() and (FileAccess.file_exists(index_path) or FileAccess.file_exists("%s.previous" % index_path) or FileAccess.file_exists("%s.recovery" % index_path))
	load_index()
	# A first launch gets a default pilot. Existing but unreadable data remains untouched
	# and is surfaced through SaveService's recovery report instead.
	if progression_profiles.is_empty() and not had_index:
		create_profile("Pilot 1", &"profile.local_1")
	if save_service != null and save_service.status in [&"saved", &"loaded"]:
		save_service.status = &"idle"
	is_initialized = true
	return true

func create_profile(display_name: String, requested_id: StringName = &"") -> ProgressionProfile:
	if progression_profiles.size() >= MAX_PROFILES:
		return null
	var profile_id := requested_id if not requested_id.is_empty() else _next_profile_id()
	if progression_profiles.has(profile_id):
		return null
	var profile := ProgressionProfile.new()
	profile.profile_id = profile_id
	profile.display_name = _clean_name(display_name)
	progression_profiles[profile_id] = profile
	if selected_profile_ids.is_empty():
		selected_profile_ids.append(profile_id)
	persist_profile(profile_id)
	profiles_changed.emit()
	return profile

func rename_profile(profile_id: StringName, display_name: String) -> bool:
	var profile := get_progression_profile(profile_id, false)
	if profile == null:
		return false
	profile.display_name = _clean_name(display_name)
	persist_profile(profile_id)
	profiles_changed.emit()
	return true

func duplicate_profile(profile_id: StringName, display_name := "") -> ProgressionProfile:
	var source := get_progression_profile(profile_id, false)
	if source == null or progression_profiles.size() >= MAX_PROFILES:
		return null
	var copy := ProgressionProfile.from_snapshot(source.to_snapshot())
	copy.profile_id = _next_profile_id()
	copy.display_name = _clean_name(display_name if not display_name.is_empty() else "%s Copy" % source.display_name)
	progression_profiles[copy.profile_id] = copy
	persist_profile(copy.profile_id)
	profiles_changed.emit()
	return copy

func delete_profile(profile_id: StringName) -> bool:
	if not progression_profiles.has(profile_id):
		return false
	progression_profiles.erase(profile_id)
	selected_profile_ids.erase(profile_id)
	if save_service != null:
		var directory := save_service.profile_path(profile_id).get_base_dir()
		for filename in ["profile.json", "profile.json.previous", "profile.json.recovery", "checkpoint.json", "checkpoint.json.previous", "checkpoint.json.recovery"]:
			var path := "%s/%s" % [directory, filename]
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if selected_profile_ids.is_empty() and not progression_profiles.is_empty():
		selected_profile_ids.append(StringName(progression_profiles.keys()[0]))
	_save_index()
	profiles_changed.emit()
	return true

func select_profiles(profile_ids: Array[StringName]) -> bool:
	for profile_id in profile_ids:
		if not progression_profiles.has(profile_id): return false
	selected_profile_ids = profile_ids.duplicate()
	_save_index()
	profile_selected.emit(selected_profile_ids)
	return true

func get_progression_profile(profile_id: StringName = &"", create_missing := true) -> ProgressionProfile:
	var resolved := profile_id
	if resolved.is_empty() and not selected_profile_ids.is_empty(): resolved = selected_profile_ids[0]
	if resolved.is_empty(): return null
	if not progression_profiles.has(resolved) and create_missing:
		return create_profile("Pilot", resolved)
	return progression_profiles.get(resolved)

func persist_profile(profile_id: StringName) -> Error:
	if save_service == null or not progression_profiles.has(profile_id): return ERR_UNCONFIGURED
	var profile: ProgressionProfile = progression_profiles[profile_id]
	var error := save_service.save_profile(profile_id, profile.to_snapshot())
	if error == OK: _save_index()
	return error

func record_playtime(profile_id: StringName, seconds: int, stage_id: StringName = &"") -> void:
	var profile := get_progression_profile(profile_id, false)
	if profile == null: return
	profile.playtime_seconds += maxi(0, seconds)
	if not stage_id.is_empty(): profile.last_played_stage = stage_id

func profile_summaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile_id in progression_profiles:
		var profile: ProgressionProfile = progression_profiles[profile_id]
		result.append({"profile_id": profile.profile_id, "display_name": profile.display_name, "playtime_seconds": profile.playtime_seconds, "campaign_progress": profile.campaign_progress.duplicate(true), "last_played_stage": profile.last_played_stage, "new_game_plus_cycle": profile.new_game_plus_cycle, "level": profile.level})
	result.sort_custom(func(a, b): return String(a.profile_id) < String(b.profile_id))
	return result

func snapshot_profiles() -> Dictionary:
	var result := {}
	for profile_id in progression_profiles: result[profile_id] = progression_profiles[profile_id].to_snapshot()
	return result

func restore_profiles(snapshot: Dictionary) -> bool:
	var restored := {}
	for profile_id in snapshot:
		if not snapshot[profile_id] is Dictionary: return false
		var migrated := SaveSchemaMigrator.migrate(snapshot[profile_id])
		if not migrated.success: return false
		var profile := ProgressionProfile.from_snapshot(migrated.data)
		restored[profile.profile_id] = profile
	progression_profiles = restored
	return true

func load_index() -> void:
	progression_profiles.clear()
	selected_profile_ids.clear()
	if save_service == null: return
	var index_path := "%s/profiles.json" % save_service.storage_root
	var index := save_service.load_snapshot_recovering(index_path, false)
	for raw_id in index.get("profile_ids", []):
		var profile_id := StringName(raw_id)
		var snapshot := save_service.load_profile(profile_id)
		if not snapshot.is_empty():
			var validation := ProfileContentValidator.validate(snapshot, content_database)
			if validation.valid:
				progression_profiles[profile_id] = ProgressionProfile.from_snapshot(snapshot)
			else:
				save_service.report_required_content_error(profile_id, validation)
	for raw_id in index.get("selected_profile_ids", []):
		var profile_id := StringName(raw_id)
		if progression_profiles.has(profile_id): selected_profile_ids.append(profile_id)
	if selected_profile_ids.is_empty() and not progression_profiles.is_empty(): selected_profile_ids.append(StringName(progression_profiles.keys()[0]))

func _save_index() -> Error:
	if save_service == null: return ERR_UNCONFIGURED
	return save_service.save_snapshot_atomic({"schema_version": SaveService.SCHEMA_VERSION, "kind": "profile_index", "profile_ids": progression_profiles.keys(), "selected_profile_ids": selected_profile_ids}, "%s/profiles.json" % save_service.storage_root)

func _next_profile_id() -> StringName:
	var index := 1
	while progression_profiles.has(StringName("profile.local_%d" % index)): index += 1
	return StringName("profile.local_%d" % index)

func _clean_name(value: String) -> String:
	var cleaned := InputSanitizer.sanitize_display_name(value, 32)
	return cleaned if not cleaned.is_empty() else "Pilot"
