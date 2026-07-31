class_name NetworkSimulator
extends RefCounted

var latency_ms := 0
var jitter_ms := 0
var packet_loss_percent := 0.0
var _random := RandomNumberGenerator.new()
var _queue: Array[Dictionary] = []

func configure(simulated_latency_ms: int, simulated_packet_loss: float, seed := 190019, simulated_jitter_ms := 0) -> void:
	latency_ms = maxi(0, simulated_latency_ms)
	jitter_ms = maxi(0, simulated_jitter_ms)
	packet_loss_percent = clampf(simulated_packet_loss, 0.0, 100.0)
	_random.seed = seed
	_queue.clear()

func enqueue(target_peer_id: int, message: Dictionary, now_ms: int) -> bool:
	if _random.randf_range(0.0, 100.0) < packet_loss_percent: return false
	var delay := latency_ms
	if jitter_ms > 0: delay += _random.randi_range(-jitter_ms, jitter_ms)
	_queue.append({"target_peer_id": target_peer_id, "deliver_at_ms": now_ms + maxi(0, delay), "message": message.duplicate(true)})
	return true

func poll(now_ms: int) -> Array[Dictionary]:
	var delivered: Array[Dictionary] = []
	for queued in _queue.duplicate():
		if now_ms < int(queued.deliver_at_ms): continue
		delivered.append(queued)
		_queue.erase(queued)
	return delivered

func pending_count() -> int: return _queue.size()
