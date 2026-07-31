class_name CodexEntryDefinition
extends ContentDefinition

const CATEGORIES := [&"factions", &"pilots", &"wingmen", &"ships", &"enemies", &"bosses", &"weapons", &"spells", &"locations", &"historical_events", &"technology"]

@export_enum("factions", "pilots", "wingmen", "ships", "enemies", "bosses", "weapons", "spells", "locations", "historical_events", "technology") var category := "technology"
@export_multiline var body := ""
@export var portrait_id: StringName
@export var unlock_rule: Dictionary = {}

func get_content_type() -> StringName:
	return &"codex_entry"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if StringName(category) not in CATEGORIES: errors.append("%s has an invalid codex category" % stable_id)
	if body.is_empty(): errors.append("%s requires body text" % stable_id)
	return errors
