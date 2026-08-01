class_name SaveSchemaMigrator
extends RefCounted

const CURRENT_VERSION := 9
const CONTENT_RENAMES := {
	"weapon.pulse": "weapon.pulse_cannon",
	"spell.gravity_well_old": "spell.gravity_well",
}

static func migrate(source: Dictionary) -> Dictionary:
	var data := source.duplicate(true)
	var version := int(data.get("schema_version", 0))
	var log: Array[Dictionary] = []
	if version <= 0 or version > CURRENT_VERSION:
		return {"success": false, "message": "Unsupported save schema %d (current is %d)." % [version, CURRENT_VERSION], "data": {}, "log": log}
	while version < CURRENT_VERSION:
		match version:
			8:
				data = _migrate_8_to_9(data)
				log.append({"from": 8, "to": 9, "unix": Time.get_unix_time_from_system()})
				version = 9
			_:
				return {"success": false, "message": "No migration path exists from schema %d." % version, "data": {}, "log": log}
	data.schema_version = CURRENT_VERSION
	return {"success": true, "message": "Save schema is current.", "data": data, "log": log}

static func _migrate_8_to_9(old: Dictionary) -> Dictionary:
	var data := old.duplicate(true)
	data.schema_version = 9
	data.display_name = String(data.get("display_name", String(data.get("profile_id", "Pilot")).replace("profile.", "").capitalize()))
	data.playtime_seconds = maxi(0, int(data.get("playtime_seconds", 0)))
	data.campaign_progress = data.get("campaign_progress", {}).duplicate(true)
	data.last_played_stage = StringName(data.get("last_played_stage", ""))
	data.new_game_plus_cycle = maxi(0, int(data.get("new_game_plus_cycle", 0)))
	data.profile_settings = data.get("profile_settings", {}).duplicate(true)
	for field in ["unlocked_content", "claimed_reward_ids"]:
		var renamed: Array = []
		for content_id in data.get(field, []):
			renamed.append(CONTENT_RENAMES.get(String(content_id), content_id))
		data[field] = renamed
	for field in ["weapon_levels", "spell_levels"]:
		var values: Dictionary = data.get(field, {})
		for old_id in CONTENT_RENAMES:
			if values.has(old_id):
				values[CONTENT_RENAMES[old_id]] = values[old_id]
				values.erase(old_id)
		data[field] = values
	return data
