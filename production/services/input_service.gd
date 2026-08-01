class_name GameInputService
extends BaseGameService

signal active_device_changed(device_kind: StringName, device_id: int, glyph_family: StringName)
signal player_device_changed(player_index: int, device_id: int)
signal controller_connection_changed(device_id: int, connected: bool)
signal bindings_changed(action: StringName)

const DEVICE_KEYBOARD_MOUSE := -1
const UNASSIGNED_DEVICE := -2
const REQUIRED_ESCAPE_ACTIONS := [&"ui_confirm", &"ui_cancel"]
const ACTION_NAMES := InputBindingCatalog.ACTION_NAMES
const LEGACY_ACTION_MIGRATIONS := InputBindingCatalog.LEGACY_ACTION_MIGRATIONS; const BUFFERED_ACTIONS := InputBindingCatalog.BUFFERED_ACTIONS; const DeviceReconnectMemoryScript = preload("res://production/services/device_reconnect_memory.gd")

var last_device_kind: StringName = &"keyboard_mouse"
var last_device_id := DEVICE_KEYBOARD_MOUSE
var player_devices: Dictionary = {0: DEVICE_KEYBOARD_MOUSE}
var allow_shared_devices := false
var _settings: SettingsService
var _default_events: Dictionary = {}
var _buffered_actions: Dictionary = {}
var _reconnect_memory = DeviceReconnectMemoryScript.new()
func get_settings_service() -> SettingsService:
	return _settings
func _init() -> void:
	service_id = &"input"

