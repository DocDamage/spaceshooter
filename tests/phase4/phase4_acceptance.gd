extends SceneTree

var failures := PackedStringArray()
var passed_count := 0
var test_settings_path := "user://phase4_acceptance_settings.json"

func _init() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)

func _run() -> void:
	await process_frame
	_test_action_map_and_devices()
	_test_rebinding()
	_test_persistence()
	_test_component_library()
	_test_accessibility_metadata()
	if FileAccess.file_exists(test_settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_settings_path))
	if failures.is_empty():
		print("PHASE 4 ACCEPTANCE: all %d checks passed" % passed_count)
		quit(0)
	else:
		print("PHASE 4 ACCEPTANCE: %d check(s) failed" % failures.size())
		quit(1)

func _make_services() -> Array:
	var settings := SettingsService.new()
	settings.storage_path = test_settings_path
	settings.initialize()
	var hub := ServiceHub.new()
	hub.settings = settings
	var input := GameInputService.new()
	input.initialize({"hub": hub})
	return [settings, input, hub]

func _free_services(pair: Array) -> void:
	(pair[1] as GameInputService).free()
	(pair[0] as SettingsService).free()
	(pair[2] as ServiceHub).free()

func _test_action_map_and_devices() -> void:
	var pair := _make_services()
	var input: GameInputService = pair[1]
	_assert(GameInputService.ACTION_NAMES.size() == 42, "complete navigation, movement, legacy compatibility, and arcade action catalog exists")
	_assert(GameInputService.ACTION_NAMES.all(func(action): return InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty()), "every Phase 4 action has a default binding")
	_assert(InputMap.action_get_events(&"primary_fire").any(func(event): return event is InputEventMouseButton), "mouse primary fire has a default binding")
	_assert(input.assign_device(0, GameInputService.DEVICE_KEYBOARD_MOUSE), "keyboard and mouse can be assigned to player one")
	_assert(not input.assign_device(1, GameInputService.DEVICE_KEYBOARD_MOUSE), "a device cannot control multiple players by default")
	input.allow_shared_devices = true
	_assert(input.assign_device(1, GameInputService.DEVICE_KEYBOARD_MOUSE), "explicit shared-device configuration is supported")
	input._on_joy_connection_changed(GameInputService.DEVICE_KEYBOARD_MOUSE, false)
	input._on_joy_connection_changed(GameInputService.DEVICE_KEYBOARD_MOUSE, true)
	_assert(input.player_devices[0] == GameInputService.DEVICE_KEYBOARD_MOUSE and input.player_devices[1] == GameInputService.DEVICE_KEYBOARD_MOUSE, "device assignments recover when a disconnected device returns")
	_assert(input.get_glyph_family(GameInputService.DEVICE_KEYBOARD_MOUSE) == &"keyboard_mouse", "keyboard prompts select keyboard glyph family")
	_free_services(pair)

func _test_rebinding() -> void:
	var pair := _make_services()
	var input: GameInputService = pair[1]
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F8
	_assert(input.rebind(&"primary_fire", key, &"replace"), "keyboard binding can be captured and replaced")
	_assert(&"primary_fire" in input.get_conflicts(&"spell", key), "binding conflicts are detected")
	_assert(not input.rebind(&"spell", key, &"cancel"), "binding conflict can be cancelled safely")
	_assert(input.rebind(&"spell", key, &"swap"), "binding conflict can be swapped")
	_assert(InputMap.action_get_events(&"ui_confirm").any(func(event): return event is InputEventKey), "confirm always retains emergency keyboard navigation")
	_assert(InputMap.action_get_events(&"ui_accept").size() == InputMap.action_get_events(&"ui_confirm").size(), "confirm rebinding drives native Godot control activation")
	_assert(InputMap.action_get_events(&"ui_cancel").any(func(event): return event is InputEventKey), "cancel always retains emergency keyboard navigation")
	input.restore_default_bindings()
	_free_services(pair)

