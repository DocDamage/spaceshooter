class_name FullCampaignNarrativeFactory
extends RefCounted

const AUTHORED_CONTENT_PATH := "res://production/content/data/campaign/full_campaign_authored_content.json"

static var _authored_content_loaded := false
static var _authored_content: Dictionary = {}

static func authored_stage_content(operation: int, stage: int) -> Dictionary:
	_load_authored_content()
	return _authored_content.get("%d-%d" % [operation, stage], {}).duplicate(true)

static func authored_stage_count() -> int:
	_load_authored_content()
	return _authored_content.size()

static func story_beat(operation: int, stage: int, mechanic: StringName) -> String:
	var authored := authored_stage_content(operation, stage)
	if not authored.is_empty(): return str(authored.get("setup", ""))
	return "%s — %s" % [stage_title(operation, stage, mechanic), String(mechanic).replace("_", " ")]

static func dialogue_definition(operation: int, stage: int, kind: StringName, mechanic: StringName, dialogue_id: StringName) -> DialogueDefinition:
	var dialogue := DialogueDefinition.new()
	dialogue.stable_id = dialogue_id
	dialogue.display_name = "Operation %d Stage %d %s" % [operation, stage, String(kind).capitalize()]
	dialogue.content_version = "21.0"
	dialogue.context = "stage_entry" if kind == &"briefing" else "results"
	dialogue.priority = operation * 10 + stage
	var authored := authored_stage_content(operation, stage)
	if kind == &"briefing":
		dialogue.lines = [
			{"speaker": "Command", "text": str(authored.get("setup", story_beat(operation, stage, mechanic)))},
			{"speaker": "Wing", "text": str(authored.get("wing", "Mission focus: %s." % String(mechanic).replace("_", " ")))}
		]
		var echo: Dictionary = authored.get("decision_echo", {})
		if not echo.is_empty(): dialogue.lines.append({"speaker": "Wing", "text": "Prior decision acknowledged.", "decision_id": StringName(echo.get("decision_id", "")), "variants": echo.get("variants", {}).duplicate(true)})
	else:
		dialogue.lines = [
			{"speaker": "Nova", "text": str(authored.get("result", "%s is secure." % stage_title(operation, stage, mechanic)))},
			{"speaker": "Command", "text": str(authored.get("consequence", "Operation %d progress: %d of 10 stages resolved." % [operation, stage]))}
		]
		var decision := decision_for(operation, stage)
		if not decision.is_empty(): dialogue.lines.append(decision)
	return dialogue

static func stage_title(operation: int, stage: int, mechanic: StringName) -> String:
	var authored := authored_stage_content(operation, stage)
	return str(authored.get("title", "")) if not authored.is_empty() else String(mechanic).replace("_", " ").capitalize()

static func operation_color(operation: int) -> Color:
	return [Color("65b9ff"), Color("bb78ff"), Color("ff9a52"), Color("ff526f"), Color("f5e663")][operation - 2]

static func decision_for(operation: int, stage: int) -> Dictionary:
	if operation == 2 and stage == 10: return {"speaker": "Command", "text": "Which doctrine leads the specialist wings?", "choices": [{"text": "Independent specialists", "decision_id": &"specialist_doctrine", "value": &"independent"}, {"text": "Unified formation", "decision_id": &"specialist_doctrine", "value": &"unified"}]}
	if operation == 3 and stage == 8: return {"speaker": "Kael", "text": "What do we do with the recovered alien archive?", "choices": [{"text": "Share the archive", "decision_id": &"alien_archive", "value": &"shared"}, {"text": "Seal the archive", "decision_id": &"alien_archive", "value": &"sealed"}]}
	if operation == 4 and stage == 5: return {"speaker": "Reyes", "text": "Which faction receives our protection corridor?", "choices": [{"text": "Defend the civilians", "decision_id": &"faction_alliance", "value": &"civilians"}, {"text": "Support the defense fleet", "decision_id": &"faction_alliance", "value": &"fleet"}]}
	if operation == 5 and stage == 10: return {"speaker": "Rook", "text": "The Last Arsenal can be dismantled or turned against the invasion.", "choices": [{"text": "Dismantle it", "decision_id": &"arsenal_fate", "value": &"dismantled"}, {"text": "Use it", "decision_id": &"arsenal_fate", "value": &"deployed"}]}
	if operation == 6 and stage == 10: return {"speaker": "Command", "text": "The invasion is over. Choose what the united fleet builds from the victory.", "choices": [{"text": "Rebuild the frontier", "decision_id": &"final_resolution", "value": &"rebuild"}, {"text": "Guard the convergence", "decision_id": &"final_resolution", "value": &"guard"}]}
	return {}

static func _load_authored_content() -> void:
	if _authored_content_loaded: return
	_authored_content_loaded = true
	var file := FileAccess.open(AUTHORED_CONTENT_PATH, FileAccess.READ)
	if file == null:
		push_error("Authored campaign content is missing: %s" % AUTHORED_CONTENT_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.get("stages") is Dictionary:
		_authored_content = parsed.stages.duplicate(true)
	else:
		push_error("Authored campaign content is invalid: %s" % AUTHORED_CONTENT_PATH)
