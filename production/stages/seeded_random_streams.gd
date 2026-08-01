class_name SeededRandomStreams
extends RefCounted

var root_seed: int
var _streams: Dictionary = {}

func _init(seed_value := 1) -> void:
	root_seed = seed_value if seed_value != 0 else 1

func stream(stream_id: StringName) -> RandomNumberGenerator:
	if not _streams.has(stream_id):
		var random := RandomNumberGenerator.new()
		random.seed = root_seed ^ int(String(stream_id).hash())
		_streams[stream_id] = random
	return _streams[stream_id]

func snapshot() -> Dictionary:
	var states := {}
	for stream_id in _streams:
		states[String(stream_id)] = (_streams[stream_id] as RandomNumberGenerator).state
	return {"root_seed": root_seed, "states": states}

func restore(data: Dictionary) -> void:
	root_seed = int(data.get("root_seed", root_seed))
	_streams.clear()
	for stream_id in data.get("states", {}):
		var random := stream(StringName(stream_id))
		random.state = int(data.states[stream_id])
