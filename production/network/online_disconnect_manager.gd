class_name OnlineDisconnectManager
extends RefCounted

signal reconnect_window_opened(peer_id: int, deadline_ms: int)
signal disconnect_resolved(peer_id: int, resolution: StringName)

var reconnect_window_ms := 30000
var disconnected: Dictionary = {}
var ai_takeover_enabled := true

func handle_disconnect(peer_id: int, is_host: bool, checkpoint_snapshot: Dictionary, now_ms: int) -> Dictionary:
	var record := {
		"peer_id": peer_id, "is_host": is_host, "deadline_ms": now_ms + reconnect_window_ms,
		"checkpoint": checkpoint_snapshot.duplicate(true), "ai_takeover": ai_takeover_enabled and not is_host,
		"reward_eligible": not checkpoint_snapshot.is_empty(), "resolved": false
	}
	disconnected[peer_id] = record
	reconnect_window_opened.emit(peer_id, int(record.deadline_ms))
	return {"pause": is_host, "mission_abort": is_host, "ai_takeover": record.ai_takeover, "reconnect_deadline_ms": record.deadline_ms, "save_checkpoint": not checkpoint_snapshot.is_empty()}

func reconnect(peer_id: int, now_ms: int) -> Dictionary:
	if not disconnected.has(peer_id): return {"accepted": false, "reason": &"no_reconnect_record"}
	var record: Dictionary = disconnected[peer_id]
	if now_ms > int(record.deadline_ms): return {"accepted": false, "reason": &"reconnect_window_expired"}
	disconnected.erase(peer_id)
	disconnect_resolved.emit(peer_id, &"reconnected")
	return {"accepted": true, "checkpoint": record.checkpoint.duplicate(true), "reward_eligible": record.reward_eligible}

func expire(now_ms: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for peer_id in disconnected.keys().duplicate():
		var record: Dictionary = disconnected[peer_id]
		if now_ms <= int(record.deadline_ms): continue
		disconnected.erase(peer_id)
		results.append({"peer_id": peer_id, "resolution": &"removed", "reward_eligible": record.reward_eligible})
		disconnect_resolved.emit(peer_id, &"removed")
	return results
