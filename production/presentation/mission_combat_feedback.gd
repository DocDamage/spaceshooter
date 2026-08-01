class_name MissionCombatFeedback
extends Node

var feedback := CombatFeedbackController.new()
var vibration := VibrationRouter.new()
var input: GameInputService
var camera: PresentationCameraRig
var screen_effects: ScreenEffectsController
var _attached: Dictionary = {}

func configure(settings: SettingsService, input_service: GameInputService, camera_rig: PresentationCameraRig, effects: ScreenEffectsController) -> void:
	input = input_service
	camera = camera_rig
	screen_effects = effects
	vibration.configure(settings)
	add_child(feedback)
	feedback.feedback_requested.connect(_present)

func attach(actor: BaseActor2D) -> void:
	if actor == null or _attached.has(actor.get_instance_id()): return
	_attached[actor.get_instance_id()] = true
	feedback.connect_actor(actor)
	if actor is ProductionPlayer:
		actor.damage_resolved.connect(func(_packet: DamagePacket, result: DamageResult):
			if result.health_damage > 0.0: _vibrate(actor, &"player_damage", 0.35, 0.7, 0.16))
		actor.shield_component.shield_broken.connect(func(): _vibrate(actor, &"shield_break", 0.3, 0.85, 0.22))
		if actor.weapon_runtime != null:
			actor.weapon_runtime.fired.connect(func(weapon_id: StringName, count: int):
				if count > 0: _vibrate(actor, &"heavy_weapon" if String(weapon_id).contains("missile") else &"primary_weapon", 0.08, 0.2, 0.06))

func _vibrate(player: ProductionPlayer, category: StringName, weak: float, strong: float, duration: float) -> void:
	if input != null:
		vibration.emit(category, int(input.player_devices.get(player.player_index, GameInputService.UNASSIGNED_DEVICE)), weak, strong, duration)

func _present(kind: StringName, position: Vector2, value: float, _player_id: StringName) -> void:
	if screen_effects != null and kind in [&"hit_flash", &"shield_break"]:
		screen_effects.trigger(&"hit_flash", clampf(value / 50.0, 0.15, 0.7))
	if camera != null and kind in [&"hit_flash", &"shield_break"]:
		camera.add_shake(kind, clampf(value * 0.25, 1.0, 5.0), 0.12, 30.0)
