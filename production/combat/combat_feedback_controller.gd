class_name CombatFeedbackController
extends Node

signal feedback_requested(kind: StringName, world_position: Vector2, value: float, player_id: StringName)

var maximum_audio_voices := 32
var active_audio_voices := 0
var vibration_enabled := true
var flash_scale := 1.0
var shake_scale := 1.0

func report(kind: StringName, world_position: Vector2, value := 0.0, player_id: StringName = &"") -> void:
	feedback_requested.emit(kind, world_position, value, player_id)

func request_audio_voice() -> bool:
	if active_audio_voices >= maximum_audio_voices:
		return false
	active_audio_voices += 1
	return true

func release_audio_voice() -> void:
	active_audio_voices = maxi(0, active_audio_voices - 1)

func vibrate(device_id: int, weak: float, strong: float, duration_seconds: float) -> void:
	if vibration_enabled and device_id >= 0:
		Input.start_joy_vibration(device_id, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), maxf(0.0, duration_seconds))

func connect_actor(actor: BaseActor2D) -> void:
	actor.damage_resolved.connect(func(_packet: DamagePacket, result: DamageResult):
		if result.shield_damage > 0.0: report(&"shield_block", actor.global_position, result.shield_damage)
		if result.health_damage > 0.0: report(&"hit_flash", actor.global_position, result.health_damage)
		if result.reflected_damage > 0.0: report(&"reflection", actor.global_position, result.reflected_damage)
		if result.absorbed_damage > 0.0: report(&"absorb", actor.global_position, result.absorbed_damage))
	actor.shield_component.shield_broken.connect(func(): report(&"shield_break", actor.global_position))
