class_name Yard
extends Node2D
## The sanctuary grounds: zone rectangles, spirits, flower beds, the gate.

signal spirit_clicked(spirit: Spirit)
signal flower_clicked(flower: Flower)
signal light_clicked(index: int, is_seed: bool)
signal place_clicked(zone_id: String)

const CELL: Vector2 = Vector2(420, 300)
const LAYOUT: Dictionary = {
	"sky": Rect2i(0, 0, 1, 1), "grove": Rect2i(1, 0, 1, 1), "hill": Rect2i(2, 0, 1, 1), "beasts": Rect2i(3, 0, 1, 1),
	"pond": Rect2i(0, 1, 1, 1), "meadow": Rect2i(1, 1, 2, 1), "house": Rect2i(3, 1, 1, 1),
	"loom": Rect2i(0, 2, 1, 1), "hearth": Rect2i(1, 2, 1, 1), "hall": Rect2i(2, 2, 1, 1), "body": Rect2i(3, 2, 1, 1),
	"forge": Rect2i(0, 3, 1, 1), "path": Rect2i(1, 3, 1, 1),
}
const GATE: Rect2i = Rect2i(2, 3, 2, 1)
const SPIRIT_SLOT: Vector2 = Vector2(42, 48)
const FLOWER_SLOT: Vector2 = Vector2(20, 28)
const BED_RATIO: float = 0.42
const ZONE_MARGIN: Vector2 = Vector2(24, 36)
const BED_MARGIN: Vector2 = Vector2(12, 8)
const LIGHT_SPACING: float = 30.0
const GRASS: Color = Color("4f6b3a")
const SOIL: Color = Color("5a4a34")
const WOODS: Color = Color("27391f")
const WOODS_EDGE: Color = Color("1d2b17")
const NAME_COLOR: Color = Color(1, 1, 1, 0.55)
const HIGHLIGHT: Color = Color("f2d06b")
const TORII: Color = Color("b8402a")
const TINT_MIX: float = 0.22

const PACK_DIR: String = "res://assets/packs/mana_seed/"
const FOREST_SHEET: String = PACK_DIR + "gentle_forest.png"
const TREES_SHEET: String = PACK_DIR + "gentle_trees.png"
const TILE: int = 16
const WOODS_MARGIN: int = 400
const GRASS_TILES: Array[Vector2i] = [Vector2i(1, 5), Vector2i(2, 5), Vector2i(1, 6), Vector2i(2, 6)]
const GRASS_DETAIL_TILES: Array[Vector2i] = []
const GRASS_DETAIL_EVERY: int = 0
const DIRT_TILES: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]
const WATER_TILES: Array[Vector2i] = [Vector2i(1, 9), Vector2i(2, 9), Vector2i(1, 10), Vector2i(2, 10)]
const POND_POOL: Rect2 = Rect2(0.3, 0.12, 0.4, 0.3)
const TREE_SIZE: Vector2i = Vector2i(80, 96)
const TREE_VARIANTS: int = 2
const TREES_PER_CELL: int = 6

@export var spirit_scene: PackedScene
@export var flower_scene: PackedScene
@export var light_scene: PackedScene
@export var name_font: Font
@export var name_size: int = 16

var spirits: Dictionary = {}
var flowers: Dictionary = {}
var placing_zone: String = ""

@onready var _ground: TileMapLayer = %Ground
@onready var _woods: TileMapLayer = %Woods
@onready var _water: TileMapLayer = %Water
@onready var _beds: TileMapLayer = %Beds
@onready var _trees_root: Node2D = %Trees
@onready var _spirits_root: Node2D = %Spirits
@onready var _flowers_root: Node2D = %Flowers
@onready var _lights_root: Node2D = %Lights

var _zone_spirits: Dictionary = {}
var _zone_flowers: Dictionary = {}
var _lights: Array[GateLight] = []
var _tiles_ready: bool = false
var _tree_texture: Texture2D


func _ready() -> void:
	_setup_tiles()