func initialize(context: Dictionary = {}) -> bool:
	_settings = context.get("hub").settings if context.has("hub") else null
	_build_default_map()
	_apply_saved_bindings()
	_sync_confirm_alias()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	set_process_input(true)
	set_physics_process(true)
	is_initialized = true
	return true
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.relative.length_squared() < 1.0:
		return
	if not (event is InputEventKey or event is InputEventMouse or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	_buffer_actions(event)
	if event is InputEventJoypadMotion and absf(event.axis_value) < 0.45:
		return
	var kind: StringName = &"controller" if event is InputEventJoypadButton or event is InputEventJoypadMotion else &"keyboard_mouse"
	var device := event.device if kind == &"controller" else DEVICE_KEYBOARD_MOUSE
	if kind != last_device_kind or device != last_device_id:
		last_device_kind = kind
		last_device_id = device
		active_device_changed.emit(kind, device, get_glyph_family(device))
func _physics_process(_delta: float) -> void:
	for action in _buffered_actions.keys():
		var buffer: Dictionary = _buffered_actions[action]
		buffer.frames = int(buffer.frames) - 1
		if int(buffer.frames) <= 0:
			_buffered_actions.erase(action)
		else:
			_buffered_actions[action] = buffer

func get_move_vector(player_index := 0) -> Vector2:
	var assigned: int = player_devices.get(player_index, UNASSIGNED_DEVICE)
	var vector := _device_vector(&"move_left", &"move_right", &"move_up", &"move_down", player_index, assigned < 0)
	if assigned >= 0:
		var dead_zone := float(_settings.get_setting(&"controller_dead_zone", 0.18)) if _settings else 0.18
		var curve := float(_settings.get_setting(&"analog_response_curve", 1.0)) if _settings else 1.0
		var analog := ArcadeInputRules.radial_response(Vector2(Input.get_joy_axis(assigned, JOY_AXIS_LEFT_X), Input.get_joy_axis(assigned, JOY_AXIS_LEFT_Y)), dead_zone, curve)
		vector = analog if analog.length_squared() >= vector.length_squared() else vector
	if _settings and not bool(_settings.get_setting(&"analog_movement", true)) and vector != Vector2.ZERO:
		vector = Vector2(signf(vector.x), signf(vector.y)).normalized()
	return vector.limit_length()

func get_aim_vector(player_index := 0) -> Vector2:
	var vector := _device_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down", player_index)
	var sensitivity := float(_settings.get_setting(&"aim_sensitivity", 1.0)) if _settings else 1.0
	return vector.limit_length() * sensitivity

func is_fire_pressed(player_index := 0) -> bool:
	return is_action_pressed_for_player(&"rapid_shot", player_index) or (_settings and bool(_settings.get_setting(&"auto_fire", false)))

func is_focus_beam_pressed(player_index := 0) -> bool:
	return is_action_pressed_for_player(&"focus_beam", player_index)
func consume_buffered_action(action: StringName, player_index := 0) -> bool:
	var buffer: Dictionary = _buffered_actions.get(action, {})
	if buffer.is_empty() or int(buffer.get(&"device", UNASSIGNED_DEVICE)) != int(player_devices.get(player_index, UNASSIGNED_DEVICE)):
		return false
	_buffered_actions.erase(action)
	return true

func is_assist_enabled(key: StringName) -> bool:
	return _settings != null and bool(_settings.get_setting(key, false))

func get_gameplay_setting(key: StringName, fallback: Variant = null) -> Variant:
	return _settings.get_setting(key, fallback) if _settings != null else fallback

func is_action_pressed_for_player(action: StringName, player_index: int) -> bool:
	var assigned: int = player_devices.get(player_index, UNASSIGNED_DEVICE)
	for event in InputMap.action_get_events(action):
		if assigned == DEVICE_KEYBOARD_MOUSE and (event is InputEventKey or event is InputEventMouse):
			if _event_strength(event, assigned) > 0.0:
				return true
		if assigned >= 0 and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			if _event_strength(event, assigned) > 0.0:
				return true
	return false

func is_action_just_pressed_for_player(action: StringName, player_index: int) -> bool:
	# Godot owns edge detection; device ownership is still enforced by the held-state check.
	return Input.is_action_just_pressed(action) and is_action_pressed_for_player(action, player_index)

func assign_device(player_index: int, device_id: int) -> bool:
	if device_id >= 0 and device_id not in Input.get_connected_joypads():
		return false
	if not allow_shared_devices:
		for existing_player in player_devices:
			if existing_player != player_index and player_devices[existing_player] == device_id:
				return false
	player_devices[player_index] = device_id
	player_device_changed.emit(player_index, device_id)
	return true

func unassign_device(player_index: int) -> void:
	player_devices[player_index] = UNASSIGNED_DEVICE
	player_device_changed.emit(player_index, UNASSIGNED_DEVICE)

func get_conflicts(action: StringName, event: InputEvent) -> Array[StringName]:
	var conflicts: Array[StringName] = []
	for candidate in ACTION_NAMES:
		if candidate == action:
			continue
		for bound in InputMap.action_get_events(candidate):
			if bound.is_match(event, true):
				conflicts.append(candidate)
	return conflicts

func rebind(action: StringName, event: InputEvent, conflict_policy: StringName = &"cancel") -> bool:
	if action not in ACTION_NAMES or not _is_bindable_event(event):
		return false
	var conflicts := get_conflicts(action, event)
	if not conflicts.is_empty() and conflict_policy == &"cancel":
		return false
	if conflict_policy == &"replace":
		for conflict in conflicts:
			_remove_matching_event(conflict, event)
	elif conflict_policy == &"swap" and not conflicts.is_empty():
		var old_events := InputMap.action_get_events(action)
		_remove_matching_event(conflicts[0], event)
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)
		for old_event in old_events:
			InputMap.action_add_event(conflicts[0], old_event)
		bindings_changed.emit(conflicts[0])
		_ensure_emergency_bindings()
		_sync_confirm_alias()
		_persist_bindings()
		bindings_changed.emit(action)
		return true
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	_ensure_emergency_bindings()
	_sync_confirm_alias()
	_persist_bindings()
	bindings_changed.emit(action)
	return true

func restore_default_bindings() -> void:
	for action in ACTION_NAMES:
		InputMap.action_erase_events(action)
		for event in _default_events.get(action, []):
			InputMap.action_add_event(action, event.duplicate())
	_sync_confirm_alias()
	_persist_bindings()
	bindings_changed.emit(&"")

func get_prompt(action: StringName, device_id := -99) -> String:
	return InputBindingCatalog.prompt(action, last_device_id if device_id == -99 else device_id)

func get_glyph_family(device_id := -99) -> StringName:
	return InputBindingCatalog.glyph_family(_settings, last_device_id if device_id == -99 else device_id)

func _device_vector(left: StringName, right: StringName, up: StringName, down: StringName, player_index: int, include_axes := true) -> Vector2:
	var assigned: int = player_devices.get(player_index, UNASSIGNED_DEVICE)
	if assigned == UNASSIGNED_DEVICE:
		return Vector2.ZERO
	var result := Vector2.ZERO
	for pair in [[left, Vector2.LEFT], [right, Vector2.RIGHT], [up, Vector2.UP], [down, Vector2.DOWN]]:
		for event in InputMap.action_get_events(pair[0]):
			if assigned == DEVICE_KEYBOARD_MOUSE and not (event is InputEventKey):
				continue
			if assigned >= 0 and not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
				continue
			if not include_axes and event is InputEventJoypadMotion:
				continue
			var strength := _event_strength(event, assigned)
			if strength > 0.0:
				result += pair[1] * strength
				break
	return result.limit_length()

