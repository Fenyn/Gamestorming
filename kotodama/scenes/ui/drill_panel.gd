class_name DrillPanel
extends Control
## One review: call it (type the reading), what it is (pick the meaning) or write it (strokes).

signal finished(key: String, passed: bool)

enum Drill { CALL, WHAT, FORM }

const CHOICE_COUNT: int = 4
const GUIDE_UNTIL_STAGE: int = 2
const SHY_SPIRIT: String = "The spirit was shy today."
const SHY_FLOWER: String = "The flower droops a little."

@onready var _kind: Label = %Kind
@onready var _item_label: Label = %Item
@onready var _hint: Label = %Hint
@onready var _input_box: Control = %InputBox
@onready var _romaji: LineEdit = %Romaji
@onready var _kana: Label = %Kana
@onready var _choices: GridContainer = %Choices
@onready var _canvas_holder: Control = %CanvasHolder
@onready var _canvas: StrokeCanvas = %Canvas
@onready var _answer: Label = %Answer
@onready var _parts: Label = %Parts
@onready var _shy: Label = %Shy
@onready var _continue: Button = %Continue

var _key: String = ""
var _drill: int = Drill.CALL
var _item: Dictionary = {}
var _is_kanji: bool = true
var _answered: bool = false
var _passed: bool = false
var _correct_choice: String = ""


func _ready() -> void:
	_romaji.text_changed.connect(_on_romaji_changed)
	_romaji.text_submitted.connect(_on_romaji_submitted)
	_continue.pressed.connect(_finish)
	_canvas.finished.connect(_on_canvas_finished)
	for child in _choices.get_children():
		var button: Button = child
		button.pressed.connect(_on_choice.bind(button))
	hide()


func start(key: String, drill: int) -> void:
	_key = key
	_drill = drill
	_answered = false
	_passed = false
	_is_kanji = Progress.is_kanji_key(key)
	var text: String = Progress.key_text(key)
	_item = Data.kanji_by_ch[text] if _is_kanji else Data.words_by_word[text]
	_input_box.visible = false
	_choices.visible = false
	_canvas_holder.visible = false
	_item_label.visible = true
	_item_label.text = text
	_hint.text = ""
	_answer.text = ""
	_parts.text = ""
	_shy.text = ""
	_continue.visible = false
	match drill:
		Drill.CALL:
			_show_call()
		Drill.WHAT:
			_show_what()
		Drill.FORM:
			_show_form()
	show()


# ---------------------------------------------------------------- call

func _show_call() -> void:
	_kind.text = "Call it" if _is_kanji else "Water it"
	_input_box.visible = true
	_romaji.editable = true
	_romaji.text = ""
	_kana.text = ""
	_romaji.grab_focus()


func _on_romaji_changed(text: String) -> void:
	_kana.text = Romaji.to_kana(text)


func _on_romaji_submitted(text: String) -> void:
	if _answered:
		_finish()
		return
	if text.strip_edges() == "":
		return
	var kana: String = Romaji.to_kana_final(text)
	_kana.text = kana
	var accepted: Array = _item["accept"] if _is_kanji else _item["readings"]
	_resolve(accepted.has(kana))


# ---------------------------------------------------------------- what

func _show_what() -> void:
	_kind.text = "What is it?"
	_choices.visible = true
	_correct_choice = primary_meaning(_item, _is_kanji)
	var options: Array[String] = [_correct_choice]
	options.append_array(_distractors())
	options.shuffle()
	var buttons: Array[Node] = _choices.get_children()
	for i in range(buttons.size()):
		var button: Button = buttons[i]
		button.visible = i < options.size()
		button.disabled = false
		button.text = options[i] if i < options.size() else ""


func _on_choice(button: Button) -> void:
	if _answered:
		return
	_resolve(button.text == _correct_choice)


func _distractors() -> Array[String]:
	var pool: Array = Data.kanji if _is_kanji else Data.words
	var same_zone: Array[String] = []
	var others: Array[String] = []
	for entry in pool:
		var e: Dictionary = entry
		var meaning: String = primary_meaning(e, _is_kanji)
		if meaning == _correct_choice:
			continue
		if e["zone"] == _item["zone"]:
			same_zone.append(meaning)
		else:
			others.append(meaning)
	same_zone.shuffle()
	others.shuffle()
	var out: Array[String] = []
	for meaning in same_zone + others:
		var m: String = meaning
		if not out.has(m):
			out.append(m)
		if out.size() >= CHOICE_COUNT - 1:
			break
	return out


# ---------------------------------------------------------------- form

func _show_form() -> void:
	_kind.text = "Write it"
	_item_label.visible = false
	_hint.text = short_hint(_item)
	_canvas_holder.visible = true
	var guide: int = StrokeCanvas.Guide.FIRST_START if Progress.stage_of(_key) <= GUIDE_UNTIL_STAGE else StrokeCanvas.Guide.NONE
	_canvas.begin(Data.strokes_for(_item["cp"]), guide)


func _on_canvas_finished(passed: bool) -> void:
	if _answered:
		return
	_item_label.visible = true
	_resolve(passed)


# ---------------------------------------------------------------- result

func _resolve(passed: bool) -> void:
	_answered = true
	_passed = passed
	_answer.text = ("✓ " if passed else "✗ ") + answer_text(_item, _is_kanji)
	if not passed:
		_shy.text = SHY_SPIRIT if _is_kanji else SHY_FLOWER
		if _is_kanji:
			_parts.text = parts_text(_item)
	_romaji.editable = false
	for child in _choices.get_children():
		var button: Button = child
		button.disabled = true
	_continue.visible = true
	_continue.grab_focus()


func _finish() -> void:
	hide()
	finished.emit(_key, _passed)


# ---------------------------------------------------------------- text helpers

static func primary_meaning(item: Dictionary, is_kanji: bool) -> String:
	if is_kanji:
		return item["keyword"]
	var meanings: Array = item["meanings"]
	return meanings[0] if meanings.size() > 0 else ""


static func readings_text(item: Dictionary, is_kanji: bool) -> String:
	if is_kanji:
		var all: Array[String] = []
		for r in item["on"]:
			all.append(kun_display(r))
		for r in item["kun"]:
			all.append(kun_display(r))
		return "、".join(all)
	return "、".join(item["readings"])


## Short form for the write drill: keyword, first on reading, first kun reading.
static func short_hint(kanji: Dictionary) -> String:
	var pieces: Array[String] = [kanji["keyword"]]
	var on: Array = kanji["on"]
	var kun: Array = kanji["kun"]
	if on.size() > 0:
		pieces.append(kun_display(on[0]))
	if kun.size() > 0:
		pieces.append(kun_display(kun[0]))
	return " · ".join(pieces)


## KANJIDIC writes okurigana after a dot and affixes with a dash: "ふた.つ" shows as "ふた(つ)".
static func kun_display(reading: String) -> String:
	var r: String = reading.replace("-", "")
	var dot: int = r.find(".")
	if dot >= 0:
		r = r.substr(0, dot) + "(" + r.substr(dot + 1) + ")"
	return r


static func answer_text(item: Dictionary, is_kanji: bool) -> String:
	return "%s · %s" % [readings_text(item, is_kanji), primary_meaning(item, is_kanji)]


static func parts_text(kanji: Dictionary) -> String:
	var pieces: Array[String] = []
	for part in kanji["parts"]:
		var pid: String = part
		var glyph: String = Data.parts_by_id[pid]["glyph"] if Data.parts_by_id.has(pid) else pid
		pieces.append("%s %s" % [glyph, Data.part_name(pid)])
	return " + ".join(pieces)
