class_name HitboxComponent
extends Node

var enabled := true
var collision_damage := 0.0
var damage_type := DamagePacket.DamageType.KINETIC
var radius := 0.0

func configure(hit_radius: float, contact_damage := 0.0, contact_damage_type := DamagePacket.DamageType.KINETIC) -> void:
	radius = maxf(0.0, hit_radius)
	collision_damage = maxf(0.0, contact_damage)
	damage_type = contact_damage_type

func make_collision_packet(source_actor_id: StringName) -> DamagePacket:
	var packet := DamagePacket.new(collision_damage, source_actor_id)
	packet.damage_type = damage_type
	packet.is_collision_damage = true
	return packet
