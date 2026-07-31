class_name NetworkProtocol
extends RefCounted

const PROTOCOL_VERSION := 19
const MAX_PACKET_BYTES := 64 * 1024
const MAX_PAYLOAD_BYTES := 48 * 1024
const MAX_NESTING_DEPTH := 8
const MAX_CONTAINER_ENTRIES := 256
const MAX_ARRAY_ENTRIES := 128
const MAX_STRING_BYTES := 1024
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
	if not message.protocol is int:
		errors.append("Network protocol version must be an integer")
	elif message.protocol != PROTOCOL_VERSION:
		errors.append("Protocol version mismatch")
	if not (message.type is String or message.type is StringName):
		errors.append("Network message type must be text")
	elif StringName(message.type) not in MESSAGE_TYPES:
		errors.append("Unknown message type: %s" % message.type)
	if not message.sequence is int:
		errors.append("Network sequence must be an integer")
	elif message.sequence < 1:
		errors.append("Network sequence must be positive")
	elif message.sequence > 2147483647:
		errors.append("Network sequence exceeds the supported range")
	if not message.sender_peer_id is int:
		errors.append("Sender peer ID must be an integer")
	elif message.sender_peer_id < 1:
		errors.append("Sender peer ID must be positive")
	elif message.sender_peer_id > 2:
		errors.append("Sender peer ID exceeds the two-player protocol")
	if not message.tick is int:
		errors.append("Network tick must be an integer")
	elif message.tick < 0 or message.tick > 2147483647:
		errors.append("Network tick is outside the supported range")
	if not message.payload is Dictionary:
		errors.append("Message payload must be a Dictionary")
	else:
		var payload_error := _validate_bounded_variant(message.payload)
		if not payload_error.is_empty(): errors.append(payload_error)
		elif var_to_bytes(message.payload).size() > MAX_PAYLOAD_BYTES: errors.append("Network payload exceeds the byte limit")
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
	if not host_manifest.protocol is int or not client_manifest.protocol is int:
		return {"compatible": false, "reason": &"invalid_manifest", "message": "Compatibility protocol data is invalid."}
	if not (host_manifest.build_version is String or host_manifest.build_version is StringName) or not (client_manifest.build_version is String or client_manifest.build_version is StringName):
		return {"compatible": false, "reason": &"invalid_manifest", "message": "Compatibility build data is invalid."}
	if not (host_manifest.content_revision is String or host_manifest.content_revision is StringName) or not (client_manifest.content_revision is String or client_manifest.content_revision is StringName):
		return {"compatible": false, "reason": &"invalid_manifest", "message": "Compatibility content data is invalid."}
	if not (host_manifest.compatibility_hash is String or host_manifest.compatibility_hash is StringName) or not (client_manifest.compatibility_hash is String or client_manifest.compatibility_hash is StringName):
		return {"compatible": false, "reason": &"invalid_manifest", "message": "Compatibility hash data is invalid."}
	if host_manifest.protocol != client_manifest.protocol:
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

static func _validate_bounded_variant(value: Variant) -> String:
	return _validate_bounded_variant_recursive(value, 0, [0])

static func _validate_bounded_variant_recursive(value: Variant, depth: int, budget: Array[int]) -> String:
	if depth > MAX_NESTING_DEPTH: return "Network payload exceeds the nesting limit"
	if value is Dictionary:
		budget[0] += value.size()
		if budget[0] > MAX_CONTAINER_ENTRIES: return "Network payload contains too many fields"
		for key in value:
			if str(key).to_utf8_buffer().size() > MAX_STRING_BYTES: return "Network field name is too long"
			var error := _validate_bounded_variant_recursive(value[key], depth + 1, budget)
			if not error.is_empty(): return error
		return ""
	if value is Array:
		if value.size() > MAX_ARRAY_ENTRIES: return "Network array exceeds the entry limit"
		budget[0] += value.size()
		if budget[0] > MAX_CONTAINER_ENTRIES: return "Network payload contains too many entries"
		for entry in value:
			var error := _validate_bounded_variant_recursive(entry, depth + 1, budget)
			if not error.is_empty(): return error
		return ""
	if value is String or value is StringName:
		if str(value).to_utf8_buffer().size() > MAX_STRING_BYTES: return "Network string exceeds the byte limit"
		return ""
	if value is float and not is_finite(value): return "Network number must be finite"
	if value is Object or value is Callable or value is Signal: return "Network payload contains an unsupported object"
	if not (value == null or value is bool or value is int or value is float or value is Vector2 or value is Vector2i or value is Vector3 or value is Vector3i or value is Color):
		return "Network payload contains an unsupported value type"
	return ""
