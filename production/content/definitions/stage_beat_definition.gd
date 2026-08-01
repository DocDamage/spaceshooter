class_name StageBeatDefinition
extends Resource

@export var stable_id: StringName
@export var label := ""
@export_range(0.0, 3600.0, 0.1) var start_seconds := 0.0
@export_range(0.1, 3600.0, 0.1) var target_duration_seconds := 15.0
@export var segment: StageSegmentDefinition
@export var primary_route := true
@export var next_beat_ids: Array[StringName] = []
@export var landmarks: Array[StagePropDefinition] = []
@export var encounter_variants: Array[EncounterVariantDefinition] = []
@export var background_zone: StringName = &""
@export var music_state: StringName = &""
@export var dialogue_hook: StringName = &""
@export var practice_id: StringName = &""
@export var variation_ids: Array[StringName] = []
@export var pressure := {"enemy_cap": 8, "projectile_cap": 256, "speed_multiplier": 1.0, "high_attention_roles": 1}

func validate_definition() -> PackedStringArray:
	var errors := PackedStringArray()
	if stable_id.is_empty() or label.strip_edges().is_empty(): errors.append("Stage beat needs an ID and label")
	if segment == null or not segment.validate_definition().is_empty(): errors.append("%s needs a valid stage segment" % stable_id)
	if target_duration_seconds <= 0.0: errors.append("%s needs a positive target duration" % stable_id)
	if background_zone.is_empty() or music_state.is_empty() or practice_id.is_empty(): errors.append("%s needs zone, music, and practice identifiers" % stable_id)
	var roles := int(pressure.get("high_attention_roles", 0))
	if int(pressure.get("enemy_cap", 0)) < 1 or int(pressure.get("projectile_cap", 0)) < 1 or float(pressure.get("speed_multiplier", 0.0)) <= 0.0 or roles < 1 or roles > 2:
		errors.append("%s has an unreadable pressure budget" % stable_id)
	for landmark in landmarks:
		if landmark == null: errors.append("%s has a missing landmark" % stable_id)
	for variant in encounter_variants:
		if variant == null: errors.append("%s has a missing encounter variant" % stable_id)
	return errors

func snapshot(seed_value: int) -> Dictionary:
	var variant := &"base"
	if not variation_ids.is_empty(): variant = variation_ids[posmod(seed_value ^ hash(String(stable_id)), variation_ids.size())]
	var landmark_ids: Array[StringName] = []
	for landmark in landmarks:
		if landmark != null: landmark_ids.append(landmark.stable_id)
	var variant_ids: Array[StringName] = []
	for encounter in encounter_variants:
		if encounter != null: variant_ids.append(encounter.stable_id)
	return {"beat_id": stable_id, "beat_label": label, "timeline_start": start_seconds, "timeline_duration": target_duration_seconds, "background_zone": background_zone, "music_state": music_state, "dialogue_hook": dialogue_hook, "practice_id": practice_id, "landmark_ids": landmark_ids, "encounter_variant_ids": variant_ids, "variation_id": variant, "pressure": pressure.duplicate(true)}
