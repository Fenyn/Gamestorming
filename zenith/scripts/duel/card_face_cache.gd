class_name CardFaceCache
extends Node
## Renders card faces to textures once per definition (and per aspect for personalities, and per
## resolved table base for a Strike inside a duel).
## One SubViewport, reused; each render waits for a frame, so pre-render during a loading overlay.

@onready var viewport: SubViewport = $Viewport
@onready var face_control: CardFace = $Viewport/CardFace

signal _render_done

var _cache: Dictionary = {}   # key -> Texture2D
var _back: Texture2D = null
var _ladder: Rect2 = Rect2()
var _rendering: bool = false
var _strike_table: StrikeTable = null
## Per owning seat, the Might its Strikes are performed at and the Might they land on; empty
## outside a duel, where a table Strike keeps its "Table" wording.
var _mights: Array[Vector2i] = []


## Sets the default portrait backdrop: the run deck's in an adventure, neutral elsewhere. Session
## is looked up by path because `-s` test runs have no autoloads.
func _ready() -> void:
	CardFace.default_backdrop = CardFace.NEUTRAL_BACKDROP
	var session: Node = get_tree().root.get_node_or_null("Session")
	if session != null:
		CardFace.strike_table = session.get("strike_table") as StrikeTable
	if session == null or not bool(session.call("in_adventure")):
		return
	var run: AdventureRun = session.get("run") as AdventureRun
	var library: CardLibrary = session.get("library") as CardLibrary
	if run != null:
		CardFace.default_backdrop = CardFace.mastery_backdrop(run.deck(), library)


## `backdrop` is the deck colour behind a personality portrait (CardFace.NO_BACKDROP for the
## default). It is part of a personality's key, so one card shown for two decks is two faces.
## `table` is a Strike's resolved table base (-1 for none), so each number is its own face.
static func key_for(def: CardDef, aspect: int = 0, backdrop: Color = CardFace.NO_BACKDROP, table: int = -1) -> String:
	if def.is_personality():
		return "%s#%d@%s" % [def.id, def.aspect if def.aspect > 0 else aspect, CardFace.resolve_backdrop(backdrop).to_html(false)]
	if table >= 0:
		return "%s~%d" % [def.id, table]
	return def.id


## Reads both seats' Strike matchups off a duel view. True when either changed, which is when the
## Strike faces on show need their numbers redrawn.
func set_matchups(view: SeatView, library: CardLibrary, table: StrikeTable) -> bool:
	var next: Array[Vector2i] = []
	for p in view.players:
		next.append(view.strike_mights(p.index, library))
	var changed: bool = next != _mights or table != _strike_table
	_mights = next
	_strike_table = table
	return changed


## The table base a card owned by `owner` shows, -1 when it has none or the matchup is unknown.
func table_base(def: CardDef, owner: int) -> int:
	if def == null or owner < 0 or owner >= _mights.size():
		return -1
	var m: Vector2i = _mights[owner]
	return CardText.strike_table_base(def, _strike_table, m.x, m.y)


## The key of the texture `face` returns: the matchup face once it is rendered, else the plain
## one, so a caller comparing keys swaps in the numbered face when it lands.
func key_of(def: CardDef, aspect: int = 0, backdrop: Color = CardFace.NO_BACKDROP, owner: int = -1) -> String:
	var table: int = table_base(def, owner)
	var key: String = key_for(def, aspect, backdrop, table)
	if table >= 0 and not _cache.has(key):
		return key_for(def, aspect, backdrop)
	return key


func has_face(def: CardDef, aspect: int = 0, backdrop: Color = CardFace.NO_BACKDROP, owner: int = -1) -> bool:
	return _cache.has(key_for(def, aspect, backdrop, table_base(def, owner)))


## Cached texture, or null if it has not been rendered yet. `owner` is the seat whose card it is,
## for a Strike's numbered base inside a duel.
func face(def: CardDef, aspect: int = 0, backdrop: Color = CardFace.NO_BACKDROP, owner: int = -1) -> Texture2D:
	return _cache.get(key_of(def, aspect, backdrop, owner))


func back() -> Texture2D:
	return _back


## Renders run one at a time on the shared viewport; callers that arrive mid-render wait their turn.
func render_face(def: CardDef, aspect: int = 0, backdrop: Color = CardFace.NO_BACKDROP, owner: int = -1) -> Texture2D:
	var table: int = table_base(def, owner)
	var key: String = key_for(def, aspect, backdrop, table)
	while _rendering:
		await _render_done
	if _cache.has(key):
		return _cache[key]
	_rendering = true
	face_control.show_def(def, aspect, -1, null, backdrop, table)
	var tex: Texture2D = await _render()
	_cache[key] = tex
	if def.is_personality() and not _ladder.has_area():
		_ladder = face_control.ladder_rect()
	_rendering = false
	_render_done.emit()
	return tex


## The Might ladder's rect in face pixels, the same on every personality face; known once a
## personality has rendered.
func ladder_rect() -> Rect2:
	return _ladder


func render_back() -> Texture2D:
	while _rendering:
		await _render_done
	if _back != null:
		return _back
	_rendering = true
	face_control.show_back()
	_back = await _render()
	_rendering = false
	_render_done.emit()
	return _back


## Every aspect of a personality, or the one face of anything else.
func render_def(def: CardDef, backdrop: Color = CardFace.NO_BACKDROP, owner: int = -1) -> void:
	if def == null:
		return
	if def.is_personality():
		for t in def.aspects:
			await render_face(def, int(t.get("aspect", 1)), backdrop)
	else:
		await render_face(def, 0, CardFace.NO_BACKDROP, owner)


## The cards a deck list names, personalities on that deck's backdrop. `public_only` renders just
## the duelists, Mastery and Relic.
func render_deck(deck: DeckList, library: CardLibrary, public_only: bool = false) -> void:
	var backdrop: Color = CardFace.mastery_backdrop(deck, library)
	await render_back()
	for duelist_id in deck.duelist_ids:
		await render_def(library.defs.get(duelist_id), backdrop)
	if deck.mastery_id != "":
		await render_def(library.defs.get(deck.mastery_id))
	if deck.relic_id != "":
		await render_def(library.defs.get(deck.relic_id))
	if public_only:
		return
	var seen: Dictionary = {}
	for id in deck.reserve + deck.cards:
		if seen.has(id):
			continue
		seen[id] = true
		await render_def(library.defs.get(id), backdrop)


## Renders any face the view shows that is not cached yet (cards first seen on the table).
## `seat_backdrops[owner]` is each seat's deck colour; a seat missing from it gets the default.
func render_missing(view: SeatView, library: CardLibrary, seat_backdrops: Array[Color] = []) -> void:
	for c in view.visible_cards():
		var def: CardDef = library.defs.get(c.def_id)
		var backdrop: Color = seat_backdrops[c.owner] if c.owner >= 0 and c.owner < seat_backdrops.size() else CardFace.NO_BACKDROP
		if def != null and not has_face(def, c.aspect, backdrop, c.owner):
			await render_def(def, backdrop, c.owner)


func _render() -> Texture2D:
	await get_tree().process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
