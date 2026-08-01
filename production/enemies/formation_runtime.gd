class_name FormationRuntime
extends Node2D

signal ordered_kill_bonus(amount: int)
signal formation_completed(amount: int)

var definition: FormationDefinition
var members: Array[ProductionEnemy] = []
var player_count := 1
var elapsed := 0.0
var _next_order_index := 0
var _completed := false

func configure(formation: FormationDefinition, active_player_count := 1) -> void:
	definition = formation
	player_count = maxi(1, active_player_count)

func add_member(member: ProductionEnemy, slot_index: int) -> bool:
	if definition == null or member == null or slot_index < 0 or slot_index >= definition.slots.size(): return false
	while members.size() <= slot_index: members.append(null)
	members[slot_index] = member
	member.formation = self
	member.formation_slot = slot_index
	member.defeated.connect(_on_member_defeated.bind(slot_index), CONNECT_ONE_SHOT)
	member.escaped.connect(_on_member_escaped.bind(slot_index), CONNECT_ONE_SHOT)
	return true

func _physics_process(delta: float) -> void:
	if definition == null or _completed: return
	elapsed += delta
	for index in members.size():
		var member := members[index]
		if is_instance_valid(member) and member.active:
			var offset := definition.slots[index]
			offset.x += signf(offset.x) * definition.multiplayer_spacing * float(player_count - 1)
			member.set_formation_target(global_position + offset)
	if elapsed >= definition.escape_seconds:
		for member in members:
			if is_instance_valid(member) and member.active: member.request_escape()
	_check_completion()

func _on_member_defeated(_actor_id: StringName, _credits: int, slot_index: int) -> void:
	var finished_member: ProductionEnemy = members[slot_index] if slot_index >= 0 and slot_index < members.size() else null
	var escape_callback := _on_member_escaped.bind(slot_index)
	if is_instance_valid(finished_member) and finished_member.escaped.is_connected(escape_callback): finished_member.escaped.disconnect(escape_callback)
	if _next_order_index < definition.ordered_kill_slots.size() and definition.ordered_kill_slots[_next_order_index] == slot_index:
		_next_order_index += 1
		if _next_order_index == definition.ordered_kill_slots.size(): ordered_kill_bonus.emit(definition.ordered_kill_reward)
	else:
		_next_order_index = 0
	if slot_index == definition.leader_slot:
		match definition.loss_behavior:
			&"promote": definition.leader_slot = _first_active_slot()
			&"break":
				for member in members:
					if is_instance_valid(member): member.leave_formation()
			&"collapse": global_position.y += 80.0
	_check_completion()

func _on_member_escaped(_actor_id: StringName, _slot_index: int) -> void:
	var finished_member: ProductionEnemy = members[_slot_index] if _slot_index >= 0 and _slot_index < members.size() else null
	var defeat_callback := _on_member_defeated.bind(_slot_index)
	if is_instance_valid(finished_member) and finished_member.defeated.is_connected(defeat_callback): finished_member.defeated.disconnect(defeat_callback)
	_check_completion()

func _first_active_slot() -> int:
	for index in members.size():
		if is_instance_valid(members[index]) and members[index].active: return index
	return -1

func _check_completion() -> void:
	if _completed: return
	for member in members:
		if is_instance_valid(member) and member.active: return
	_completed = true
	formation_completed.emit(definition.completion_bonus)
