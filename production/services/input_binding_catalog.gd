class_name InputBindingCatalog
extends RefCounted

const ACTION_NAMES := [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_confirm", &"ui_cancel", &"ui_tab_previous", &"ui_tab_next", &"ui_page_previous", &"ui_page_next", &"pause", &"rapid_shot", &"focus_beam", &"element", &"overdrive", &"bomb", &"move_left", &"move_right", &"move_up", &"move_down", &"focus", &"aim_left", &"aim_right", &"aim_up", &"aim_down", &"lock_on", &"primary_fire", &"secondary_fire", &"heavy_weapon", &"spell", &"melee", &"shield", &"parry", &"dash", &"barrel_roll", &"boost", &"teleport", &"super_mode", &"next_weapon", &"previous_weapon", &"wingman_command", &"wingman_command_wheel"]
const LEGACY_ACTION_MIGRATIONS := {&"primary_fire": &"rapid_shot", &"focus": &"focus_beam", &"spell": &"element", &"super_mode": &"overdrive"}
const BUFFERED_ACTIONS := [&"bomb", &"overdrive"]

static func defaults() -> Dictionary:
	return {
		&"ui_up": [key(KEY_UP), joy_button(JOY_BUTTON_DPAD_UP), joy_axis(JOY_AXIS_LEFT_Y, -1.0)], &"ui_down": [key(KEY_DOWN), joy_button(JOY_BUTTON_DPAD_DOWN), joy_axis(JOY_AXIS_LEFT_Y, 1.0)], &"ui_left": [key(KEY_LEFT), joy_button(JOY_BUTTON_DPAD_LEFT), joy_axis(JOY_AXIS_LEFT_X, -1.0)], &"ui_right": [key(KEY_RIGHT), joy_button(JOY_BUTTON_DPAD_RIGHT), joy_axis(JOY_AXIS_LEFT_X, 1.0)],
		&"ui_confirm": [key(KEY_ENTER), key(KEY_SPACE), joy_button(JOY_BUTTON_A)], &"ui_cancel": [key(KEY_ESCAPE), joy_button(JOY_BUTTON_B)], &"ui_tab_previous": [key(KEY_Q), joy_button(JOY_BUTTON_LEFT_SHOULDER)], &"ui_tab_next": [key(KEY_E), joy_button(JOY_BUTTON_RIGHT_SHOULDER)], &"ui_page_previous": [key(KEY_PAGEUP)], &"ui_page_next": [key(KEY_PAGEDOWN)], &"pause": [key(KEY_ESCAPE), joy_button(JOY_BUTTON_START)],
		&"move_left": [key(KEY_A), joy_button(JOY_BUTTON_DPAD_LEFT), joy_axis(JOY_AXIS_LEFT_X, -1.0)], &"move_right": [key(KEY_D), joy_button(JOY_BUTTON_DPAD_RIGHT), joy_axis(JOY_AXIS_LEFT_X, 1.0)], &"move_up": [key(KEY_W), joy_button(JOY_BUTTON_DPAD_UP), joy_axis(JOY_AXIS_LEFT_Y, -1.0)], &"move_down": [key(KEY_S), joy_button(JOY_BUTTON_DPAD_DOWN), joy_axis(JOY_AXIS_LEFT_Y, 1.0)],
		&"rapid_shot": [key(KEY_Z), joy_button(JOY_BUTTON_A)], &"focus_beam": [key(KEY_X), joy_button(JOY_BUTTON_X)], &"element": [key(KEY_C), joy_button(JOY_BUTTON_Y)], &"overdrive": [key(KEY_V), joy_button(JOY_BUTTON_B)], &"bomb": [key(KEY_SHIFT), joy_button(JOY_BUTTON_RIGHT_SHOULDER)], &"focus": [key(KEY_X), joy_button(JOY_BUTTON_X)],
		&"aim_left": [joy_axis(JOY_AXIS_RIGHT_X, -1.0)], &"aim_right": [joy_axis(JOY_AXIS_RIGHT_X, 1.0)], &"aim_up": [joy_axis(JOY_AXIS_RIGHT_Y, -1.0)], &"aim_down": [joy_axis(JOY_AXIS_RIGHT_Y, 1.0)], &"lock_on": [key(KEY_L), joy_button(JOY_BUTTON_RIGHT_STICK)],
		&"primary_fire": [key(KEY_Z), joy_button(JOY_BUTTON_A)], &"secondary_fire": [key(KEY_J), joy_button(JOY_BUTTON_X)], &"heavy_weapon": [key(KEY_K), joy_button(JOY_BUTTON_Y)], &"spell": [key(KEY_C), joy_button(JOY_BUTTON_Y)], &"melee": [key(KEY_V)], &"shield": [key(KEY_C), joy_button(JOY_BUTTON_LEFT_SHOULDER)], &"parry": [key(KEY_R)], &"dash": [key(KEY_ALT), joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)], &"barrel_roll": [key(KEY_B)], &"boost": [key(KEY_CTRL)], &"teleport": [key(KEY_T)], &"super_mode": [key(KEY_V), joy_button(JOY_BUTTON_B)], &"next_weapon": [key(KEY_BRACKETRIGHT)], &"previous_weapon": [key(KEY_BRACKETLEFT)], &"wingman_command": [key(KEY_X)], &"wingman_command_wheel": [key(KEY_Z)],
	}