## Builds the tile set from the Mana Seed sheet when the pack is present. Flat colours otherwise.
func _setup_tiles() -> void:
	if not ResourceLoader.exists(FOREST_SHEET):
		return
	var sheet: Texture2D = load(FOREST_SHEET)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = sheet
	source.texture_region_size = Vector2i(TILE, TILE)
	for cell in GRASS_TILES + GRASS_DETAIL_TILES + DIRT_TILES + WATER_TILES:
		source.create_tile(cell)
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_source(source, 0)
	for layer in [_ground, _woods, _water, _beds]:
		var l: TileMapLayer = layer
		l.tile_set = tile_set
	if ResourceLoader.exists(TREES_SHEET):
		_tree_texture = load(TREES_SHEET)
	_tiles_ready = true


# ---------------------------------------------------------------- geometry

func zone_rect(zone_id: String) -> Rect2:
	var r: Rect2i = LAYOUT[zone_id]
	return Rect2(Vector2(r.position) * CELL, Vector2(r.size) * CELL)


func gate_rect() -> Rect2:
	return Rect2(Vector2(GATE.position) * CELL, Vector2(GATE.size) * CELL)


func gate_position() -> Vector2:
	return gate_rect().get_center()


func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, CELL * Vector2(4, 4))


func is_open(zone_id: String) -> bool:
	return int(_zone_spirits.get(zone_id, 0)) > 0


func _spirit_slot(zone_id: String, index: int) -> Vector2:
	var r: Rect2 = zone_rect(zone_id)
	var field_h: float = r.size.y * (1.0 - BED_RATIO)
	var cols: int = maxi(1, int((r.size.x - ZONE_MARGIN.x * 2.0) / SPIRIT_SLOT.x))
	var rows: int = maxi(1, int((field_h - ZONE_MARGIN.y) / SPIRIT_SLOT.y))
	var col: int = index % cols
	var row: int = (index / cols) % rows
	var jitter: Vector2 = Vector2(float((index * 7) % 9) - 4.0, float((index * 5) % 7) - 3.0)
	return r.position + ZONE_MARGIN + Vector2(col, row) * SPIRIT_SLOT + SPIRIT_SLOT * 0.5 + jitter


func _flower_slot(zone_id: String, index: int) -> Vector2:
	var r: Rect2 = zone_rect(zone_id)
	var bed_top: float = r.position.y + r.size.y * (1.0 - BED_RATIO)
	var cols: int = maxi(1, int((r.size.x - BED_MARGIN.x * 2.0) / FLOWER_SLOT.x))
	var rows: int = maxi(1, int((r.size.y * BED_RATIO - BED_MARGIN.y) / FLOWER_SLOT.y))
	var col: int = index % cols
	var row: int = (index / cols) % rows
	return Vector2(r.position.x + BED_MARGIN.x, bed_top + BED_MARGIN.y) + Vector2(col, row) * FLOWER_SLOT + Vector2(FLOWER_SLOT.x * 0.5, FLOWER_SLOT.y)


# ---------------------------------------------------------------- building

func rebuild() -> void:
	for child in _spirits_root.get_children():
		child.queue_free()
	for child in _flowers_root.get_children():
		child.queue_free()
	spirits.clear()
	flowers.clear()
	_zone_spirits.clear()
	_zone_flowers.clear()
	for entry in Data.kanji:
		var k: Dictionary = entry
		if Progress.is_known(Progress.kanji_key(k["ch"])):
			add_spirit(k)
	for entry in Data.words:
		var w: Dictionary = entry
		if Progress.is_known(Progress.word_key(w["word"])):
			add_flower(w)
	_refresh_tiles()
	queue_redraw()


func add_spirit(k: Dictionary) -> Spirit:
	var zone: String = k["zone"]
	var index: int = int(_zone_spirits.get(zone, 0))
	_zone_spirits[zone] = index + 1
	if index == 0:
		_refresh_tiles()
	var spirit: Spirit = spirit_scene.instantiate()
	spirit.position = _spirit_slot(zone, index)
	_spirits_root.add_child(spirit)
	spirit.setup(k)
	spirit.set_stage(Progress.stage_of(Progress.kanji_key(k["ch"])))
	spirit.clicked.connect(func(s: Spirit) -> void: spirit_clicked.emit(s))
	spirits[k["ch"]] = spirit
	queue_redraw()
	return spirit


