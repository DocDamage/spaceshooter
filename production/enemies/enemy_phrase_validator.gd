class_name EnemyPhraseValidator
extends RefCounted

static func validate_phrase(phrase: AttackPhraseDefinition, playfield := Rect2(0, 0, 540, 960)) -> PackedStringArray:
	var errors := PackedStringArray()
	if phrase == null: return PackedStringArray(["phrase is missing"])
	errors.append_array(phrase.validate_definition())
	if not playfield.encloses(phrase.safe_lane): errors.append("%s safe lane leaves playfield" % phrase.stable_id)
	return errors

static func validate_behavior(score: EnemyBehaviorScoreDefinition) -> PackedStringArray:
	var errors := PackedStringArray()
	if score == null: return PackedStringArray(["behavior score is missing"])
	for phrase in score.phrases: errors.append_array(validate_phrase(phrase))
	return errors

static func fingerprint(score: EnemyBehaviorScoreDefinition, seed: int) -> String:
	if score == null: return ""
	var ids := PackedStringArray()
	for phrase in score.phrases: ids.append(String(phrase.stable_id) if phrase != null else "missing")
	return "%s:%d:%s:%s" % [score.stable_id, seed, score.entry_path.stable_id if score.entry_path != null else "", ",".join(ids)]
