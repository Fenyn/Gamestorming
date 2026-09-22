class_name CardFaceCache
extends Node
## Renders card faces to textures once per definition (and per aspect for personalities).
## One SubViewport, reused; each render waits for a frame, so pre-render during a loading overlay.

@onready var viewport: SubViewport = $Viewport
@onready var face_control: CardFace = $Viewport/CardFace

signal _render_done

var _cache: Dictionary = {}   # key -> Texture2D
var _back: Texture2D = null
var _ladder: Array[Rect2] = []
var _rendering: bool = false


## Sets the default portrait backdrop for screens that do not name a deck: the run deck's inside
## an adventure, the neutral dark anywhere else. Session is looked up by path so this script still
## compiles in `-s` test runs, which have no autoloads.
func _ready() -> void:
	CardFace.default_backdrop = CardFace.NEUTRAL_BACKDROP
	var session: Node = get_tree().root.get_node_or_null("Session")
	if session == null or not bool(session.call("in_adventure")):
		return
	var run: AdventureRun = session.get("run") as AdventureRun
	var library: CardLibrary = session.get("library") as CardLibrary
	if run != null:
		CardFace.default_backdrop = CardFace.mastery_backdrop(run.deck(), library)


## `backdrop` is the deck colour behind a personality portrait (CardFace.NO_BACKDROP for the
## default). It is part of a personality's key, so one card shown for two decks is two faces.
static func key_for(def: CardDef, aspect: int = 0, backdrop: Color = CardFace.NO_BACKDROP) -> String:
	if def.is_personality():
		return "%s#%d@%s" % [def.id, def.aspect if def.aspect > 0 else aspect, CardFace.resolve_backdrop(backdrop).to_html(false)]
	return def.id


func has_face(def: CardDef, aspect: int = 0, backdrop: Color = CardFace.NO_BACKDROP) -> bool:
	return _cache.has(key_for(def, aspect, backdrop))


## Cached texture, or null if it has not been rendered yet.
func face(def: CardDef, aspect: int = 0, backdrop: Color = CardFace.NO_BACKDROP) -> Texture2D:
	return _cache.get(key_for(def, aspect, backdrop))


func back() -> Texture2D:
	return _back


## Renders run one at a time on the shared viewport; callers that arrive mid-render wait their turn.
func render_face(def: CardDef, aspect: int = 0, backdrop: Color = CardFace.NO_BACKDROP) -> Texture2D:
	var key: String = key_for(def, aspect, backdrop)
	while _rendering:
		await _render_done
	if _cache.has(key):
		return _cache[key]
	_rendering = true
	face_control.show_def(def, aspect, -1, null, backdrop)
	var tex: Texture2D = await _render()
	_cache[key] = tex
	if def.is_personality() and _ladder.is_empty():
		_ladder = face_control.ladder_rects()
	_rendering = false
	_render_done.emit()
	return tex


## Rung rects in face pixels, top first; known once a personality has rendered.
func ladder_rects() -> Array[Rect2]:
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
func render_def(def: CardDef, backdrop: Color = CardFace.NO_BACKDROP) -> void:
	if def == null:
		return
	if def.is_personality():
		for t in def.aspects:
			await render_face(def, int(t.get("aspect", 1)), backdrop)
	else:
		await render_face(def)


## The cards a deck list names, personalities on that deck's backdrop. `public_only` renders just
## the parts anyone can see (duelist, Mastery, Relic), which is all a client should assume about
## the other seat's deck.
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
		if def != null and not has_face(def, c.aspect, backdrop):
			await render_def(def, backdrop)


func _render() -> Texture2D:
	await get_tree().process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
