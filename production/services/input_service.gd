class_name GameInputService
extends BaseGameService

signal active_device_changed(device_kind: StringName, device_id: int, glyph_family: StringName)
signal player_device_changed(player_index: int, device_id: int)
signal controller_connection_changed(device_id: int, connected: bool)
signal bindings_changed(action: StringName)

const DEVICE_KEYBOARD_MOUSE := -1
const UNASSIGNED_DEVICE := -2
const REQUIRED_ESCAPE_ACTIONS := [&"ui_confirm", &"ui_cancel"]
const ACTION_NAMES := [
	&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_confirm", &"ui_cancel",
	&"ui_tab_previous", &"ui_tab_next", &"ui_page_previous", &"ui_page_next", &"pause",
	&"move_left", &"move_right", &"move_up", &"move_down", &"focus",
	&"aim_left", &"aim_right", &"aim_up", &"aim_down", &"lock_on",
	&"primary_fire", &"secondary_fire", &"heavy_weapon", &"spell", &"melee", &"shield",
	&"parry", &"dash", &"barrel_roll", &"boost", &"teleport", &"super_mode",
	&"next_weapon", &"previous_weapon", &"wingman_command", &"wingman_command_wheel",
]

var last_device_kind: StringName = &"keyboard_mouse"
var last_device_id := DEVICE_KEYBOARD_MOUSE
var player_devices: Dictionary = {0: DEVICE_KEYBOARD_MOUSE}
var allow_shared_devices := false
var _settings: SettingsService
var _default_events: Dictionary = {}

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
	is_initialized = true
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.relative.length_squared() < 1.0:
		return
	if not (event is InputEventKey or event is InputEventMouse or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if event is InputEventJoypadMotion and absf(event.axis_value) < 0.45:
		return
	var kind: StringName = &"controller" if event is InputEventJoypadButton or event is InputEventJoypadMotion else &"keyboard_mouse"
	var device := event.device if kind == &"controller" else DEVICE_KEYBOARD_MOUSE
	if kind != last_device_kind or device != last_device_id:
		last_device_kind = kind
		last_device_id = device
		active_device_changed.emit(kind, device, get_glyph_family(device))

func get_move_vector(player_index := 0) -> Vector2:
	var vector := _device_vector(&"move_left", &"move_right", &"move_up", &"move_down", player_index)
	var sensitivity := float(_settings.get_setting(&"movement_sensitivity", 1.0)) if _settings else 1.0
	if _settings and not bool(_settings.get_setting(&"analog_movement", true)) and vector != Vector2.ZERO:
		vector = Vector2(signf(vector.x), signf(vector.y)).normalized()
	return vector.limit_length() * sensitivity

func get_aim_vector(player_index := 0) -> Vector2:
	var vector := _device_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down", player_index)
	var sensitivity := float(_settings.get_setting(&"aim_sensitivity", 1.0)) if _settings else 1.0
	return vector.limit_length() * sensitivity

func is_fire_pressed(player_index := 0) -> bool:
	return is_action_pressed_for_player(&"primary_fire", player_index) or (_settings and bool(_settings.get_setting(&"auto_fire", false)))

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
	var requested_device := last_device_id if device_id == -99 else device_id
	for event in InputMap.action_get_events(action):
		if requested_device >= 0 and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			return _joy_prompt(event)
		if requested_device == DEVICE_KEYBOARD_MOUSE and (event is InputEventKey or event is InputEventMouseButton):
			return event.as_text()
	return String(action).replace("_", " ").capitalize()

func get_glyph_family(device_id := -99) -> StringName:
	var override := String(_settings.get_setting(&"glyph_family", "auto")) if _settings else "auto"
	if override != "auto":
		return StringName(override)
	var requested_device := last_device_id if device_id == -99 else device_id
	if requested_device < 0:
		return &"keyboard_mouse"
	var name := Input.get_joy_name(requested_device).to_lower()
	if "playstation" in name or "dualshock" in name or "dualsense" in name:
		return &"playstation"
	if "switch" in name or "nintendo" in name:
		return &"nintendo"
	return &"xbox"

func _device_vector(left: StringName, right: StringName, up: StringName, down: StringName, player_index: int) -> Vector2:
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
			var strength := _event_strength(event, assigned)
			if strength > 0.0:
				result += pair[1] * strength
				break
	return result.limit_length()

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
	var defaults := {
		&"ui_up": [_key(KEY_UP), _joy_button(JOY_BUTTON_DPAD_UP), _joy_axis(JOY_AXIS_LEFT_Y, -1.0)],
		&"ui_down": [_key(KEY_DOWN), _joy_button(JOY_BUTTON_DPAD_DOWN), _joy_axis(JOY_AXIS_LEFT_Y, 1.0)],
		&"ui_left": [_key(KEY_LEFT), _joy_button(JOY_BUTTON_DPAD_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0)],
		&"ui_right": [_key(KEY_RIGHT), _joy_button(JOY_BUTTON_DPAD_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0)],
		&"ui_confirm": [_key(KEY_ENTER), _key(KEY_SPACE), _joy_button(JOY_BUTTON_A)],
		&"ui_cancel": [_key(KEY_ESCAPE), _joy_button(JOY_BUTTON_B)],
		&"ui_tab_previous": [_key(KEY_Q), _joy_button(JOY_BUTTON_LEFT_SHOULDER)],
		&"ui_tab_next": [_key(KEY_E), _joy_button(JOY_BUTTON_RIGHT_SHOULDER)],
		&"ui_page_previous": [_key(KEY_PAGEUP)], &"ui_page_next": [_key(KEY_PAGEDOWN)],
		&"pause": [_key(KEY_ESCAPE), _joy_button(JOY_BUTTON_START)],
		&"move_left": [_key(KEY_A), _joy_axis(JOY_AXIS_LEFT_X, -1.0)], &"move_right": [_key(KEY_D), _joy_axis(JOY_AXIS_LEFT_X, 1.0)],
		&"move_up": [_key(KEY_W), _joy_axis(JOY_AXIS_LEFT_Y, -1.0)], &"move_down": [_key(KEY_S), _joy_axis(JOY_AXIS_LEFT_Y, 1.0)],
		&"focus": [_key(KEY_SHIFT), _joy_button(JOY_BUTTON_LEFT_STICK)],
		&"aim_left": [_joy_axis(JOY_AXIS_RIGHT_X, -1.0)], &"aim_right": [_joy_axis(JOY_AXIS_RIGHT_X, 1.0)],
		&"aim_up": [_joy_axis(JOY_AXIS_RIGHT_Y, -1.0)], &"aim_down": [_joy_axis(JOY_AXIS_RIGHT_Y, 1.0)],
		&"lock_on": [_key(KEY_L), _joy_button(JOY_BUTTON_RIGHT_STICK)],
		&"primary_fire": [_key(KEY_SPACE), _joy_button(JOY_BUTTON_A)], &"secondary_fire": [_key(KEY_J), _joy_button(JOY_BUTTON_X)],
		&"heavy_weapon": [_key(KEY_K), _joy_button(JOY_BUTTON_Y)], &"spell": [_key(KEY_F), _joy_button(JOY_BUTTON_RIGHT_SHOULDER)],
		&"melee": [_key(KEY_V)], &"shield": [_key(KEY_C), _joy_button(JOY_BUTTON_LEFT_SHOULDER)], &"parry": [_key(KEY_R)],
		&"dash": [_key(KEY_ALT), _joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)], &"barrel_roll": [_key(KEY_B)], &"boost": [_key(KEY_CTRL)],
		&"teleport": [_key(KEY_T)], &"super_mode": [_key(KEY_G)], &"next_weapon": [_key(KEY_BRACKETRIGHT)],
		&"previous_weapon": [_key(KEY_BRACKETLEFT)], &"wingman_command": [_key(KEY_X)], &"wingman_command_wheel": [_key(KEY_Z)],
	}
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
	for action_key in _settings.get_bindings():
		var action := StringName(action_key)
		if action not in ACTION_NAMES:
			continue
		var events: Array[InputEvent] = []
		for data in _settings.get_bindings()[action_key]:
			var event := _deserialize_event(data)
			if event != null:
				events.append(event)
		if not events.is_empty():
			InputMap.action_erase_events(action)
			for event in events:
				InputMap.action_add_event(action, event)
	_ensure_emergency_bindings()

