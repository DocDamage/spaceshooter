class_name PlatformService
extends BaseGameService

signal availability_changed(available: bool)
signal cloud_conflict_detected(conflict: Dictionary)
signal invitation_received(invitation: Dictionary)

var platform_name := "standalone"
var available := false
var overlay_active := false
var rich_presence: Dictionary = {}
var cloud_conflicts: Dictionary = {}
var _steam: Object

const MAX_CLOUD_FILE_BYTES := 4 * 1024 * 1024
const MAX_PRESENCE_FIELDS := 16

func _init() -> void:
	service_id = &"platform"

func initialize(_context: Dictionary = {}) -> bool:
	# Steam is an optional runtime provider. Absence or initialization failure always
	# leaves a complete standalone backend instead of preventing the game from booting.
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
		var init_result = _steam.call("steamInitEx") if _steam.has_method("steamInitEx") else null
		available = _steam != null and (init_result == null or int(init_result.get("status", 0) if init_result is Dictionary else init_result) == 0)
		if available: platform_name = "steam"
	is_initialized = true
	availability_changed.emit(available)
	return true

func configure_provider(provider: Object, provider_name := "test_provider") -> bool:
	_steam = provider
	available = provider != null
	platform_name = InputSanitizer.sanitize_network_text(provider_name, 48) if available else "standalone"
	availability_changed.emit(available)
	return available

func get_user_id() -> StringName:
	if available and _steam.has_method("getSteamID"):
		return StringName(str(_steam.call("getSteamID")))
	return &"local_user"

func supports(feature: StringName) -> bool:
	if feature in [&"local_profiles", &"local_saves", &"offline_fallback", &"achievements", &"glyphs", &"direct_ip_networking", &"network_simulation"]: return true
	return available and feature in [&"cloud_files", &"rich_presence", &"invitations", &"lobbies", &"user_identity", &"overlay_status", &"steam_input"]

func unlock_achievement(achievement_id: StringName) -> bool:
	if achievement_id.is_empty(): return false
	if available and _steam.has_method("setAchievement"):
		_steam.call("setAchievement", String(achievement_id))
		if _steam.has_method("storeStats"): _steam.call("storeStats")
	return true

func set_rich_presence(values: Dictionary) -> bool:
	if values.size() > MAX_PRESENCE_FIELDS: return false
	var sanitized := {}
	for key in values:
		var safe_key := InputSanitizer.safe_storage_key(str(key), 64)
		if safe_key.is_empty(): return false
		sanitized[safe_key] = InputSanitizer.sanitize_network_text(str(values[key]), 256)
	rich_presence = sanitized
	if available and _steam.has_method("setRichPresence"):
		for key in sanitized: _steam.call("setRichPresence", str(key), str(sanitized[key]))
	return true

func glyph_for_action(action: StringName, device_family: StringName = &"auto") -> StringName:
	if available and device_family in [&"auto", &"steam"]: return StringName("steam.%s" % action)
	return StringName("%s.%s" % ["keyboard" if device_family == &"auto" else device_family, action])

func receive_invitation(invitation: Dictionary) -> void:
	var sanitized := invitation.duplicate(true)
	for key in sanitized.keys():
		if sanitized[key] is String or sanitized[key] is StringName:
			sanitized[key] = InputSanitizer.sanitize_network_text(str(sanitized[key]), 256)
	invitation_received.emit(sanitized)

func set_overlay_active(value: bool) -> void:
	overlay_active = value

func compare_cloud_file(path: String, local: Dictionary, remote: Dictionary) -> Dictionary:
	var safe_path := InputSanitizer.safe_storage_key(path)
	if safe_path.is_empty(): return {"status": &"invalid_path", "path": "", "resolved": false, "choice": &""}
	var local_revision := int(local.get("revision", 0)); var remote_revision := int(remote.get("revision", 0))
	var local_hash := JSON.stringify(local).sha256_text(); var remote_hash := JSON.stringify(remote).sha256_text()
	if local_hash == remote_hash: return {"status": &"identical", "path": safe_path, "resolved": true, "choice": &"either"}
	if local.is_empty(): return {"status": &"remote_only", "path": safe_path, "resolved": true, "choice": &"remote"}
	if remote.is_empty(): return {"status": &"local_only", "path": safe_path, "resolved": true, "choice": &"local"}
	# A differing payload is always surfaced. Revision numbers inform the UI but never
	# authorize a silent overwrite of player progress.
	var conflict := {"status": &"conflict", "path": safe_path, "resolved": false, "choice": &"", "local": local.duplicate(true), "remote": remote.duplicate(true), "newer": &"local" if local_revision > remote_revision else &"remote" if remote_revision > local_revision else &"same_revision"}
	cloud_conflicts[safe_path] = conflict
	cloud_conflict_detected.emit(conflict.duplicate(true))
	return conflict.duplicate(true)

func resolve_cloud_conflict(path: String, choice: StringName) -> Dictionary:
	var safe_path := InputSanitizer.safe_storage_key(path)
	if not cloud_conflicts.has(safe_path) or choice not in [&"local", &"remote", &"keep_both"]: return {}
	var conflict: Dictionary = cloud_conflicts[safe_path]
	conflict.resolved = true; conflict.choice = choice
	cloud_conflicts.erase(safe_path)
	return conflict

func write_cloud_document(path: String, document: Dictionary) -> Error:
	var safe_path := InputSanitizer.safe_storage_key(path)
	if safe_path.is_empty(): return ERR_INVALID_PARAMETER
	var bytes := JSON.stringify(document).to_utf8_buffer()
	if bytes.size() > MAX_CLOUD_FILE_BYTES: return ERR_INVALID_DATA
	if not available or _steam == null or not _steam.has_method("fileWrite"): return ERR_UNAVAILABLE
	return OK if bool(_steam.call("fileWrite", safe_path, bytes)) else FAILED

func read_cloud_document(path: String) -> Dictionary:
	var safe_path := InputSanitizer.safe_storage_key(path)
	if safe_path.is_empty() or not available or _steam == null or not _steam.has_method("fileRead"):
		return {"error": ERR_UNAVAILABLE, "document": {}}
	var size := int(_steam.call("getFileSize", safe_path)) if _steam.has_method("getFileSize") else MAX_CLOUD_FILE_BYTES
	if size < 0 or size > MAX_CLOUD_FILE_BYTES: return {"error": ERR_INVALID_DATA, "document": {}}
	var raw = _steam.call("fileRead", safe_path, size)
	var bytes: PackedByteArray = raw if raw is PackedByteArray else PackedByteArray()
	if bytes.size() > MAX_CLOUD_FILE_BYTES: return {"error": ERR_INVALID_DATA, "document": {}}
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	return {"error": OK, "document": parsed} if parsed is Dictionary else {"error": ERR_PARSE_ERROR, "document": {}}