static func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new(); event.physical_keycode = code; return event

static func joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new(); event.button_index = button; return event

static func joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new(); event.axis = axis; event.axis_value = value; return event

static func serialize(event: InputEvent) -> Dictionary:
	if event is InputEventKey: return {"type": "key", "physical_keycode": event.physical_keycode}
	if event is InputEventMouseButton: return {"type": "mouse_button", "button_index": event.button_index}
	if event is InputEventJoypadButton: return {"type": "joy_button", "button_index": event.button_index}
	if event is InputEventJoypadMotion: return {"type": "joy_axis", "axis": event.axis, "axis_value": event.axis_value}
	return {}

static func deserialize(data: Dictionary) -> InputEvent:
	match data.get("type", ""):
		"key": return key(int(data.get("physical_keycode", 0)) as Key)
		"mouse_button":
			var event := InputEventMouseButton.new(); event.button_index = int(data.get("button_index", 1)) as MouseButton; return event
		"joy_button": return joy_button(int(data.get("button_index", 0)) as JoyButton)
		"joy_axis": return joy_axis(int(data.get("axis", 0)) as JoyAxis, float(data.get("axis_value", 1.0)))
	return null

static func joy_prompt(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		var names := ["A", "B", "X", "Y", "Back", "Guide", "Start", "L3", "R3", "LB", "RB", "D-pad Up", "D-pad Down", "D-pad Left", "D-pad Right"]
		return names[event.button_index] if event.button_index >= 0 and event.button_index < names.size() else "Button %d" % event.button_index
	if event is InputEventJoypadMotion:
		var axes := ["Left X", "Left Y", "Right X", "Right Y", "LT", "RT"]
		return "%s %s" % [axes[event.axis] if event.axis >= 0 and event.axis < axes.size() else "Axis %d" % event.axis, "+" if event.axis_value > 0 else "−"]
	return event.as_text()

static func prompt(action: StringName, requested_device: int) -> String:
	for event in InputMap.action_get_events(action):
		if requested_device >= 0 and (event is InputEventJoypadButton or event is InputEventJoypadMotion): return joy_prompt(event)
		if requested_device == -1 and (event is InputEventKey or event is InputEventMouseButton): return event.as_text()
	return String(action).replace("_", " ").capitalize()

static func glyph_family(settings: SettingsService, requested_device: int) -> StringName:
	var override := String(settings.get_setting(&"glyph_family", "auto")) if settings else "auto"
	if override != "auto": return StringName(override)
	if requested_device < 0: return &"keyboard_mouse"
	var name := Input.get_joy_name(requested_device).to_lower()
	if "playstation" in name or "dualshock" in name or "dualsense" in name: return &"playstation"
	if "switch" in name or "nintendo" in name: return &"nintendo"
	return &"xbox"
