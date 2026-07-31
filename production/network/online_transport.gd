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
var connection_timeout_seconds := 10.0
var connection_elapsed := 0.0
var _last_status := MultiplayerPeer.CONNECTION_DISCONNECTED

func create_host(port := DEFAULT_PORT) -> Error:
	close()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK: connection_failed.emit(&"host_creation_failed"); peer = null; return error
	is_host = true; active = true; connection_elapsed = 0.0; _last_status = peer.get_connection_status()
	return OK

func join_host(address: String, port := DEFAULT_PORT) -> Error:
	close()
	var cleaned_address := InputSanitizer.sanitize_network_text(address, 255)
	if cleaned_address.is_empty() or cleaned_address != address.strip_edges():
		connection_failed.emit(&"invalid_address")
		return ERR_INVALID_PARAMETER
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(cleaned_address, port)
	if error != OK: connection_failed.emit(&"client_creation_failed"); peer = null; return error
	is_host = false; active = true; connection_elapsed = 0.0; _last_status = peer.get_connection_status()
	return OK

func send_message(target_peer_id: int, message: Dictionary) -> Error:
	if not active or peer == null or not NetworkProtocol.validate_message(message).is_empty(): return ERR_UNCONFIGURED
	var packet := var_to_bytes(message)
	if packet.size() > NetworkProtocol.MAX_PACKET_BYTES: return ERR_INVALID_DATA
	peer.set_target_peer(target_peer_id)
	return peer.put_packet(packet)

func close() -> void:
	if peer != null: peer.close()
	peer = null; active = false; is_host = false; connection_elapsed = 0.0; _last_status = MultiplayerPeer.CONNECTION_DISCONNECTED

func _process(delta: float) -> void:
	if not active or peer == null: return
	connection_elapsed += delta
	peer.poll()
	while peer.get_available_packet_count() > 0:
		var packet := peer.get_packet()
		if packet.size() > NetworkProtocol.MAX_PACKET_BYTES:
			connection_failed.emit(&"packet_too_large")
			continue
		# Godot 4.7's one-argument decoder is the safe, object-disallowing API.
		var decoded = bytes_to_var(packet)
		if decoded is Dictionary and NetworkProtocol.validate_message(decoded).is_empty(): message_received.emit(decoded)
	var status := peer.get_connection_status()
	if status != _last_status:
		_last_status = status
		if status == MultiplayerPeer.CONNECTION_CONNECTED: connected.emit(peer.get_unique_id())
	match status:
		MultiplayerPeer.CONNECTION_DISCONNECTED:
			if active: active = false; disconnected.emit(1 if not is_host else 0)
		MultiplayerPeer.CONNECTION_CONNECTING:
			if connection_elapsed >= connection_timeout_seconds:
				connection_failed.emit(&"connection_timeout")
				close()
		MultiplayerPeer.CONNECTION_CONNECTED: connection_elapsed = 0.0

func _exit_tree() -> void: close()
