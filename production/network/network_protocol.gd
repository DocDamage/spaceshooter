class_name NetworkProtocol
extends RefCounted

const PROTOCOL_VERSION := 19
const MESSAGE_TYPES: Array[StringName] = [
	&"player_input", &"actor_spawn", &"actor_despawn", &"damage_confirmation",
	&"projectile_spawn", &"projectile_interaction", &"boss_phase", &"objective_event",
	&"checkpoint_snapshot", &"reward_result", &"menu_state", &"world_snapshot",
	&"disconnect_notice", &"reconnect_request"
]
const HOST_AUTHORITY_DOMAINS: Array[StringName] = [
	&"mission_seed", &"stage_graph", &"spawn_events", &"enemy_state", &"damage",
	&"deaths", &"drops", &"objectives", &"score", &"rewards", &"checkpoint"
]

static func make_message(message_type: StringName, sequence: int, sender_peer_id: int, payload: Dictionary, tick: int = 0) -> Dictionary:
	return {
		"protocol": PROTOCOL_VERSION,
		"type": message_type,
		"sequence": sequence,
		"sender_peer_id": sender_peer_id,
		"tick": tick,
		"payload": payload.duplicate(true)
	}

static func validate_message(message: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for key in [&"protocol", &"type", &"sequence", &"sender_peer_id", &"tick", &"payload"]:
		if not message.has(key): errors.append("Missing network message field: %s" % key)
	if not errors.is_empty(): return errors
	if int(message.protocol) != PROTOCOL_VERSION: errors.append("Protocol version mismatch")
	if StringName(message.type) not in MESSAGE_TYPES: errors.append("Unknown message type: %s" % message.type)
	if int(message.sequence) < 1: errors.append("Network sequence must be positive")
	if int(message.sender_peer_id) < 1: errors.append("Sender peer ID must be positive")
	if not message.payload is Dictionary: errors.append("Message payload must be a Dictionary")
	return errors

static func compatibility_manifest(content_revision: StringName, build_version: String = "") -> Dictionary:
	var version := build_version if not build_version.is_empty() else str(ProjectSettings.get_setting("application/config/version", "dev"))
	var manifest := {"protocol": PROTOCOL_VERSION, "build_version": version, "content_revision": content_revision}
	manifest["compatibility_hash"] = _compatibility_hash(manifest)
	return manifest

static func compare_compatibility(host_manifest: Dictionary, client_manifest: Dictionary) -> Dictionary:
	for key in [&"protocol", &"build_version", &"content_revision", &"compatibility_hash"]:
		if not host_manifest.has(key) or not client_manifest.has(key):
			return {"compatible": false, "reason": &"invalid_manifest", "message": "Compatibility data is incomplete."}
	if int(host_manifest.protocol) != int(client_manifest.protocol):
		return {"compatible": false, "reason": &"protocol_mismatch", "message": "Online protocol versions do not match."}
	if str(host_manifest.build_version) != str(client_manifest.build_version):
		return {"compatible": false, "reason": &"version_mismatch", "message": "Game versions do not match."}
	if StringName(host_manifest.content_revision) != StringName(client_manifest.content_revision):
		return {"compatible": false, "reason": &"content_mismatch", "message": "Installed campaign content does not match."}
	if str(host_manifest.compatibility_hash) != str(client_manifest.compatibility_hash):
		return {"compatible": false, "reason": &"manifest_tampered", "message": "Compatibility manifest could not be verified."}
	return {"compatible": true, "reason": &"compatible", "message": "Compatible"}

static func canonical_state_hash(state: Dictionary) -> String:
	return JSON.stringify(_canonicalize(state)).sha256_text()

static func _compatibility_hash(manifest: Dictionary) -> String:
	return "%d|%s|%s" % [int(manifest.protocol), str(manifest.build_version), str(manifest.content_revision)]

static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys()
		keys.sort_custom(func(a, b): return str(a) < str(b))
		for key in keys: result[str(key)] = _canonicalize(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in value: result.append(_canonicalize(entry))
		return result
	if value is Vector2: return [value.x, value.y]
	if value is StringName: return String(value)
	return value
