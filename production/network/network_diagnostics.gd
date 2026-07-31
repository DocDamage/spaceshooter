class_name NetworkDiagnostics
extends RefCounted

signal desync_detected(details: Dictionary)

var ping_ms := 0.0
var packet_loss_percent := 0.0
var snapshot_age_ms := 0.0
var correction_count := 0
var desync_warning_count := 0
var authority_peer_id := 1
var stage_seed := 0
var last_event_sequence := 0
var packets_sent := 0
var packets_received := 0
var packets_dropped := 0
var _local_hashes: Dictionary = {}

func record_sent() -> void: packets_sent += 1

func record_received(sequence: int, round_trip_ms := -1.0) -> void:
	packets_received += 1
	last_event_sequence = maxi(last_event_sequence, sequence)
	if round_trip_ms >= 0.0: ping_ms = lerpf(ping_ms, round_trip_ms, 0.25) if ping_ms > 0.0 else round_trip_ms
	_update_loss()

func record_drop() -> void:
	packets_dropped += 1
	_update_loss()

func record_snapshot(age_ms: float) -> void: snapshot_age_ms = maxf(0.0, age_ms)

func record_correction() -> void: correction_count += 1

func store_local_hash(tick: int, state_hash: String) -> void:
	_local_hashes[tick] = state_hash
	while _local_hashes.size() > 120: _local_hashes.erase(_local_hashes.keys().min())

func verify_authority_hash(tick: int, authority_hash: String) -> bool:
	if not _local_hashes.has(tick): return true
	if str(_local_hashes[tick]) == authority_hash: return true
	desync_warning_count += 1
	desync_detected.emit({"tick": tick, "local_hash": _local_hashes[tick], "authority_hash": authority_hash})
	return false

func snapshot() -> Dictionary:
	return {
		"ping_ms": ping_ms, "packet_loss": packet_loss_percent, "snapshot_age_ms": snapshot_age_ms,
		"correction_count": correction_count, "desync_warnings": desync_warning_count,
		"authority_peer_id": authority_peer_id, "stage_seed": stage_seed,
		"event_sequence": last_event_sequence, "packets_sent": packets_sent,
		"packets_received": packets_received, "packets_dropped": packets_dropped
	}

func _update_loss() -> void:
	var total := packets_received + packets_dropped
	packet_loss_percent = (float(packets_dropped) / float(total)) * 100.0 if total > 0 else 0.0
