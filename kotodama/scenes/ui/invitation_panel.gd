class_name InvitationPanel
extends Control
## Inviting a new spirit: its parts, the stroke order, its name, writing the ofuda, then its words.

signal place_requested(kanji: Dictionary)
signal finished

enum Step { PARTS, ORDER, NAME, WRITE, PLACE, WORDS, DONE }

const RACK_SIZE: int = 6
const LESSON_WRONG_LIMIT: int = 99

@onready var _title: Label = %Title
@onready var _glyph: Label = %Glyph
@onready var _rack: GridContainer = %Rack
@onready var _canvas_holder: Control = %CanvasHolder
@onready var _canvas: StrokeCanvas = %Canvas
@onready var _info: Label = %Info
@onready var _word_box: Control = %WordBox
@onready var _word: Label = %Word
@onready var _word_info: Label = %WordInfo
@onready var _romaji: LineEdit = %Romaji
@onready var _kana: Label = %Kana
@onready var _feedback: Label = %Feedback
@onready var _next: Button = %Next

var _kanji: Dictionary = {}
var _words: Array[Dictionary] = []
var _step: int = Step.DONE
var _word_index: int = 0
var _parts_checked: bool = false
var _today: int = 0
var _drill_wrong_limit: int = 2


func _ready() -> void:
	_next.pressed.connect(_on_next)
	_romaji.text_changed.connect(func(text: String) -> void: _kana.text = Romaji.to_kana(text))
	_romaji.text_submitted.connect(_on_romaji_submitted)
	_canvas.order_played.connect(func() -> void: _next.disabled = false)
	_canvas.finished.connect(func(_passed: bool) -> void: _next.disabled = false)
	_drill_wrong_limit = _canvas.wrong_limit
	hide()


func start_kanji(kanji: Dictionary, words: Array[Dictionary], today: int) -> void:
	_kanji = kanji
	_words = words
	_today = today
	_word_index = 0
	var parts: Array = kanji["parts"]
	_step = Step.PARTS if parts.size() > 0 else Step.ORDER
	show()
	_show_step()


func start_words(words: Array[Dictionary], today: int) -> void:
	_kanji = {}
	_words = words
	_today = today
	_word_index = 0
	_step = Step.WORDS
	show()
	_show_step()


func continue_after_place() -> void:
	_step = Step.WORDS if _words.size() > 0 else Step.DONE
	show()
	_show_step()


func _show_step() -> void:
	_rack.visible = false
	_canvas_holder.visible = false
	_info.visible = false
	_word_box.visible = false
	_feedback.text = ""
	_next.disabled = false
	_next.visible = true
	_glyph.visible = not _kanji.is_empty()
	if not _kanji.is_empty():
		_glyph.text = _kanji["ch"]
	match _step:
		Step.PARTS:
			_title.text = "Its parts"
			_rack.visible = true
			_parts_checked = false
			_fill_rack()
		Step.ORDER:
			_title.text = "Stroke order"
			_canvas_holder.visible = true
			_canvas.show_only(Data.strokes_for(_kanji["cp"]))
			_canvas.play_order()
			_next.disabled = true
		Step.NAME:
			_title.text = "Name"
			_info.visible = true
			var on: Array[String] = []
			for r in _kanji["on"]:
				on.append(DrillPanel.kun_display(r))
			var kun: Array[String] = []
			for r in _kanji["kun"]:
				kun.append(DrillPanel.kun_display(r))
			_info.text = "%s\non  %s\nkun  %s\n%s" % [
				_kanji["keyword"], "、".join(on), "、".join(kun), Data.zone_name(_kanji["zone"]),
			]
		Step.WRITE:
			_title.text = "Write it on the ofuda"
			_canvas_holder.visible = true
			_canvas.wrong_limit = LESSON_WRONG_LIMIT
			_canvas.begin(Data.strokes_for(_kanji["cp"]), StrokeCanvas.Guide.FULL)
			_next.disabled = true
		Step.PLACE:
			_canvas.wrong_limit = _drill_wrong_limit
			hide()
			place_requested.emit(_kanji)
		Step.WORDS:
			_title.text = "Words"
			_glyph.visible = false
			_next.visible = false
			_word_box.visible = true
			_show_word()
		Step.DONE:
			hide()
			finished.emit()


func _on_next() -> void:
	if _step == Step.PARTS and not _parts_checked:
		if not _check_parts():
			return
	_step += 1
	if _step == Step.WORDS and _words.is_empty():
		_step = Step.DONE
	_show_step()


# ---------------------------------------------------------------- parts

func _fill_rack() -> void:
	var truth: Array = _kanji["parts"]
	var ids: Array[String] = []
	for part in truth:
		var pid: String = part
		ids.append(pid)
	var pool: Array[String] = []
	for entry in Data.parts:
		var p: Dictionary = entry
		var pid: String = p["id"]
		if not ids.has(pid) and Progress.is_part_known(pid):
			pool.append(pid)
	pool.shuffle()
	for pid in pool:
		if ids.size() >= RACK_SIZE:
			break
		ids.append(pid)
	ids.shuffle()
	var tiles: Array[Node] = _rack.get_children()
	for i in range(tiles.size()):
		var tile: Button = tiles[i]
		tile.visible = i < ids.size()
		tile.button_pressed = false
		tile.disabled = false
		if i < ids.size():
			var pid: String = ids[i]
			tile.text = Data.part_name(pid)
			tile.icon = Data.glyph_for(Data.part_glyph_cp(pid))
			tile.set_meta("part_id", pid)


## Returns true when the picked parts are right. Otherwise shows the right ones.
func _check_parts() -> bool:
	var truth: Array = _kanji["parts"]
	var picked: Array[String] = []
	for child in _rack.get_children():
		var tile: Button = child
		if tile.visible and tile.button_pressed:
			picked.append(tile.get_meta("part_id"))
	var right: bool = picked.size() == truth.size()
	for part in truth:
		if not picked.has(part):
			right = false
	_parts_checked = true
	if right:
		return true
	_feedback.text = DrillPanel.parts_text(_kanji)
	for child in _rack.get_children():
		var tile: Button = child
		if tile.visible:
			tile.button_pressed = truth.has(tile.get_meta("part_id"))
			tile.disabled = true
	return false


# ---------------------------------------------------------------- words

func _show_word() -> void:
	var w: Dictionary = _words[_word_index]
	_word.text = w["word"]
	_word_info.text = "%s\n%s" % ["、".join(w["readings"]), ", ".join(w["meanings"])]
	_romaji.text = ""
	_kana.text = ""
	_romaji.grab_focus()


func _on_romaji_submitted(text: String) -> void:
	if _step != Step.WORDS or text.strip_edges() == "":
		return
	var w: Dictionary = _words[_word_index]
	var kana: String = Romaji.to_kana_final(text)
	var readings: Array = w["readings"]
	if not readings.has(kana):
		_feedback.text = "、".join(readings)
		_romaji.text = ""
		_kana.text = ""
		return
	Progress.learn(Progress.word_key(w["word"]), _today)
	_feedback.text = ""
	_word_index += 1
	if _word_index < _words.size():
		_show_word()
	else:
		_step = Step.DONE
		_show_step()
