class_name CommsPortraitLibrary
extends RefCounted

const ATLAS_PATH := "res://assets_runtime/portraits/comms_portrait_atlas.png"
const CELL_SIZE := Vector2(448.0, 448.0)
const CELLS := {
	"command": Vector2i(0, 0),
	"nova": Vector2i(1, 0),
	"kael": Vector2i(2, 0),
	"reyes": Vector2i(3, 0),
	"rook": Vector2i(0, 1),
	"corsair": Vector2i(1, 1),
	"corsair ace": Vector2i(2, 1),
	"wing": Vector2i(3, 1),
}

static var _atlas: Texture2D
static var _cache: Dictionary = {}

static func texture_for_speaker(speaker: String) -> Texture2D:
	var key := speaker.strip_edges().to_lower()
	if key.is_empty(): key = "command"
	if not CELLS.has(key): key = "wing"
	if _cache.has(key): return _cache[key] as Texture2D
	if _atlas == null and ResourceLoader.exists(ATLAS_PATH): _atlas = load(ATLAS_PATH) as Texture2D
	if _atlas == null: return null
	var cell: Vector2i = CELLS[key]
	var texture := AtlasTexture.new()
	texture.atlas = _atlas
	texture.region = Rect2(Vector2(cell) * CELL_SIZE, CELL_SIZE)
	texture.filter_clip = true
	_cache[key] = texture
	return texture
