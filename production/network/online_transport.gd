class_name OnlineTransport
extends Node

signal connected(peer_id: int)
signal disconnected(peer_id: int)
signal message_received(message: Dictionary)
signal connection_failed(reason: StringName)

const DEFAULT_PORT := 27191
const MAX_CLIENTS := 1

var peer: ENetMultiplayerPeer
var active := false
var is_host := false

func create_host(port := DEFAULT_PORT) -> Error:
	close()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK: connection_failed.emit(&"host_creation_failed"); peer = null; return error
	is_host = true; active = true
	return OK

func join_host(address: String, port := DEFAULT_PORT) -> Error:
	close()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK: connection_failed.emit(&"client_creation_failed"); peer = null; return error
	is_host = false; active = true
	return OK

func send_message(target_peer_id: int, message: Dictionary) -> Error:
	if not active or peer == null or not NetworkProtocol.validate_message(message).is_empty(): return ERR_UNCONFIGURED
	peer.set_target_peer(target_peer_id)
	return peer.put_packet(var_to_bytes(message))

func close() -> void:
	if peer != null: peer.close()
	peer = null; active = false; is_host = false

func _process(_delta: float) -> void:
	if not active or peer == null: return
	peer.poll()
	while peer.get_available_packet_count() > 0:
		var packet := peer.get_packet()
		var decoded = bytes_to_var(packet)
		if decoded is Dictionary and NetworkProtocol.validate_message(decoded).is_empty(): message_received.emit(decoded)
	match peer.get_connection_status():
		MultiplayerPeer.CONNECTION_DISCONNECTED:
			if active: active = false; disconnected.emit(1 if not is_host else 0)
		MultiplayerPeer.CONNECTION_CONNECTED: pass

func _exit_tree() -> void: close()