func add_flower(w: Dictionary) -> Flower:
	var zone: String = w["zone"]
	var index: int = int(_zone_flowers.get(zone, 0))
	_zone_flowers[zone] = index + 1
	var flower: Flower = flower_scene.instantiate()
	flower.position = _flower_slot(zone, index)
	_flowers_root.add_child(flower)
	flower.setup(w)
	flower.set_stage(Progress.stage_of(Progress.word_key(w["word"])))
	flower.clicked.connect(func(f: Flower) -> void: flower_clicked.emit(f))
	flowers[w["word"]] = flower
	return flower


## Marks due items with a bubble and overdue ones as dim or drooping.
func refresh_states(due: Array[String], today: int) -> void:
	for ch in spirits:
		var spirit: Spirit = spirits[ch]
		spirit.set_stage(Progress.stage_of(spirit.key))
		spirit.set_hungry(due.has(spirit.key))
		spirit.set_dim(Progress.is_overdue(spirit.key, today))
	for word in flowers:
		var flower: Flower = flowers[word]
		flower.set_stage(Progress.stage_of(flower.key))
		flower.set_hungry(due.has(flower.key))
		flower.set_droop(Progress.is_overdue(flower.key, today))


func set_lights(count: int, seed_light: bool) -> void:
	for light in _lights:
		light.queue_free()
	_lights.clear()
	var total: int = count + (1 if seed_light else 0)
	var center: Vector2 = gate_position() + Vector2(0, -20)
	for i in range(total):
		var light: GateLight = light_scene.instantiate()
		light.is_seed = seed_light and i == total - 1
		light.position = center + Vector2((float(i) - float(total - 1) * 0.5) * LIGHT_SPACING, 0)
		_lights_root.add_child(light)
		light.clicked.connect(_on_light_clicked)
		_lights.append(light)


func _on_light_clicked(light: GateLight) -> void:
	light_clicked.emit(_lights.find(light), light.is_seed)


func light_count() -> int:
	return _lights.size()


# ---------------------------------------------------------------- placing

func begin_placing(zone_id: String) -> void:
	placing_zone = zone_id
	queue_redraw()


func end_placing() -> void:
	placing_zone = ""
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if placing_zone == "":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if zone_rect(placing_zone).has_point(get_global_mouse_position()):
			place_clicked.emit(placing_zone)
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- tiles

static func _pick(cells: Array[Vector2i], x: int, y: int) -> Vector2i:
	var h: int = ((x * 73856093) ^ (y * 19349663)) & 0x7FFFFFFF
	return cells[h % cells.size()]


func _bed_rect(zone_id: String) -> Rect2:
	var r: Rect2 = zone_rect(zone_id)
	return Rect2(r.position + Vector2(0, r.size.y * (1.0 - BED_RATIO)), Vector2(r.size.x, r.size.y * BED_RATIO)).grow_individual(-8, 0, -8, -8)


func _fill(layer: TileMapLayer, rect: Rect2, cells: Array[Vector2i], detail: Array[Vector2i] = [], detail_every: int = 0) -> void:
	var x0: int = floori(rect.position.x / TILE)
	var y0: int = floori(rect.position.y / TILE)
	var x1: int = ceili(rect.end.x / TILE)
	var y1: int = ceili(rect.end.y / TILE)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var use_detail: bool = detail_every > 0 and (((x * 31 + y * 17) ^ (x * y)) % detail_every) == 0
			var cell: Vector2i = _pick(detail, x, y) if use_detail else _pick(cells, x, y)
			layer.set_cell(Vector2i(x, y), 0, cell)


func _clear(layer: TileMapLayer, rect: Rect2) -> void:
	var x0: int = floori(rect.position.x / TILE)
	var y0: int = floori(rect.position.y / TILE)
	var x1: int = ceili(rect.end.x / TILE)
	var y1: int = ceili(rect.end.y / TILE)
	for y in range(y0, y1):
		for x in range(x0, x1):
			layer.erase_cell(Vector2i(x, y))


