class_name DamagePacket
extends RefCounted

enum DamageType { KINETIC, ENERGY, EXPLOSIVE, FIRE, ICE, ELECTRIC, CORROSIVE, TRUE }
enum ShieldInteraction { NORMAL, BYPASS, PARTIAL_PENETRATION, REFLECT, ABSORB }

var source_actor_id: StringName
var source_ability_id: StringName
var source_player_id: StringName
var base_damage: float
var damage_type: DamageType
var is_critical: bool
var critical_multiplier: float
var armor_penetration: float
var shield_interaction: ShieldInteraction
var shield_penetration: float
var is_collision_damage: bool
var status_applications: Array[StatusApplication]
var chain_attribution: StringName
var score_attribution: StringName
var network_sequence_id: int

func _init(damage := 0.0, source_id: StringName = &"") -> void:
	base_damage = maxf(0.0, damage)
	source_actor_id = source_id
	source_ability_id = &""
	source_player_id = &""
	damage_type = DamageType.KINETIC
	is_critical = false
	critical_multiplier = 1.5
	armor_penetration = 0.0
	shield_interaction = ShieldInteraction.NORMAL
	shield_penetration = 0.0
	is_collision_damage = false
	status_applications = []
	chain_attribution = &""
	score_attribution = &""
	network_sequence_id = 0

func duplicate_packet() -> DamagePacket:
	var copy := DamagePacket.new(base_damage, source_actor_id)
	copy.source_ability_id = source_ability_id
	copy.source_player_id = source_player_id
	copy.damage_type = damage_type
	copy.is_critical = is_critical
	copy.critical_multiplier = critical_multiplier
	copy.armor_penetration = armor_penetration
	copy.shield_interaction = shield_interaction
	copy.shield_penetration = shield_penetration
	copy.is_collision_damage = is_collision_damage
	copy.status_applications.assign(status_applications)
	copy.chain_attribution = chain_attribution
	copy.score_attribution = score_attribution
	copy.network_sequence_id = network_sequence_id
	return copy
