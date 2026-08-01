class_name HazardFactory
extends RefCounted

const SUPPORTED := [&"hazard.asteroids", &"hazard.debris", &"hazard.ion_storm", &"hazard.minefield", &"hazard.turret_wall", &"hazard.orbital_weapon", &"hazard.crossfire", &"hazard.reactor_arc"]

static func create(hazard_id: StringName, index: int, context: Dictionary) -> StageHazard:
	var hazard := StageHazard.new()
	hazard.name = "Hazard_%s_%d" % [String(hazard_id).trim_prefix("hazard."), index]
	hazard.configure_hazard(hazard_id if hazard_id in SUPPORTED else &"hazard.debris", index, context)
	return hazard
