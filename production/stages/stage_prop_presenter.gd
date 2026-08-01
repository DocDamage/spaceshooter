class_name StagePropPresenter
extends Node2D

var timeline: StageEncounterTimelineDefinition
var _active: Array[CanvasItem] = []

func configure(source_timeline: StageEncounterTimelineDefinition) -> void:
	timeline = source_timeline

func present(landmark_ids: Array) -> void:
	_clear()
	if timeline == null: return
	for beat in timeline.beats:
		if beat == null: continue
		for prop in beat.landmarks:
			if prop != null and prop.stable_id in landmark_ids: _add_prop(prop)

func _add_prop(prop: StagePropDefinition) -> void:
	var texture := load(prop.visual_asset_path) as Texture2D
	if texture == null: return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = prop.local_position
	sprite.scale = prop.visual_scale
	sprite.rotation_degrees = prop.rotation_degrees
	sprite.modulate = prop.tint
	sprite.z_index = prop.z_order
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_active.append(sprite)

func _clear() -> void:
	for item in _active:
		if is_instance_valid(item): item.queue_free()
	_active.clear()
