class_name CombatReplayState
extends RefCounted

static func snapshot(score_tracker: MissionScoreTracker, players: Array) -> Dictionary:
	var state := {&"score": score_tracker.snapshot() if score_tracker != null else {}, &"players": []}
	for player in players:
		if player is ProductionPlayer:
			state.players.append({&"actor_id": player.actor_id, &"element": (player.get_node_or_null("ElementRuntime") as ElementRuntime).snapshot() if player.get_node_or_null("ElementRuntime") != null else {}, &"overdrive": player.super_runtime.snapshot() if player.super_runtime != null else {}})
	return state

static func restore(state: Dictionary, players: Array) -> void:
	for saved in state.get(&"players", []):
		for player in players:
			if not player is ProductionPlayer or player.actor_id != StringName(saved.get(&"actor_id", "")): continue
			var element := player.get_node_or_null("ElementRuntime") as ElementRuntime
			if element != null and player.spell_runtime != null: player.spell_runtime.energy = clampf(float(saved.get(&"element", {}).get(&"energy", player.spell_runtime.energy)), 0.0, 100.0)
			if player.super_runtime != null:
				var overdrive: Dictionary = saved.get(&"overdrive", {})
				player.super_runtime.charge = maxf(0.0, float(overdrive.get(&"charge", player.super_runtime.charge)))
				player.super_runtime.recovery_remaining = maxf(0.0, float(overdrive.get(&"recovery", 0.0)))
