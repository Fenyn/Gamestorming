extends Node
## Read-only access to the built data files. Loaded once at startup.

const KANJI_PATH: String = "res://data/kanji.json"
const PARTS_PATH: String = "res://data/parts.json"
const WORDS_PATH: String = "res://data/words.json"
const ZONES_PATH: String = "res://data/zones.json"
const STROKES_PATH: String = "res://data/strokes.json"
const ATLAS_PATH: String = "res://data/glyph_atlas.json"
const GLYPHS_TEXTURE_PATH: String = "res://assets/glyphs/glyphs.png"

var kanji: Array = []
var kanji_by_ch: Dictionary = {}
var parts: Array = []
var parts_by_id: Dictionary = {}
var words: Array = []
var words_by_word: Dictionary = {}
var zones: Array = []
var zone_by_id: Dictionary = {}

var _strokes: Dictionary = {}
var _atlas_cells: Dictionary = {}
var _atlas_cell: int = 32
var _atlas_texture: Texture2D
var _glyph_cache: Dictionary = {}


func _ready() -> void:
	_atlas_texture = load(GLYPHS_TEXTURE_PATH)
	kanji = _load_json(KANJI_PATH)
	for entry in kanji:
		var k: Dictionary = entry
		kanji_by_ch[k["ch"]] = k
	parts = _load_json(PARTS_PATH)
	for entry in parts:
		var p: Dictionary = entry
		parts_by_id[p["id"]] = p
	words = _load_json(WORDS_PATH)
	for entry in words:
		var w: Dictionary = entry
		words_by_word[w["word"]] = w
	var zone_file: Dictionary = _load_json(ZONES_PATH)
	zones = zone_file["zones"]
	for entry in zones:
		var z: Dictionary = entry
		zone_by_id[z["id"]] = z
	_strokes = _load_json(STROKES_PATH)
	var atlas: Dictionary = _load_json(ATLAS_PATH)
	_atlas_cells = atlas["cells"]
	_atlas_cell = int(atlas["cell"])


func _load_json(path: String) -> Variant:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed != null, "could not parse " + path)
	return parsed


## Strokes for a code point, as polylines in KanjiVG's 109 box. Empty when KanjiVG has none.
func strokes_for(cp: String) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if not _strokes.has(cp):
		return out
	for stroke in _strokes[cp]:
		out.append(StrokeCheck.from_json(stroke))
	return out


## The 32 px ink glyph for a code point, cut from the atlas.
func glyph_for(cp: String) -> Texture2D:
	if _glyph_cache.has(cp):
		return _glyph_cache[cp]
	if not _atlas_cells.has(cp):
		return null
	var cell: Array = _atlas_cells[cp]
	var tex: AtlasTexture = AtlasTexture.new()
	tex.atlas = _atlas_texture
	tex.region = Rect2(int(cell[0]) * _atlas_cell, int(cell[1]) * _atlas_cell, _atlas_cell, _atlas_cell)
	_glyph_cache[cp] = tex
	return tex


func zone_tint(zone_id: String) -> Color:
	if not zone_by_id.has(zone_id):
		return Color.WHITE
	return Color.html(zone_by_id[zone_id]["tint"])


func zone_name(zone_id: String) -> String:
	if not zone_by_id.has(zone_id):
		return zone_id
	return zone_by_id[zone_id]["name"]


func part_glyph_cp(part_id: String) -> String:
	if parts_by_id.has(part_id):
		return parts_by_id[part_id]["cp"]
	if kanji_by_ch.has(part_id):
		return kanji_by_ch[part_id]["cp"]
	return ""


func part_name(part_id: String) -> String:
	if parts_by_id.has(part_id):
		return parts_by_id[part_id]["name"]
	if kanji_by_ch.has(part_id):
		return kanji_by_ch[part_id]["keyword"]
	return part_id
