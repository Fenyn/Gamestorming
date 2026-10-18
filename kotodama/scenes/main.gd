class_name Main
extends Node2D
## One day at the sanctuary: invitations at the gate, drills on hungry spirits and flowers.

const NEW_KANJI_PER_DAY: int = 5
const NEW_WORDS_PER_DAY: int = 15
const WORDS_PER_KANJI: int = 3
const REVIEW_CAP: int = 60
const PLANTABLE_SCAN: int = 80
const EVENING: Color = Color(0.6, 0.55, 0.75)
const ZOOM_MIN: float = 1.5
const ZOOM_MAX: float = 3.0
const ZOOM_STEP: float = 1.15
const PAN_SPEED: float = 420.0

@onready var _yard: Yard = %Yard
@onready var _camera: Camera2D = %Camera
@onready var _night: CanvasModulate = %Night
@onready var _day_label: Label = %Day
@onready var _tally_label: Label = %Tally
@onready var _rest: Button = %Rest
@onready var _drill: DrillPanel = %DrillPanel
@onready var _invite: InvitationPanel = %InvitationPanel
@onready var _dusk: DuskPanel = %DuskPanel

var _today: int = 0
var _due: Array[String] = []
var _placing: Dictionary = {}


func _ready() -> void:
	_yard.spirit_clicked.connect(_on_spirit_clicked)
	_yard.flower_clicked.connect(_on_flower_clicked)
	_yard.light_clicked.connect(_on_light_clicked)
	_yard.place_clicked.connect(_on_place_clicked)
	_drill.finished.connect(_on_drill_finished)
	_invite.place_requested.connect(_on_place_requested)
	_invite.finished.connect(_on_invite_finished)
	_rest.pressed.connect(func() -> void: _dusk.show_tally(Progress.tally))
	Progress.day_rolled.connect(func(_day: int) -> void: refresh())
	_yard.rebuild()
	_camera.position = _yard.gate_position() + Vector2(0, -120)
	refresh()


## Recomputes the queue, the gate lights, the bubbles and the light of day.
func refresh() -> void:
	Progress.roll_day()
	_today = Srs.today()
	_due = Progress.due_keys(_today)
	if _due.size() > REVIEW_CAP:
		_due.resize(REVIEW_CAP)
	_yard.refresh_states(_due, _today)
	var lights: int = mini(kanji_budget_left(), Progress.next_kanji(NEW_KANJI_PER_DAY).size())
	var seed_light: bool = lights == 0 and word_budget_left() > 0 and Progress.plantable_words(1).size() > 0
	_yard.set_lights(lights, seed_light)
	_day_label.text = "Day %d" % Progress.day_number()
	_tally_label.text = "Called %d · Watered %d · Invited %d · Planted %d" % [
		int(Progress.tally.get("called", 0)), int(Progress.tally.get("watered", 0)),
		int(Progress.tally.get("invited", 0)), int(Progress.tally.get("planted", 0)),
	]
	var evening: bool = _due.is_empty() and lights == 0 and not seed_light
	_night.color = EVENING if evening else Color.WHITE


func kanji_budget_left() -> int:
	return maxi(0, NEW_KANJI_PER_DAY - int(Progress.tally.get("invited", 0)))


func word_budget_left() -> int:
	return maxi(0, NEW_WORDS_PER_DAY - int(Progress.tally.get("planted", 0)))


## Words to plant with a new kanji: those using it first, then any other ready word.
func words_for(kanji: Dictionary) -> Array[Dictionary]:
	var budget: int = mini(WORDS_PER_KANJI, word_budget_left())
	var out: Array[Dictionary] = []
	if budget <= 0:
		return out
	var ch: String = kanji["ch"]
	var candidates: Array[Dictionary] = Progress.plantable_words(PLANTABLE_SCAN, [ch])
	for w in candidates:
		var uses: Array = w["kanji"]
		if uses.has(ch):
			out.append(w)
		if out.size() >= budget:
			return out
	for w in candidates:
		if not out.has(w):
			out.append(w)
		if out.size() >= budget:
			break
	return out


# ---------------------------------------------------------------- yard events

func _on_spirit_clicked(spirit: Spirit) -> void:
	if _busy() or not _due.has(spirit.key):
		return
	_drill.start(spirit.key, Progress.next_drill(spirit.key))


func _on_flower_clicked(flower: Flower) -> void:
	if _busy() or not _due.has(flower.key):
		return
	_drill.start(flower.key, Progress.next_drill(flower.key))


func _on_light_clicked(_index: int, is_seed: bool) -> void:
	if _busy():
		return
	if is_seed:
		var words: Array[Dictionary] = Progress.plantable_words(word_budget_left())
		if words.is_empty():
			return
		_invite.start_words(words, _today)
		return
	var next: Array[Dictionary] = Progress.next_kanji(1)
	if next.is_empty() or kanji_budget_left() <= 0:
		return
	_invite.start_kanji(next[0], words_for(next[0]), _today)


func _on_drill_finished(key: String, passed: bool) -> void:
	if passed:
		Progress.record_pass(key, _today)
	else:
		Progress.record_miss(key, _today)
	refresh()


func _on_place_requested(kanji: Dictionary) -> void:
	_placing = kanji
	_yard.begin_placing(kanji["zone"])


func _on_place_clicked(_zone_id: String) -> void:
	if _placing.is_empty():
		return
	var kanji: Dictionary = _placing
	_placing = {}
	_yard.end_placing()
	Progress.learn(Progress.kanji_key(kanji["ch"]), _today)
	_yard.add_spirit(kanji)
	_invite.continue_after_place()


func _on_invite_finished() -> void:
	for word in Progress.known_words():
		if not _yard.flowers.has(word):
			_yard.add_flower(Data.words_by_word[word])
	refresh()


func _busy() -> bool:
	return _drill.visible or _invite.visible or _dusk.visible or not _placing.is_empty()


# ---------------------------------------------------------------- camera

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_camera.zoom.x * ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_camera.zoom.x / ZOOM_STEP)
	elif event is InputEventMouseMotion and (event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT)):
		_camera.position -= event.relative / _camera.zoom.x
		_clamp_camera()


func _process(delta: float) -> void:
	if _busy():
		return
	var dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir != Vector2.ZERO:
		_camera.position += dir * PAN_SPEED * delta / _camera.zoom.x
		_clamp_camera()


func _set_zoom(z: float) -> void:
	var clamped: float = clampf(z, ZOOM_MIN, ZOOM_MAX)
	_camera.zoom = Vector2(clamped, clamped)
	_clamp_camera()


func _clamp_camera() -> void:
	var world: Rect2 = _yard.world_rect().grow(60)
	_camera.position = _camera.position.clamp(world.position, world.end)
