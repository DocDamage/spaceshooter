class_name InventoryManager
extends RefCounted

var profile: ProgressionProfile
var definitions: Dictionary = {}

func _init(owner_profile: ProgressionProfile, equipment_definitions: Array[EquipmentDefinition] = []) -> void:
	profile = owner_profile
	for definition in equipment_definitions:
		if definition != null: definitions[definition.stable_id] = definition

func acquire(definition: EquipmentDefinition) -> Dictionary:
	if definition == null: return {"accepted": false, "reason": &"invalid"}
	definitions[definition.stable_id] = definition
	var duplicate := _find_by_definition(definition.stable_id)
	if not duplicate.is_empty() and definition.duplicate_policy == &"reject": return {"accepted": false, "reason": &"duplicate"}
	if not duplicate.is_empty() and definition.duplicate_policy == &"convert":
		profile.currency += definition.dismantle_value
		return {"accepted": true, "converted": true, "currency": definition.dismantle_value}
	var item := {"instance_id": profile.next_item_instance_id(), "definition_id": definition.stable_id, "favorite": false, "locked": false}
	profile.inventory.append(item)
	return {"accepted": true, "converted": false, "item": item.duplicate(true)}

func equip(instance_id: StringName, slot: StringName, ship_id: StringName = &"") -> bool:
	var item := get_item(instance_id)
	if item.is_empty(): return false
	var definition: EquipmentDefinition = definitions.get(item.definition_id)
	if definition == null or definition.slot != slot: return false
	if not definition.allowed_ship_ids.is_empty() and ship_id not in definition.allowed_ship_ids: return false
	profile.equipped[slot] = instance_id
	return true

func set_favorite(instance_id: StringName, value: bool) -> bool:
	for item in profile.inventory:
		if item.instance_id == instance_id: item.favorite = value; return true
	return false

func set_locked(instance_id: StringName, value: bool) -> bool:
	for item in profile.inventory:
		if item.instance_id == instance_id: item.locked = value; return true
	return false

func sell(instance_id: StringName, dismantle := false) -> int:
	var item := get_item(instance_id)
	if item.is_empty() or item.locked or item.favorite or instance_id in profile.equipped.values(): return 0
	var definition: EquipmentDefinition = definitions.get(item.definition_id)
	if definition == null: return 0
	var value := definition.dismantle_value if dismantle else definition.sell_value
	profile.currency += value
	profile.inventory.erase(item)
	return value

func sorted_items(sort_key: StringName = &"rarity", slot_filter: StringName = &"") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in profile.inventory:
		var definition: EquipmentDefinition = definitions.get(item.definition_id)
		if definition != null and (slot_filter.is_empty() or definition.slot == slot_filter): result.append(item.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		var da: EquipmentDefinition = definitions.get(a.definition_id); var db: EquipmentDefinition = definitions.get(b.definition_id)
		if sort_key == &"name": return da.display_name.naturalnocasecmp_to(db.display_name) < 0
		return da.rarity > db.rarity if da.rarity != db.rarity else da.display_name.naturalnocasecmp_to(db.display_name) < 0)
	return result

func save_preset(preset_id: StringName) -> bool:
	if preset_id.is_empty(): return false
	profile.loadout_presets[preset_id] = profile.equipped.duplicate(true)
	return true

func load_preset(preset_id: StringName, ship_id: StringName = &"") -> bool:
	if not profile.loadout_presets.has(preset_id): return false
	var target: Dictionary = profile.loadout_presets[preset_id]
	for slot in target:
		if not equip(target[slot], slot, ship_id): return false
	return true

func equipped_modifiers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var set_counts := {}
	var set_sources := {}
	for instance_id in profile.equipped.values():
		var item := get_item(instance_id); var definition: EquipmentDefinition = definitions.get(item.get("definition_id", &""))
		if definition != null:
			result.append(definition.modifiers)
			if not definition.set_id.is_empty():
				set_counts[definition.set_id] = int(set_counts.get(definition.set_id, 0)) + 1
				set_sources[definition.set_id] = definition
	for set_id in set_counts:
		var source: EquipmentDefinition = set_sources[set_id]
		if int(set_counts[set_id]) >= source.set_bonus_required: result.append(source.set_bonus)
	return result

func get_item(instance_id: StringName) -> Dictionary:
	for item in profile.inventory:
		if item.instance_id == instance_id: return item
	return {}

func _find_by_definition(definition_id: StringName) -> Dictionary:
	for item in profile.inventory:
		if item.definition_id == definition_id: return item
	return {}
