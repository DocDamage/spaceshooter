class_name EquipmentDefinition
extends ContentDefinition

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var slot: StringName = &"core"
@export var rarity: Rarity = Rarity.COMMON
@export var modifiers: Dictionary = {}
@export var allowed_ship_ids: Array[StringName] = []
@export var sell_value := 0
@export var dismantle_value := 0
@export var duplicate_policy: StringName = &"keep"
@export var set_id: StringName
@export_range(0, 8, 1) var set_bonus_required := 0
@export var set_bonus: Dictionary = {}

func get_content_type() -> StringName:
	return &"equipment"

func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if slot.is_empty(): errors.append("equipment slot is required for %s" % stable_id)
	if sell_value < 0 or dismantle_value < 0: errors.append("equipment values cannot be negative for %s" % stable_id)
	if duplicate_policy not in [&"keep", &"convert", &"reject"]: errors.append("invalid duplicate policy for %s" % stable_id)
	if set_id.is_empty() and (set_bonus_required > 0 or not set_bonus.is_empty()): errors.append("%s defines a set bonus without a set ID" % stable_id)
	if not set_id.is_empty() and set_bonus_required < 2: errors.append("%s equipment sets require at least two pieces" % stable_id)
	return errors