func _test_persistence() -> void:
	var settings := SettingsService.new()
	settings.storage_path = test_settings_path
	settings.initialize()
	settings.set_setting(&"aim_assistance", 0.65)
	settings.set_setting(&"colorblind_filter", "tritanopia")
	var loaded := SettingsService.new()
	loaded.storage_path = test_settings_path
	loaded.initialize()
	_assert(is_equal_approx(float(loaded.get_setting(&"aim_assistance")), 0.65), "settings survive a service restart")
	_assert(loaded.get_setting(&"colorblind_filter") == "tritanopia", "accessibility settings persist")
	_assert(not FileAccess.file_exists(test_settings_path + ".tmp"), "settings use temporary-file replacement without stale writes")
	settings.free()
	loaded.free()
	var file := FileAccess.open(test_settings_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 1, "values": {"ui_scale": 999.0, "game_speed_assistance": "fast", "vsync_enabled": "yes", "vibration_categories": {"primary_weapon": false, "boss_impact": "invalid"}}, "bindings": []}))
	file.close()
	var sanitized := SettingsService.new()
	sanitized.storage_path = test_settings_path
	sanitized.initialize()
	_assert(is_equal_approx(float(sanitized.get_setting(&"ui_scale")), 1.5) and is_equal_approx(float(sanitized.get_setting(&"game_speed_assistance")), 1.0) and sanitized.get_setting(&"vsync_enabled") is bool and not bool(sanitized.get_setting(&"vibration_categories").get("primary_weapon", true)) and bool(sanitized.get_setting(&"vibration_categories").get("boss_impact", false)), "malformed known settings fall back or clamp without poisoning startup")
	sanitized.free()

func _test_component_library() -> void:
	var components: Array[Control] = [
		UIComponentLibrary.primary_button("Primary"), UIComponentLibrary.secondary_button("Secondary"),
		UIComponentLibrary.icon_button("?", "Help"), UIComponentLibrary.segmented_control(PackedStringArray(["A", "B"])),
		UIComponentLibrary.slider(0, 1, 0.5), UIComponentLibrary.check_box("Check", true),
		UIComponentLibrary.drop_down(PackedStringArray(["One"])), UIComponentLibrary.key_binding_row("Fire", "Space"),
		UIComponentLibrary.equipment_card("Equipment", "Test"), UIComponentLibrary.ship_card("Ship", "Test"),
		UIComponentLibrary.stage_card("Stage", "Test"), UIComponentLibrary.profile_card("Profile", "Test"),
		UIComponentLibrary.tab_bar(PackedStringArray(["Tab"])), UIComponentLibrary.tooltip("Tip"),
		UIComponentLibrary.notification_toast("Saved"), UIComponentLibrary.loading_indicator(),
	]
	_assert(components.size() == 16 and components.all(func(control): return control != null), "shared UI component library exposes all reusable inline components")
	var confirmation := UIComponentLibrary.confirmation_dialog("Confirm", "Test")
	var warning := UIComponentLibrary.warning_dialog("Warning", "Test")
	_assert(confirmation != null and warning != null, "shared confirmation and warning dialogs exist")
	_assert(components[0].focus_mode == Control.FOCUS_ALL, "shared interactive components are controller-focusable")
	for component in components:
		component.free()
	confirmation.free()
	warning.free()

func _test_accessibility_metadata() -> void:
	var settings := SettingsService.new()
	settings.storage_path = test_settings_path
	settings.initialize()
	settings.set_setting(&"auto_fire", true, false)
	settings.set_setting(&"simplified_patterns", true, false)
	var preview := AccessibilityPreview.new()
	preview.configure(settings)
	var metadata := preview.run_metadata()
	_assert("auto_fire" in metadata.active_assists and "simplified_patterns" in metadata.active_assists, "active assists are recorded in neutral run metadata")
	_assert(metadata.accessibility_allowed, "assists do not block campaign progress")
	preview.free()
	settings.free()