func _buffer_actions(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	var device := event.device if event is InputEventJoypadButton or event is InputEventJoypadMotion else DEVICE_KEYBOARD_MOUSE
	for action in BUFFERED_ACTIONS:
		if event.is_action_pressed(action):
			_buffered_actions[action] = {&"frames": 2, &"device": device}

func _event_strength(event: InputEvent, device_id: int) -> float:
	if event is InputEventKey:
		return 1.0 if Input.is_physical_key_pressed(event.physical_keycode) else 0.0
	if event is InputEventMouseButton:
		return 1.0 if Input.is_mouse_button_pressed(event.button_index) else 0.0
	if event is InputEventJoypadButton:
		return 1.0 if Input.is_joy_button_pressed(device_id, event.button_index) else 0.0
	if event is InputEventJoypadMotion:
		var value := Input.get_joy_axis(device_id, event.axis)
		if signf(value) != signf(event.axis_value):
			return 0.0
		var dead_zone := float(_settings.get_setting(&"controller_dead_zone", 0.25)) if _settings else 0.25
		return inverse_lerp(dead_zone, 1.0, absf(value)) if absf(value) > dead_zone else 0.0
	return 0.0

func _build_default_map() -> void:
	var defaults := InputBindingCatalog.defaults()
	for action in ACTION_NAMES:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
		if InputMap.action_get_events(action).is_empty():
			for event in defaults.get(action, []):
				InputMap.action_add_event(action, event)
		_default_events[action] = InputMap.action_get_events(action).map(func(event): return event.duplicate())

func _apply_saved_bindings() -> void:
	if _settings == null:
		return
	var saved := _settings.get_bindings()
	for action_key in saved:
		var action := StringName(action_key)
		if action not in ACTION_NAMES:
			continue
		var events: Array[InputEvent] = []
		for data in saved[action_key]:
			var event := InputBindingCatalog.deserialize(data)
			if event != null:
				events.append(event)
		if not events.is_empty():
			InputMap.action_erase_events(action)
			for event in events:
				InputMap.action_add_event(action, event)
	for legacy_action in LEGACY_ACTION_MIGRATIONS:
		var modern_action: StringName = LEGACY_ACTION_MIGRATIONS[legacy_action]
		if saved.has(String(legacy_action)) and not saved.has(String(modern_action)):
			InputMap.action_erase_events(modern_action)
			for data in saved[String(legacy_action)]:
				var event := InputBindingCatalog.deserialize(data)
				if event != null:
					InputMap.action_add_event(modern_action, event)
	_ensure_emergency_bindings()

func _persist_bindings() -> void:
	if _settings == null:
		return
	var result := {}
	for action in ACTION_NAMES:
		result[String(action)] = InputMap.action_get_events(action).map(InputBindingCatalog.serialize)
	_settings.set_bindings(result)

func _ensure_emergency_bindings() -> void:
	if not InputMap.action_get_events(&"ui_confirm").any(func(event): return event is InputEventKey):
		InputMap.action_add_event(&"ui_confirm", InputBindingCatalog.key(KEY_ENTER))
	if not InputMap.action_get_events(&"ui_cancel").any(func(event): return event is InputEventKey):
		InputMap.action_add_event(&"ui_cancel", InputBindingCatalog.key(KEY_ESCAPE))

func _sync_confirm_alias() -> void:
	# Godot Controls activate through ui_accept; ui_confirm remains the game's public abstraction.
	if not InputMap.has_action(&"ui_accept"):
		InputMap.add_action(&"ui_accept", 0.25)
	InputMap.action_erase_events(&"ui_accept")
	for event in InputMap.action_get_events(&"ui_confirm"):
		InputMap.action_add_event(&"ui_accept", event.duplicate())

func _remove_matching_event(action: StringName, target: InputEvent) -> void:
	for event in InputMap.action_get_events(action):
		if event.is_match(target, true):
			InputMap.action_erase_event(action, event)

func _is_bindable_event(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if not connected:
		_reconnect_memory.remember(self, device_id)
		# Keyboard remains an emergency menu device regardless of player assignment.
		last_device_kind = &"keyboard_mouse"
		last_device_id = DEVICE_KEYBOARD_MOUSE
	else:
		_reconnect_memory.restore(self, device_id)
	controller_connection_changed.emit(device_id, connected)
