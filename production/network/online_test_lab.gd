class_name OnlineTestLab
extends Node

var host := OnlineSessionCoordinator.new()
var client := OnlineSessionCoordinator.new()
var simulator := NetworkSimulator.new()
var now_ms := 0

func configure(seed := 190019, latency_ms := 100, packet_loss := 0.0) -> bool:
	var graph := {"mission_id": &"mission.online_lab", "seed": seed, "nodes": [{"node_id": &"entry"}, {"node_id": &"enemy"}, {"node_id": &"boss"}]}
	if not host.configure(1, true, seed, graph, [1, 2]) or not client.configure(2, false, seed, graph, [1, 2]): return false
	host.name = "HostAuthority"; client.name = "RemoteClient"; add_child(host); add_child(client)
	host.register_player(1, Vector2(220, 820)); host.register_player(2, Vector2(320, 820))
	client.register_player(1, Vector2(220, 820)); client.register_player(2, Vector2(320, 820))
	simulator.configure(latency_ms, packet_loss, seed, 10)
	host.outbound_message.connect(_queue_message); client.outbound_message.connect(_queue_message)
	return true

func advance(milliseconds: int) -> int:
	now_ms += maxi(0, milliseconds)
	var delivered := 0
	for queued in simulator.poll(now_ms):
		var target := int(queued.target_peer_id)
		var accepted := host.receive_message(queued.message) if target == 1 else client.receive_message(queued.message)
		if accepted: delivered += 1
	return delivered

func _queue_message(target_peer_id: int, message: Dictionary) -> void:
	var accepted := simulator.enqueue(target_peer_id, message, now_ms)
	if not accepted:
		if message.sender_peer_id == 1: host.diagnostics.record_drop()
		else: client.diagnostics.record_drop()
