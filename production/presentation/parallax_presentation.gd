class_name ParallaxPresentation
extends Node2D

const VALID_LAYERS := [&"far_background", &"middle_background", &"near_background", &"foreground_flyover", &"particles", &"environment_lighting"]

var definitions: Array[BackgroundLayerDefinition] = []
var offsets: Dictionary = {}
var settings: SettingsService

func configure(layers: Array[BackgroundLayerDefinition], settings_service: SettingsService = null) -> void:
	definitions = layers
	settings = settings_service
	for definition in definitions:
		offsets[definition.stable_id] = Vector2.ZERO
	_build_layers()

func tick(delta: float, world_velocity := Vector2(0.0, 120.0)) -> void:
	var reduction := float(settings.get_setting(&"background_motion_reduction", 0.0)) if settings != null else 0.0
	for definition in definitions:
		var speed := definition.scroll_ratio * world_velocity * (1.0 - reduction)
		if reduction >= 0.95: speed = definition.reduced_motion_scroll_ratio * world_velocity
		var next: Vector2 = offsets.get(definition.stable_id, Vector2.ZERO) + speed * delta
		if definition.loop_behavior == &"wrap":
			next.x = fposmod(next.x, maxf(1.0, definition.loop_size.x))
			next.y = fposmod(next.y, maxf(1.0, definition.loop_size.y))
		offsets[definition.stable_id] = next
		var node := get_node_or_null(String(definition.stable_id)) as Node2D
		if node != null: node.position = next

func _build_layers() -> void:
	for child in get_children(): child.queue_free()
	for definition in definitions:
		var layer := Node2D.new()
		layer.name = String(definition.stable_id)
		layer.z_index = definition.z_order
		if not definition.visual_asset_path.is_empty() and ResourceLoader.exists(definition.visual_asset_path):
			var sprite := Sprite2D.new(); sprite.texture = load(definition.visual_asset_path); layer.add_child(sprite)
		add_child(layer)