func _persist_bindings() -> void:
	if _settings == null:
		return
	var result := {}
	for action in ACTION_NAMES:
		result[String(action)] = InputMap.action_get_events(action).map(_serialize_event)
	_settings.set_bindings(result)

func _ensure_emergency_bindings() -> void:
	if not InputMap.action_get_events(&"ui_confirm").any(func(event): return event is InputEventKey):
		InputMap.action_add_event(&"ui_confirm", _key(KEY_ENTER))
	if not InputMap.action_get_events(&"ui_cancel").any(func(event): return event is InputEventKey):
		InputMap.action_add_event(&"ui_cancel", _key(KEY_ESCAPE))

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
		for player_index in player_devices:
			if player_devices[player_index] == device_id:
				unassign_device(player_index)
		# Keyboard remains an emergency menu device regardless of player assignment.
		last_device_kind = &"keyboard_mouse"
		last_device_id = DEVICE_KEYBOARD_MOUSE
	controller_connection_changed.emit(device_id, connected)

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event

func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event

func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event

func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "physical_keycode": event.physical_keycode}
	if event is InputEventMouseButton:
		return {"type": "mouse_button", "button_index": event.button_index}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button_index": event.button_index}
	if event is InputEventJoypadMotion:
		return {"type": "joy_axis", "axis": event.axis, "axis_value": event.axis_value}
	return {}

func _deserialize_event(data: Dictionary) -> InputEvent:
	match data.get("type", ""):
		"key": return _key(int(data.get("physical_keycode", 0)) as Key)
		"mouse_button":
			var event := InputEventMouseButton.new(); event.button_index = int(data.get("button_index", 1)) as MouseButton; return event
		"joy_button": return _joy_button(int(data.get("button_index", 0)) as JoyButton)
		"joy_axis": return _joy_axis(int(data.get("axis", 0)) as JoyAxis, float(data.get("axis_value", 1.0)))
	return null

func _joy_prompt(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		var names := ["A", "B", "X", "Y", "Back", "Guide", "Start", "L3", "R3", "LB", "RB", "D-pad Up", "D-pad Down", "D-pad Left", "D-pad Right"]
		return names[event.button_index] if event.button_index >= 0 and event.button_index < names.size() else "Button %d" % event.button_index
	if event is InputEventJoypadMotion:
		var axes := ["Left X", "Left Y", "Right X", "Right Y", "LT", "RT"]
		var axis_name: String = axes[event.axis] if event.axis >= 0 and event.axis < axes.size() else "Axis %d" % event.axis
		return "%s %s" % [axis_name, "+" if event.axis_value > 0 else "−"]
	return event.as_text()
