class_name BaseMachine
extends StaticBody2D

enum MachineState { IDLE, PROCESSING, DONE }

@export var machine_type: String = ""
@export var machine_label: String = "MACHINE"
@export var machine_color: Color = Color(0.3, 0.3, 0.4, 1)
@export var sprite_texture: Texture2D = null

var _current_state: MachineState = MachineState.IDLE
var _active_recipe: RecipeData = null
var _process_timer: float = 0.0
var _output_item_id: String = ""
var _output_count: int = 0

@onready var _visual: Sprite2D = %MachineVisual
@onready var _label: Label = %MachineLabel
@onready var _progress_bar: ColorRect = %ProgressBar
@onready var _progress_bg: ColorRect = %ProgressBg
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	_label.text = machine_label
	_progress_bar.visible = false
	_progress_bg.visible = false
	if sprite_texture:
		_visual.texture = sprite_texture
	_update_status()


func _process(delta: float) -> void:
	if _current_state != MachineState.PROCESSING:
		return
	_process_timer -= delta
	_update_progress_visual()
	if _process_timer <= 0.0:
		_finish_processing()


func interact(_player: Node2D) -> void:
	match _current_state:
		MachineState.IDLE:
			_try_process_active_item()
		MachineState.DONE:
			_collect_output()


func get_interact_hint() -> String:
	match _current_state:
		MachineState.IDLE:
			var recipe: RecipeData = _find_recipe_for_active_item()
			if recipe:
				return "E/Click: Make %s" % recipe.display_name
			var recipes_text: String = _get_recipes_summary()
			if recipes_text != "":
				return "%s — Recipes: %s" % [machine_label, recipes_text]
			return "%s (no recipes)" % machine_label
		MachineState.PROCESSING:
			return "%s (processing...)" % machine_label
		MachineState.DONE:
			return "E/Click: Collect %s" % _output_item_id.replace("_", " ")
	return machine_label


func _get_recipes_summary() -> String:
	var summaries: Array[String] = []
	for recipe: Resource in Database.get_all_recipes():
		var r: RecipeData = recipe as RecipeData
		if r.machine_type != machine_type:
			continue
		var inputs: Array[String] = []
		for input: Dictionary in r.input_items:
			var id: String = input.get("id", "") as String
			inputs.append(id.replace("_", " "))
		summaries.append("%s → %s" % [" + ".join(inputs), r.display_name])
	return " | ".join(summaries)


func _try_process_active_item() -> void:
	var recipe: RecipeData = _find_recipe_for_active_item()
	if recipe == null:
		_flash_reject()
		var active: String = GameState.get_active_item_id()
		if active != "":
			EventBus.notification_requested.emit("%s doesn't go in %s" % [active.replace("_", " "), machine_label])
		return

	for input: Dictionary in recipe.input_items:
		var item_id: String = input.get("id", "") as String
		var count: int = input.get("count", 1) as int
		if not GameState.remove_item(item_id, count):
			return

	_active_recipe = recipe
	_process_timer = recipe.process_time
	_output_item_id = recipe.output_item_id
	_output_count = recipe.output_count
	_current_state = MachineState.PROCESSING
	_progress_bar.visible = true
	_progress_bg.visible = true
	_update_status()


func _finish_processing() -> void:
	_current_state = MachineState.DONE
	_process_timer = 0.0
	_progress_bar.visible = false
	_progress_bg.visible = false
	_update_status()


func _collect_output() -> void:
	if _output_item_id != "" and _output_count > 0:
		GameState.add_processed(_output_item_id, _output_count)
		GameState._auto_assign_toolbar(_output_item_id)
		_spawn_float_text("+%d %s" % [_output_count, _output_item_id.replace("_", " ")])
	_output_item_id = ""
	_output_count = 0
	_active_recipe = null
	_current_state = MachineState.IDLE
	_update_status()


func _spawn_float_text(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.modulate = Color(0.3, 1.0, 0.5, 1)
	label.position = Vector2(-40, -40)
	label.z_index = 10
	add_child(label)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 25, 0.8)
	tw.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(label.queue_free)


func _find_recipe_for_active_item() -> RecipeData:
	var active_id: String = GameState.get_active_item_id()
	if active_id == "":
		return null

	for recipe: Resource in Database.get_all_recipes():
		var r: RecipeData = recipe as RecipeData
		if r.machine_type != machine_type:
			continue
		if not _recipe_uses_item(r, active_id):
			continue
		if _has_all_ingredients(r):
			return r
	return null


func _recipe_uses_item(recipe: RecipeData, item_id: String) -> bool:
	for input: Dictionary in recipe.input_items:
		if input.get("id", "") == item_id:
			return true
	return false


func _has_all_ingredients(recipe: RecipeData) -> bool:
	for input: Dictionary in recipe.input_items:
		var item_id: String = input.get("id", "") as String
		var count: int = input.get("count", 1) as int
		if GameState.get_item_count(item_id) < count:
			return false
	return true


func _update_progress_visual() -> void:
	if _active_recipe == null:
		return
	var progress: float = 1.0 - (_process_timer / _active_recipe.process_time)
	_progress_bar.scale.x = clampf(progress, 0.0, 1.0)


func _update_status() -> void:
	match _current_state:
		MachineState.IDLE:
			_status_label.text = "IDLE"
			_status_label.modulate = Color(0.5, 0.5, 0.5, 1)
			_tween_machine_color(machine_color)
		MachineState.PROCESSING:
			_status_label.text = _active_recipe.display_name if _active_recipe else "..."
			_status_label.modulate = Color(1.0, 0.8, 0.3, 1)
			_tween_machine_color(machine_color.lerp(Color(0.6, 0.5, 0.2, 1), 0.4))
		MachineState.DONE:
			_status_label.text = _output_item_id.replace("_", " ")
			_status_label.modulate = Color(0.3, 1.0, 0.3, 1)
			_tween_machine_color(machine_color.lerp(Color(0.2, 0.5, 0.3, 1), 0.4))


func _tween_machine_color(target: Color) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_visual, "modulate", target, 0.3)


func _flash_reject() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_visual, "modulate", Color(1.0, 0.4, 0.4, 1), 0.1)
	tw.tween_property(_visual, "modulate", Color.WHITE, 0.2)
