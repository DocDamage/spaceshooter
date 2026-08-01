class_name DeviceReconnectMemory
extends RefCounted

var _waiting_players: Dictionary = {}
const UNASSIGNED_DEVICE := -2

func remember(input, device_id: int) -> void:
	var players: Array[int] = []
	for player_index in input.player_devices:
		if int(input.player_devices[player_index]) == device_id:
			players.append(player_index)
			input.unassign_device(player_index)
	if not players.is_empty():
		_waiting_players[device_id] = players

func restore(input, device_id: int) -> void:
	var remaining: Array[int] = []
	for player_index in _waiting_players.get(device_id, []):
		if int(input.player_devices.get(player_index, UNASSIGNED_DEVICE)) != UNASSIGNED_DEVICE or not input.assign_device(player_index, device_id):
			remaining.append(player_index)
	if remaining.is_empty():
		_waiting_players.erase(device_id)
	else:
		_waiting_players[device_id] = remaining
