class_name ProfileContentValidator
extends RefCounted

static func validate(snapshot: Dictionary, database: ContentDatabase) -> Dictionary:
	var warnings := PackedStringArray()
	var missing_required := PackedStringArray()
	var unresolved_optional := PackedStringArray()
	if database == null:
		return {"valid": false, "missing_required": PackedStringArray(["content_database"]), "unresolved_optional": unresolved_optional, "warnings": PackedStringArray(["Content database is unavailable."])}
	for content_id in snapshot.get("unlocked_content", []):
		if not database.has_id(StringName(content_id)):
			unresolved_optional.append(String(content_id))
	for item in snapshot.get("inventory", []):
		if item is Dictionary:
			var definition_id := StringName(item.get("definition_id", ""))
			if not definition_id.is_empty() and not database.has_id(definition_id): unresolved_optional.append(String(definition_id))
	for slot in snapshot.get("equipped", {}):
		var instance_id := StringName(snapshot.equipped[slot])
		if instance_id.is_empty(): continue
		var found := false
		for item in snapshot.get("inventory", []):
			if item is Dictionary and StringName(item.get("instance_id", "")) == instance_id:
				found = true
				var definition_id := StringName(item.get("definition_id", ""))
				if definition_id.is_empty() or not database.has_id(definition_id): missing_required.append("%s:%s" % [slot, definition_id])
				break
		if not found: missing_required.append("%s:%s" % [slot, instance_id])
	if not unresolved_optional.is_empty(): warnings.append("Optional content is unavailable and retained as unresolved data: %s" % ", ".join(unresolved_optional))
	if not missing_required.is_empty(): warnings.append("Required equipped content is unavailable: %s" % ", ".join(missing_required))
	return {"valid": missing_required.is_empty(), "missing_required": missing_required, "unresolved_optional": unresolved_optional, "warnings": warnings}
