class_name MissionBackdrop
extends CanvasLayer

const VIEW_SIZE := Vector2(540.0, 960.0)
const SHEET_LAYER_COUNT := 5
const MOTION_RATIOS := [0.025, 0.055, 0.095, 0.15, 0.23]
const LAYER_TINTS := [
	Color(0.72, 0.78, 0.9, 1.0),
	Color(0.8, 0.86, 1.0, 0.72),
	Color(0.88, 0.94, 1.0, 0.72),
	Color(0.92, 0.97, 1.0, 0.62),
	Color(1.0, 1.0, 1.0, 0.52),
]

var settings: SettingsService
var operation := 1
var source_texture: Texture2D
var motion_layers: Array[Node2D] = []
var motion_offsets: Array[float] = []
var motion_ratios: Array[float] = []
var tile_height := 540.0
var current_zone: StringName
var zone_overlay: ColorRect

func _ready() -> void:
	_align_playfield()
	if not get_viewport().size_changed.is_connected(_align_playfield): get_viewport().size_changed.connect(_align_playfield)

func configure(asset_path: String, operation_index: int, settings_service: SettingsService = null) -> void:
	settings = settings_service
	operation = clampi(operation_index, 1, 6)
	layer = -20
	follow_viewport_enabled = false
	if not asset_path.is_empty() and ResourceLoader.exists(asset_path):
		source_texture = load(asset_path) as Texture2D
	_build()

func _process(delta: float) -> void:
	if motion_layers.is_empty(): return
	var reduction := float(settings.get_setting(&"background_motion_reduction", 0.0)) if settings != null else 0.0
	var motion_scale := 1.0 - clampf(reduction, 0.0, 1.0)
	if reduction >= 0.95: motion_scale = 0.08
	for index in motion_layers.size():
		motion_offsets[index] = fposmod(motion_offsets[index] + 120.0 * motion_ratios[index] * motion_scale * delta, tile_height)
		motion_layers[index].position.y = motion_offsets[index]

func _build() -> void:
	for child in get_children(): child.queue_free()
	motion_layers.clear()
	motion_offsets.clear()
	motion_ratios.clear()
	var base := ColorRect.new()
	base.color = _operation_color(operation)
	base.position = Vector2.ZERO
	base.size = VIEW_SIZE
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	_add_star_layer(46, Color(0.48, 0.78, 1.0, 0.34), 0.018, 2)
	if source_texture != null:
		var size := source_texture.get_size()
		if size.x > 0.0 and size.y >= size.x * 4.9:
			_build_vertical_layer_sheet(size)
		else:
			_build_single_texture(size)
	_add_star_layer(24, _operation_accent(operation), 0.2, 7)
	zone_overlay = ColorRect.new()
	zone_overlay.color = Color(0.005, 0.018, 0.045, 0.22)
	zone_overlay.position = Vector2.ZERO
	zone_overlay.size = VIEW_SIZE
	zone_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(zone_overlay)

func set_zone(zone_id: StringName) -> bool:
	if zone_id.is_empty() or zone_id == current_zone: return false
	current_zone = zone_id
	if zone_overlay == null: return true
	var tint := Color(0.005, 0.018, 0.045, 0.22)
	match zone_id:
		&"planet_horizon": tint = Color(0.06, 0.13, 0.22, 0.24)
		&"relay_approach", &"relay_core", &"relay_hidden_lane": tint = Color(0.04, 0.21, 0.30, 0.24)
		&"debris_belt", &"orbit_breakup": tint = Color(0.17, 0.10, 0.04, 0.24)
		&"carrier_approach", &"carrier_arena": tint = Color(0.20, 0.03, 0.08, 0.25)
	var tween := create_tween()
	tween.tween_property(zone_overlay, "color", tint, 0.22)
	return true

func _build_vertical_layer_sheet(size: Vector2) -> void:
	var cell_size := size.x
	tile_height = VIEW_SIZE.x
	var count := mini(SHEET_LAYER_COUNT, int(floor(size.y / cell_size)))
	for index in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = source_texture
		atlas.region = Rect2(0.0, float(index) * cell_size, cell_size, cell_size)
		_add_tiled_texture_layer(atlas, float(MOTION_RATIOS[index]), LAYER_TINTS[index], index)

func _build_single_texture(size: Vector2) -> void:
	if size.x <= 0.0 or size.y <= 0.0: return
	tile_height = 720.0
	_add_tiled_texture_layer(source_texture, 0.045, Color(0.74, 0.82, 1.0, 0.68), 0, tile_height)

func _add_tiled_texture_layer(texture: Texture2D, ratio: float, tint: Color, order: int, display_width := 540.0) -> void:
	var root := Node2D.new()
	root.name = "BackdropLayer%d" % order
	root.z_index = order + 1
	add_child(root)
	motion_layers.append(root)
	motion_offsets.append(0.0)
	motion_ratios.append(ratio)
	var source_size := texture.get_size()
	var scale_factor := display_width / maxf(1.0, source_size.x)
	for tile_index in range(-1, 3):
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = true
		sprite.position = Vector2(VIEW_SIZE.x * 0.5, (float(tile_index) + 0.5) * tile_height)
		sprite.scale = Vector2.ONE * scale_factor
		sprite.modulate = tint
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		root.add_child(sprite)

func _add_star_layer(count: int, color: Color, ratio: float, seed_offset: int) -> void:
	var root := Node2D.new()
	root.name = "ProceduralStars%d" % seed_offset
	root.z_index = 7 + seed_offset
	add_child(root)
	motion_layers.append(root)
	motion_offsets.append(0.0)
	motion_ratios.append(ratio)
	for tile_index in range(-1, 3):
		var tile := BackdropStarTile.new()
		tile.position.y = float(tile_index) * tile_height
		tile.configure(count, color, operation * 101 + seed_offset)
		root.add_child(tile)

func _operation_color(index: int) -> Color:
	return [Color("061121"), Color("061121"), Color("061a31"), Color("170b2a"), Color("2b1209"), Color("290712"), Color("211d08")][clampi(index, 0, 6)]

func _operation_accent(index: int) -> Color:
	return [Color("8edcff"), Color("8edcff"), Color("66dfff"), Color("d49aff"), Color("ffb16f"), Color("ff7896"), Color("fff07b")][clampi(index, 0, 6)]

func _align_playfield() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	offset = Vector2(maxf(0.0, (viewport_size.x - VIEW_SIZE.x) * 0.5), maxf(0.0, (viewport_size.y - VIEW_SIZE.y) * 0.5))

class BackdropStarTile:
	extends Node2D
	const TILE_SIZE := Vector2(540.0, 540.0)

	var count := 40
	var star_color := Color.WHITE
	var seed_value := 1

	func configure(value: int, color: Color, seed: int) -> void:
		count = value
		star_color = color
		seed_value = seed
		queue_redraw()

	func _draw() -> void:
		for index in count:
			var x := float(posmod(index * 137 + seed_value * 43, int(TILE_SIZE.x - 8.0))) + 4.0
			var y := float(posmod(index * 211 + seed_value * 71, int(TILE_SIZE.y - 8.0))) + 4.0
			var radius := 0.65 + float(posmod(index + seed_value, 4)) * 0.38
			draw_circle(Vector2(x, y), radius, star_color)
