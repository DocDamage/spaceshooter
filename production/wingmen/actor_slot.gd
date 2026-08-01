class_name ActorSlot
extends RefCounted

var slot_id: StringName
var profile_id: StringName
var ship_id: StringName
var controller_kind: StringName = &"ai"
var actor: Node

func configure(id: StringName, selected_ship: StringName, kind: StringName = &"ai", selected_profile: StringName = &"") -> ActorSlot:
	slot_id = id; ship_id = selected_ship; controller_kind = kind; profile_id = selected_profile
	return self

func replace_controller(kind: StringName, selected_profile: StringName = &"") -> void:
	controller_kind = kind; profile_id = selected_profile
