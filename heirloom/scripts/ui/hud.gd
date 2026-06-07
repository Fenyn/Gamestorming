extends CanvasLayer

@onready var clock_label: Label = %ClockLabel
@onready var day_label: Label = %DayLabel
@onready var money_label: Label = %MoneyLabel
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var thirst_bar: ProgressBar = %ThirstBar
@onready var fatigue_bar: ProgressBar = %FatigueBar
@onready var materials_label: Label = %MaterialsLabel
@onready var bicycle_label: Label = %BicycleLabel
@onready var camaro_label: Label = %CamaroProgress
@onready var interact_label: Label = %InteractLabel

var _player: CharacterBody3D = null

var _hunger_fill: StyleBoxFlat = null
var _thirst_fill: StyleBoxFlat = null
var _fatigue_fill: StyleBoxFlat = null


func _ready() -> void:
	_hunger_fill = _make_fill(hunger_bar)
	_thirst_fill = _make_fill(thirst_bar)
	_fatigue_fill = _make_fill(fatigue_bar)

	EventBus.camaro_progress_changed.connect(_on_camaro_progress)
	EventBus.part_installed.connect(func(_id: String) -> void: _flash_camaro_label())

	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D


func _process(_delta: float) -> void:
	clock_label.text = TimeManager.get_time_string()
	day_label.text = "Day %d  |  Month %d" % [GameState.day, GameState.month]
	money_label.text = "$%.2f" % GameState.money

	hunger_bar.value = GameState.hunger
	thirst_bar.value = GameState.thirst
	fatigue_bar.value = GameState.fatigue

	_color_fill(_hunger_fill, GameState.hunger)
	_color_fill(_thirst_fill, GameState.thirst)
	_color_fill(_fatigue_fill, GameState.fatigue)

	_update_materials()
	_update_bicycle()
	_update_interact_prompt()


func _make_fill(bar: ProgressBar) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.8, 0.3)
	bar.add_theme_stylebox_override("fill", style)
	return style


func _color_fill(style: StyleBoxFlat, value: float) -> void:
	if value <= 0.2:
		style.bg_color = Color(0.9, 0.2, 0.2)
	elif value <= 0.4:
		style.bg_color = Color(0.9, 0.7, 0.2)
	else:
		style.bg_color = Color(0.3, 0.8, 0.3)


func _update_materials() -> void:
	var parts: Array[String] = []
	var wood: int = GameState.get_material_count("wood_plank")
	var salvage: int = GameState.get_material_count("salvage_part")
	var stone: int = GameState.get_material_count("stone")
	var wire: int = GameState.get_material_count("wire_pipe")
	if wood > 0:
		parts.append("Wood: %d" % wood)
	if salvage > 0:
		parts.append("Salvage: %d" % salvage)
	if stone > 0:
		parts.append("Stone: %d" % stone)
	if wire > 0:
		parts.append("Wire: %d" % wire)
	materials_label.text = "  ".join(parts)


func _update_bicycle() -> void:
	if _player and _player.has_method("is_on_bicycle"):
		bicycle_label.text = "[B] Riding Bicycle" if _player.is_on_bicycle() else ""
	else:
		bicycle_label.text = ""


func _on_camaro_progress(installed: int, total: int) -> void:
	if total <= 0:
		camaro_label.text = ""
		return
	camaro_label.text = "Camaro: %d/%d parts" % [installed, total]


func _flash_camaro_label() -> void:
	var tween: Tween = create_tween()
	camaro_label.add_theme_color_override("font_color", Color(1, 1, 0.3))
	tween.tween_interval(0.8)
	tween.tween_callback(func() -> void:
		camaro_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4)))


func _update_interact_prompt() -> void:
	if not _player:
		interact_label.text = ""
		return

	if _player.has_held_item():
		var held: Node3D = _player.get_held_item()
		if held and held.has_method("is_food") and held.is_food():
			interact_label.text = "[F] Eat %s" % (held.get("display_name") as String)
			return

	var ray: RayCast3D = _player.get_node("Camera3D/InteractRay") as RayCast3D
	if not ray or not ray.is_colliding():
		interact_label.text = ""
		return

	var collider: Node = ray.get_collider()
	if not collider:
		interact_label.text = ""
		return

	if collider.has_method("get_interact_hint"):
		var hint: String = collider.get_interact_hint(_player) as String
		if not hint.is_empty():
			interact_label.text = hint
			return

	if collider.is_in_group("carriable") and not _player.has_held_item():
		var item_name: String = collider.get("display_name") as String
		if item_name.is_empty():
			item_name = collider.name
		interact_label.text = "[Click] Pick up %s" % item_name
	elif collider.has_method("receive_item") and _player.has_held_item():
		interact_label.text = "[Click] Place"
	else:
		interact_label.text = ""