func _refresh_tiles() -> void:
	if not _tiles_ready:
		return
	var outer: Rect2 = world_rect().grow(WOODS_MARGIN)
	_ground.clear()
	_woods.clear()
	_water.clear()
	_beds.clear()
	for child in _trees_root.get_children():
		child.queue_free()
	_fill(_ground, outer, GRASS_TILES, GRASS_DETAIL_TILES, GRASS_DETAIL_EVERY)
	_fill(_woods, outer, GRASS_TILES)
	_clear(_woods, gate_rect())
	for zone_id in LAYOUT:
		var zid: String = zone_id
		var r: Rect2 = zone_rect(zid)
		if is_open(zid):
			_clear(_woods, r)
			_fill(_beds, _bed_rect(zid), DIRT_TILES)
			if zid == "pond":
				var pool: Rect2 = Rect2(r.position + POND_POOL.position * r.size, POND_POOL.size * r.size)
				_fill(_water, pool, WATER_TILES)
		else:
			_plant_trees(r)
	var band: Rect2 = outer
	_plant_trees(Rect2(band.position, Vector2(band.size.x, WOODS_MARGIN)))
	_plant_trees(Rect2(Vector2(band.position.x, world_rect().end.y), Vector2(band.size.x, WOODS_MARGIN)))
	_plant_trees(Rect2(band.position + Vector2(0, WOODS_MARGIN), Vector2(WOODS_MARGIN, world_rect().size.y)))
	_plant_trees(Rect2(Vector2(world_rect().end.x, band.position.y + WOODS_MARGIN), Vector2(WOODS_MARGIN, world_rect().size.y)))


func _plant_trees(rect: Rect2) -> void:
	if _tree_texture == null:
		return
	var cells: int = maxi(1, int(rect.get_area() / CELL.x / CELL.y))
	var count: int = TREES_PER_CELL * cells
	var inner: Rect2 = rect.grow_individual(-TREE_SIZE.x * 0.5, -TREE_SIZE.y * 0.5, -TREE_SIZE.x * 0.5, -TREE_SIZE.y * 0.5)
	if inner.size.x <= 0 or inner.size.y <= 0:
		return
	var seed_x: int = int(rect.position.x)
	var seed_y: int = int(rect.position.y)
	for i in range(count):
		var h: int = ((seed_x + i * 7919) * 73856093 ^ (seed_y + i * 104729) * 19349663) & 0x7FFFFFFF
		var pos: Vector2 = inner.position + Vector2(float(h % int(inner.size.x)), float((h / 7919) % int(inner.size.y)))
		var tree: Sprite2D = Sprite2D.new()
		tree.texture = _tree_texture
		tree.region_enabled = true
		tree.region_rect = Rect2(Vector2(TREE_SIZE.x * (h % TREE_VARIANTS), 0), Vector2(TREE_SIZE))
		tree.position = pos
		tree.offset = Vector2(0, -TREE_SIZE.y * 0.5 + 8)
		_trees_root.add_child(tree)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not _tiles_ready:
		draw_rect(world_rect().grow(WOODS_MARGIN), WOODS_EDGE)
	for zone_id in LAYOUT:
		var zid: String = zone_id
		var r: Rect2 = zone_rect(zid)
		if is_open(zid) or zid == placing_zone:
			if not _tiles_ready:
				draw_rect(r, GRASS.lerp(Data.zone_tint(zid), TINT_MIX))
				draw_rect(_bed_rect(zid), SOIL)
			if name_font:
				draw_string(name_font, r.position + Vector2(10, 24), Data.zone_name(zid), HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, NAME_COLOR)
		elif not _tiles_ready:
			draw_rect(r, WOODS)
	var g: Rect2 = gate_rect()
	if not _tiles_ready:
		draw_rect(g, GRASS)
	_draw_torii(g.get_center() + Vector2(0, 40))
	if placing_zone != "":
		draw_rect(zone_rect(placing_zone), HIGHLIGHT, false, 3.0)


func _draw_torii(base: Vector2) -> void:
	draw_rect(Rect2(base + Vector2(-34, -90), Vector2(8, 90)), TORII)
	draw_rect(Rect2(base + Vector2(26, -90), Vector2(8, 90)), TORII)
	draw_rect(Rect2(base + Vector2(-46, -98), Vector2(92, 8)), TORII)
	draw_rect(Rect2(base + Vector2(-38, -76), Vector2(76, 6)), TORII)
