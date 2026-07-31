extends SceneTree

var failures := PackedStringArray()
var passed_count := 0
var settings: SettingsService

func _init() -> void: call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if condition: passed_count += 1; print("PASS: %s" % message)
	else: failures.append(message); push_error("FAIL: %s" % message)

func _run() -> void:
	await process_frame
	settings = SettingsService.new(); settings.storage_path = "user://phase11_settings_%d.json" % Time.get_ticks_usec(); root.add_child(settings); settings.initialize()
	_test_coordinate_model()
	_test_parallax_and_reduced_motion()
	_test_camera_and_effect_settings()
	_test_effect_budget()
	await _test_audio_and_vibration()
	await _test_ship_and_stress()
	if failures.is_empty(): print("PHASE 11 ACCEPTANCE: all %d checks passed" % passed_count); _finish(0)
	else: print("PHASE 11 ACCEPTANCE: %d check(s) failed" % failures.size()); _finish(1)

func _finish(exit_code: int) -> void:
	for child in root.get_children():
		if child is ServiceHub and child.audio != null:
			child.audio.stop_all()
	call_deferred("_free_after_audio_shutdown", exit_code)

func _free_after_audio_shutdown(exit_code: int) -> void:
	for ignored in 5: await process_frame
	settings = null
	TestSupport.free_root_nodes(self)
	call_deferred("_quit_after_cleanup", exit_code)

func _quit_after_cleanup(exit_code: int) -> void:
	for ignored in 5: await process_frame
	quit(exit_code)

func _test_coordinate_model() -> void:
	var actor := Area2D.new(); actor.position = Vector2(100, 200); root.add_child(actor)
	var visual := Node2D.new(); actor.add_child(visual)
	var presentation := PresentationActor.new(); actor.add_child(presentation); presentation.configure(visual, settings)
	var gameplay_position := actor.position
	presentation.set_altitude(0.8)
	_assert(actor.position == gameplay_position and visual.position != Vector2.ZERO, "altitude changes presentation without moving the gameplay hitbox")
	_assert(not presentation.is_targetable() and visual.modulate.a < 1.0, "off-plane altitude communicates non-targetability")
	presentation.set_altitude(0.0)
	_assert(presentation.is_targetable() and visual.modulate.a == 1.0, "combat-plane targetability is unambiguous")

func _test_parallax_and_reduced_motion() -> void:
	var definition := BackgroundLayerDefinition.new(); definition.stable_id = &"background.test"; definition.presentation_layer = "far_background"; definition.scroll_ratio = Vector2(0.0, 0.5); definition.reduced_motion_scroll_ratio = Vector2(0.0, 0.01)
	var parallax := ParallaxPresentation.new(); root.add_child(parallax); parallax.configure([definition], settings); parallax.tick(1.0)
	var normal_y := (parallax.offsets[definition.stable_id] as Vector2).y
	settings.set_setting(&"background_motion_reduction", 1.0, false); parallax.offsets[definition.stable_id] = Vector2.ZERO; parallax.tick(1.0)
	var reduced_y := (parallax.offsets[definition.stable_id] as Vector2).y
	_assert(normal_y > reduced_y and reduced_y > 0.0, "six-layer parallax definitions provide an understandable reduced-motion alternative")

func _test_camera_and_effect_settings() -> void:
	var camera := PresentationCameraRig.new(); root.add_child(camera); camera.configure(settings)
	settings.set_setting(&"screen_shake_scale", 0.0, false); camera.add_shake(&"impact", 20.0, 1.0); camera._process(0.1)
	_assert(camera.position.length() == 0.0, "camera shake is source-layered and disabled by its setting")
	var effects := ScreenEffectsController.new(); root.add_child(effects); effects.configure(settings)
	settings.set_setting(&"flash_reduction", 1.0, false)
	_assert(effects.trigger(&"hit_flash", 1.0) == 0.0, "hit flash honors flash reduction")
	settings.set_setting(&"particle_density", 0.25, false); settings.set_setting(&"background_motion_reduction", 0.0, false)
	_assert(is_equal_approx(effects.trigger(&"speed_lines", 1.0), 0.25), "screen motion effects honor particle density")

func _test_effect_budget() -> void:
	var pool := EffectsPoolManager.new(); pool.maximum_active = 200; root.add_child(pool)
	for index in 260: pool.spawn_effect(&"impact", &"decorative", Vector2(index, 0))
	_assert(pool.active.size() <= 70 and pool.active.size() <= pool.maximum_active, "effects pooling enforces category and global budgets")
	var reused := pool.active[0]; pool.release_effect(reused)
	_assert(pool.spawn_effect(&"spell", &"gameplay") == reused, "released presentation effects are reused")

func _test_audio_and_vibration() -> void:
	var hub := ServiceHub.new(); root.add_child(hub); _assert(hub.initialize_services(), "presentation audio services initialize")
	var buses_valid := true
	for bus in GameAudioService.BUS_NAMES: buses_valid = buses_valid and AudioServer.get_bus_index(bus) >= 0
	_assert(buses_valid, "all nine Phase 11 audio buses exist")
	var stream := AudioStreamWAV.new(); stream.format = AudioStreamWAV.FORMAT_8_BITS; stream.mix_rate = 11025
	var silence := PackedByteArray(); silence.resize(11025); silence.fill(128); stream.data = silence
	for index in 30: hub.audio.play(stream, &"Weapons", index % 3)
	_assert(hub.audio.active_voice_count(&"Weapons") <= int(hub.audio.voice_limits[&"Weapons"]), "dense combat audio obeys per-bus voice limits")
	hub.settings.set_setting(&"vibration_enabled", false, false)
	var vibration := VibrationRouter.new(); vibration.configure(hub.settings)
	_assert(not vibration.emit(&"player_damage", -1, 1.0, 1.0, 0.2), "vibration events respect global accessibility settings")

func _test_ship_and_stress() -> void:
	var visual := ShipPresentation.new(); root.add_child(visual); visual.update_state(Vector2(1, -1), 0.8, 0.2, true, true, 0.1)
	_assert(visual.thrust > 0.0 and visual.recoil > 0.0 and visual.super_active, "ship presentation covers thrust, shield, damage, recoil, and super state")
	var actors: Array[Node2D] = []
	var start := Time.get_ticks_usec()
	for index in 150:
		var actor := Node2D.new(); var child := Node2D.new(); actor.add_child(child); var presentation := PresentationActor.new(); actor.add_child(presentation); presentation.configure(child, settings); presentation.banking_amount = sin(index); presentation.apply_presentation(); root.add_child(actor); actors.append(actor)
	var pool := EffectsPoolManager.new(); root.add_child(pool)
	for index in 300: pool.spawn_effect(&"impact", &"decorative", Vector2(index % 30, index / 30))
	await process_frame
	_assert(Time.get_ticks_usec() - start < 1000000 and pool.active.size() <= 200, "150 actors and 300 effect requests remain within the presentation stress budget")
