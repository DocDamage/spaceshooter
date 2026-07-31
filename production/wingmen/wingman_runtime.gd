class_name WingmanRuntime
extends BaseActor2D

signal command_changed(mode: StringName, target_id: StringName)
signal special_used(ability_id: StringName)

const MODES := [&"attack", &"defend", &"focus", &"intercept", &"hold", &"retreat", &"use_special"]

var definition: WingmanDefinition
var actor_slot: ActorSlot
var command_mode: StringName = &"defend"
var command_target_id: StringName
var command_cooldown_remaining := 0.0
var special_cooldown_remaining := 0.0
var respawn_generation := 0
var desired_position := Vector2.ZERO
var velocity := Vector2.ZERO

func configure_wingman(source: WingmanDefinition, slot: ActorSlot, session_registry: ActorRegistry, session_events: TypedEventBus) -> bool:
	if source == null or slot == null: return false
	definition = source; actor_slot = slot; actor_slot.actor = self
	configure_actor(slot.slot_id, &"wingman", &"player", session_registry, session_events)
	health_component.configure(float(source.ai_profile.get("health", 100.0)))
	return true

func _physics_process(delta: float) -> void:
	super(delta)
	command_cooldown_remaining = maxf(0.0, command_cooldown_remaining - delta)
	special_cooldown_remaining = maxf(0.0, special_cooldown_remaining - delta)
	if active and actor_slot != null and actor_slot.controller_kind == &"ai": _tick_ai(delta)

func issue_command(mode: StringName, target_id: StringName = &"") -> bool:
	if definition == null or mode not in MODES or command_cooldown_remaining > 0.0: return false
	if mode == &"use_special": return use_special()
	command_mode = mode; command_target_id = target_id; command_cooldown_remaining = definition.command_cooldown
	command_changed.emit(mode, target_id)
	return true

func use_special() -> bool:
	if definition == null or special_cooldown_remaining > 0.0: return false
	special_cooldown_remaining = definition.special_cooldown
	command_cooldown_remaining = definition.command_cooldown
	special_used.emit(definition.special_ability_id)
	return true

func on_player_respawn(player_position: Vector2) -> void:
	respawn_generation += 1
	position = player_position + Vector2(80.0, 40.0)
	if not active: spawn_actor()
	grant_invulnerability(2.0)
	command_mode = &"defend"

func handoff_to_human(profile_id: StringName) -> void:
	if actor_slot != null: actor_slot.replace_controller(&"human", profile_id)

func handoff_to_ai() -> void:
	if actor_slot != null: actor_slot.replace_controller(&"ai")

func snapshot() -> Dictionary:
	return {"slot_id": actor_slot.slot_id if actor_slot else &"", "ship_id": actor_slot.ship_id if actor_slot else &"", "controller_kind": actor_slot.controller_kind if actor_slot else &"ai", "profile_id": actor_slot.profile_id if actor_slot else &"", "command_mode": command_mode, "command_target_id": command_target_id, "command_cooldown": command_cooldown_remaining, "special_cooldown": special_cooldown_remaining, "position": position, "health": health_component.current, "respawn_generation": respawn_generation}

func restore(state: Dictionary) -> void:
	command_mode = StringName(state.get("command_mode", "defend")); command_target_id = StringName(state.get("command_target_id", ""))
	command_cooldown_remaining = maxf(0.0, float(state.get("command_cooldown", 0.0))); special_cooldown_remaining = maxf(0.0, float(state.get("special_cooldown", 0.0)))
	position = state.get("position", position); health_component.current = clampf(float(state.get("health", health_component.maximum)), 0.0, health_component.maximum)
	respawn_generation = maxi(0, int(state.get("respawn_generation", 0)))
	if actor_slot != null: actor_slot.replace_controller(StringName(state.get("controller_kind", "ai")), StringName(state.get("profile_id", "")))

func _tick_ai(delta: float) -> void:
	match command_mode:
		&"hold": velocity = Vector2.ZERO
		&"retreat": velocity = Vector2(0, 180)
		&"defend": velocity = position.direction_to(desired_position) * float(definition.ai_profile.get("speed", 180.0))
		&"attack", &"focus", &"intercept": velocity = position.direction_to(desired_position) * float(definition.ai_profile.get("speed", 220.0))
	position += velocity * delta
