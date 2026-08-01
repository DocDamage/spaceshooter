class_name StageEncounterTimelineDefinition
extends ContentDefinition

@export var mission_id: StringName
@export var beats: Array[StageBeatDefinition] = []

func get_content_type() -> StringName:
	return &"stage_encounter_timeline"

func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if mission_id.is_empty() or beats.is_empty(): errors.append("%s needs a mission and beats" % stable_id)
	var ids := {}
	var previous_start := -1.0
	var primary_count := 0
	for beat in beats:
		if beat == null:
			errors.append("%s contains a missing beat" % stable_id)
			continue
		errors.append_array(beat.validate_definition())
		if ids.has(beat.stable_id): errors.append("%s repeats beat %s" % [stable_id, beat.stable_id])
		ids[beat.stable_id] = true
		if beat.primary_route:
			if beat.start_seconds < previous_start: errors.append("%s primary beats are not chronological" % stable_id)
			previous_start = beat.start_seconds
			primary_count += 1
	for beat in beats:
		if beat == null: continue
		for next_id in beat.next_beat_ids:
			if not ids.has(next_id): errors.append("%s points to missing beat %s" % [beat.stable_id, next_id])
	if primary_count < 2: errors.append("%s needs a primary route" % stable_id)
	return errors

func ordered_primary_beats() -> Array[StageBeatDefinition]:
	var result: Array[StageBeatDefinition] = []
	for beat in beats:
		if beat != null and beat.primary_route: result.append(beat)
	result.sort_custom(func(left, right): return left.start_seconds < right.start_seconds)
	return result

func beat_for_id(beat_id: StringName) -> StageBeatDefinition:
	for beat in beats:
		if beat != null and beat.stable_id == beat_id: return beat
	return null
