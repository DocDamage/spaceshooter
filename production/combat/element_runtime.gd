class_name ElementRuntime
extends Node

signal activated(element_id: StringName, result: Dictionary)

var spell_runtime: SpellRuntime
var active_element: SpellDefinition
var conversion_service: BulletConversionService

func configure(runtime: SpellRuntime, element: SpellDefinition, converter: BulletConversionService = null) -> void:
	spell_runtime = runtime
	active_element = element
	conversion_service = converter

func activate(targets: Array[Node], projectiles: Array[ProductionProjectile]) -> Dictionary:
	if spell_runtime == null or active_element == null: return {&"success": false, &"reason": &"no_element"}
	if spell_runtime.energy < active_element.energy_cost or float(spell_runtime.cooldowns.get(active_element.stable_id, 0.0)) > 0.0:
		return spell_runtime.cast(active_element, targets, projectiles)
	var converted := conversion_service.convert_projectiles(projectiles, spell_runtime.owner_actor.actor_id, active_element.radius) if active_element.element_role == SpellDefinition.ElementRole.CONTROL and conversion_service != null else 0
	var result := spell_runtime.cast(active_element, targets, projectiles)
	if bool(result.get(&"success", false)): result[&"flux_converted"] = converted
	activated.emit(active_element.stable_id, result)
	return result

func snapshot() -> Dictionary:
	return {&"element_id": active_element.stable_id if active_element != null else &"", &"energy": spell_runtime.energy if spell_runtime != null else 0.0}
