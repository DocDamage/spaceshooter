class_name CooperativeHUD
extends CanvasLayer

var panels: Dictionary = {}
var session_manager: LocalCoopSessionManager

func configure(manager: LocalCoopSessionManager) -> void:
	session_manager = manager
	layer = 30
	for index in manager.roster.participants.size():
		var participant: Dictionary = manager.roster.participants[index]
		var label := Label.new()
		label.position = Vector2(14 if index == 0 else 330, 82)
		label.add_theme_color_override("font_color", participant.color)
		label.add_theme_font_size_override("font_size", 14)
		add_child(label)
		panels[participant.slot_id] = label
	update_from_manager(manager)

func _process(_delta: float) -> void:
	if session_manager != null: update_from_manager(session_manager)

func update_from_manager(manager: LocalCoopSessionManager) -> void:
	for participant in manager.roster.participants:
		var slot_id := StringName(participant.slot_id)
		var state: CoopPlayerState = manager.player_states.get(slot_id)
		var actor: ProductionPlayer = manager.actors.get(slot_id)
		var label: Label = panels.get(slot_id)
		if state == null or label == null: continue
		var health := actor.health_component.current / maxf(actor.health_component.maximum, 1.0) if actor != null else 0.0
		var shield := actor.shield_component.current / maxf(actor.shield_component.capacity, 1.0) if actor != null else 0.0
		var spell_energy := roundi(actor.spell_runtime.energy) if actor != null and actor.spell_runtime != null else 0
		var super_percent := 0
		if actor != null and actor.super_runtime != null and actor.super_runtime.definition != null:
			super_percent = roundi(actor.super_runtime.charge / maxf(actor.super_runtime.definition.charge_required, 1.0) * 100.0)
		var command := String(manager.command_indicators.get(slot_id, &"ready")).to_upper()
		var status := "DOWNED — REVIVE" if state.downed else "OUT" if state.eliminated else "READY"
		label.text = "%s  HP %d%%  SH %d%%\nSP %d  SUPER %d%%  CHAIN %d\nLives %d  Revives %d  CMD %s  %s" % [String(slot_id).replace("player_slot.", "P"), roundi(health * 100.0), roundi(shield * 100.0), spell_energy, super_percent, manager.team_chain, state.lives, state.revives_remaining, command, status]
