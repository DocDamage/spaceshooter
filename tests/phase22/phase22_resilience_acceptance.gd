extends SceneTree

const NETWORK_CASES := 512
const MALFORMED_SAVE_CASES := 256
const VALID_SAVE_CASES := 64

var failures := PackedStringArray()
var passed_count := 0
var storage_path := ""
var saves: SaveService
var rng := RandomNumberGenerator.new()

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
	rng.seed = 0x47414C4158
	storage_path = "user://phase22_resilience_%d" % Time.get_ticks_usec()
	saves = SaveService.new()
	root.add_child(saves)
	saves.configure_storage(storage_path.path_join("profiles"))
	_test_valid_network_corpus()
	_test_malformed_network_corpus()
	_test_save_round_trip_corpus()
	_test_malformed_save_corpus()
	if failures.is_empty():
		print("PHASE 22 ACCEPTANCE: all %d checks passed (%d network and %d save cases)" % [passed_count, NETWORK_CASES * 2, VALID_SAVE_CASES + MALFORMED_SAVE_CASES])
		_finish(0)
	else:
		print("PHASE 22 ACCEPTANCE: %d check(s) failed" % failures.size())
		_finish(1)

func _test_valid_network_corpus() -> void:
	var all_valid := true
	for index in NETWORK_CASES:
		var payload := {
			"frame": index,
			"move": Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)),
			"pressed": index % 3 == 0,
			"labels": ["fuzz", "case_%d" % index],
			"state": {"energy": rng.randi_range(0, 100), "heat": rng.randf()}
		}
		var message_type := NetworkProtocol.MESSAGE_TYPES[index % NetworkProtocol.MESSAGE_TYPES.size()]
		var message := NetworkProtocol.make_message(message_type, index + 1, 1 + index % 2, payload, index)
		if not NetworkProtocol.validate_message(message).is_empty():
			all_valid = false
			break
	_assert(all_valid, "%d deterministic bounded network messages validate without false rejection" % NETWORK_CASES)

func _test_malformed_network_corpus() -> void:
	var all_rejected := true
	var error_classes := {}
	for index in NETWORK_CASES:
		var message := NetworkProtocol.make_message(&"player_input", index + 1, 1, {"frame": index}, index)
		match index % 12:
			0: message["protocol"] = "19"
			1: message["type"] = {"forged": true}
			2: message["sequence"] = -index - 1
			3: message["sender_peer_id"] = 3 + index
			4: message["tick"] = INF
			5: message["payload"] = "not-a-dictionary"
			6: message["payload"] = {"text": "x".repeat(NetworkProtocol.MAX_STRING_BYTES + 1)}
			7: message["payload"] = {"values": Array(range(NetworkProtocol.MAX_ARRAY_ENTRIES + 1))}
			8:
				var nested: Variant = 0
				for depth in NetworkProtocol.MAX_NESTING_DEPTH + 2: nested = {"next": nested}
				message["payload"] = {"nested": nested}
			9: message["payload"] = {"bytes": PackedByteArray([1, 2, 3])}
			10:
				var fields := {}
				for field_index in NetworkProtocol.MAX_CONTAINER_ENTRIES + 1: fields["field_%d" % field_index] = field_index
				message["payload"] = fields
			11: message.erase("payload")
		var errors := NetworkProtocol.validate_message(message)
		if errors.is_empty():
			all_rejected = false
			break
		error_classes[errors[0]] = true
	_assert(all_rejected and error_classes.size() >= 10, "%d malformed/type-confused/bounds-violating network messages fail closed across distinct validation classes" % NETWORK_CASES)
	var manifest := NetworkProtocol.compatibility_manifest(&"fuzz_revision", "0.20.0")
	var confused := manifest.duplicate(true); confused["protocol"] = {"forged": 19}
	_assert(not NetworkProtocol.compare_compatibility(manifest, confused).compatible, "type-confused compatibility manifests are rejected without coercing attacker-controlled fields")

func _test_save_round_trip_corpus() -> void:
	var path := storage_path.path_join("valid_fuzz.json")
	var all_valid := true
	for index in VALID_SAVE_CASES:
		var snapshot := {
			"schema_version": SaveService.SCHEMA_VERSION,
			"fuzz_index": index,
			"profile": {"name": "Pilot %03d" % index, "level": rng.randi_range(1, 99)},
			"inventory": _random_inventory(index),
			"flags": [index % 2 == 0, index % 3 == 0, index % 5 == 0]
		}
		if saves.save_snapshot_atomic(snapshot, path) != OK:
			all_valid = false
			break
		var loaded := saves.load_snapshot_recovering(path, false)
		if int(loaded.get("fuzz_index", -1)) != index or str(loaded.get("profile", {}).get("name", "")) != snapshot.profile.name:
			all_valid = false
			break
	_assert(all_valid, "%d varied bounded save documents round-trip atomically through checksum validation" % VALID_SAVE_CASES)

func _test_malformed_save_corpus() -> void:
	var malformed_seeds := [
		"", "{", "[", "not-json", "{\"schema_version\":9", "{\"checksum\":true,\"payload\":{}}",
		"{\"checksum\":\"deadbeef\",\"payload\":{}}", "{\"schema_version\":9,\"payload\":null}",
		"{\"checksum\":\"0\",\"payload\":[]}", "{\"payload\":{\"nested\":[1,2,3]}}"
	]
	var all_rejected_and_preserved := true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(storage_path))
	for index in MALFORMED_SAVE_CASES:
		var path := storage_path.path_join("malformed_%03d.json" % index)
		var mutation := "#%d_%08x" % [index, rng.randi()]
		var text := str(malformed_seeds[index % malformed_seeds.size()]) + mutation
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			all_rejected_and_preserved = false
			break
		file.store_string(text)
		file.close()
		var before_hash := FileAccess.get_file_as_string(path).sha256_text()
		var loaded := saves.load_snapshot_recovering(path, false)
		var after_hash := FileAccess.get_file_as_string(path).sha256_text()
		if not loaded.is_empty() or before_hash != after_hash or not FileAccess.file_exists(path):
			all_rejected_and_preserved = false
			break
	_assert(all_rejected_and_preserved, "%d malformed/truncated/checksum-invalid saves fail closed and remain byte-for-byte preserved for recovery" % MALFORMED_SAVE_CASES)

func _random_inventory(index: int) -> Array:
	var result: Array = []
	for item_index in 1 + index % 8:
		result.append({"id": "item.%d.%d" % [index, item_index], "quantity": rng.randi_range(1, 20), "locked": item_index % 4 == 0})
	return result

func _finish(exit_code: int) -> void:
	saves = null
	TestSupport.free_root_nodes(self)
	TestSupport.remove_tree(storage_path)
	call_deferred("_quit_after_cleanup", exit_code)

func _quit_after_cleanup(exit_code: int) -> void:
	await process_frame
	quit(exit_code)
