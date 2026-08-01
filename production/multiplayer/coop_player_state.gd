class_name CoopPlayerState
extends RefCounted

var slot_id: StringName
var actor_id: StringName
var lives := 3
var revives_remaining := 2
var downed := false
var eliminated := false
var revive_progress := 0.0
var revive_required := 2.0

func configure(participant: Dictionary, starting_lives: int, revive_limit: int, revive_seconds: float) -> void:
	slot_id = StringName(participant.slot_id)
	actor_id = StringName(participant.actor_id)
	lives = maxi(1, starting_lives)
	revives_remaining = maxi(0, revive_limit)
	revive_required = maxf(0.25, revive_seconds)

func down(can_be_revived: bool) -> bool:
	if eliminated or downed: return false
	if can_be_revived and revives_remaining > 0:
		downed = true
		revive_progress = 0.0
		return true
	lives -= 1
	eliminated = lives <= 0
	downed = not eliminated
	return downed

func advance_revive(delta: float) -> bool:
	if not downed or eliminated or revives_remaining <= 0: return false
	revive_progress += maxf(0.0, delta)
	if revive_progress < revive_required: return false
	revives_remaining -= 1
	downed = false
	revive_progress = 0.0
	return true

func snapshot() -> Dictionary:
	return {"slot_id": slot_id, "actor_id": actor_id, "lives": lives, "revives_remaining": revives_remaining, "downed": downed, "eliminated": eliminated, "revive_progress": revive_progress}

func restore(data: Dictionary) -> bool:
	if StringName(data.get("slot_id", "")) != slot_id or StringName(data.get("actor_id", "")) != actor_id: return false
	lives = maxi(0, int(data.get("lives", lives)))
	revives_remaining = maxi(0, int(data.get("revives_remaining", revives_remaining)))
	downed = bool(data.get("downed", false))
	eliminated = bool(data.get("eliminated", false))
	revive_progress = maxf(0.0, float(data.get("revive_progress", 0.0)))
	return true
