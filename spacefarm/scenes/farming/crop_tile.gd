class_name CropTile
extends StaticBody2D

const WILT_THRESHOLD: int = 2
const TWEEN_SPEED: float = 0.25
const FRAME_SIZE: int = 48

var grid_position: Vector2i = Vector2i.ZERO
var crop_data: CropData = null
var days_grown: int = 0
var water_count: int = 0
var quality: float = 1.0
var missed_water_days: int = 0
var fertility_type: String = ""
var fertility_stacks: int = 0
var is_near_window: bool = false


@onready var _state_machine: BaseStateMachine = %StateMachine
@onready var _soil_visual: Sprite2D = %SoilVisual
@onready var _crop_visual: Sprite2D = %CropVisual
@onready var _growth_label: Label = %GrowthLabel
@onready var _water_indicator: ColorRect = %WaterIndicator


func _ready() -> void:
	collision_layer = 2
	_state_machine.start()


func interact(player: Node2D) -> void:
	var current_state: BaseState = _state_machine.current_state
	if current_state.has_method("interact"):
		current_state.interact(player)


func get_interact_hint() -> String:
	var state_name: String = _state_machine.get_current_state_name()

	match state_name:
		"Empty":
			if GameState.is_active_tool("trowel"):
				return "E/Click: Till soil"
			return "Select trowel to till"
		"Tilled":
			if GameState.is_active_seed():
				var crop_id: String = GameState.get_active_seed_crop_id()
				var crop: CropData = Database.get_crop(crop_id)
				var cname: String = crop.get_active_name() if crop else crop_id
				return "E/Click: Plant %s" % cname
			if GameState.is_active_fertilizer():
				var fert: String = GameState.get_active_item_id()
				return "E/Click: Apply %s" % fert.replace("_", " ")
			return "Select seeds or fertilizer"
		"Planted", "Growing":
			var needed: int = get_required_water_count()
			if water_count >= needed:
				return "Fully watered"
			if GameState.is_active_tool("watering_can"):
				if needed > 1:
					return "E/Click: Water (%d/%d)" % [water_count, needed]
				return "E/Click: Water crop"
			return "Select watering can"
		"Harvestable":
			return "E/Click: Harvest"
		"Wilting":
			if crop_data and crop_data.water_schedule == CropData.WaterSchedule.ALTERNATE_DAYS:
				return "WILTING! Do not water"
			var wilting_state: BaseState = _state_machine.current_state
			if wilting_state.get("_tended"):
				return "Tended — recovering tomorrow"
			if GameState.is_active_tool("watering_can"):
				return "E/Click: Tend (recovers tomorrow)"
			return "WILTING! Select watering can"
	return ""


func get_required_water_count() -> int:
	if crop_data == null:
		return 1
	match crop_data.water_schedule:
		CropData.WaterSchedule.TWICE_DAILY:
			return 2
		CropData.WaterSchedule.NEVER:
			return 0
		CropData.WaterSchedule.ALTERNATE_DAYS:
			return 1 if days_grown % 2 == 0 else 0
		_:
			return 1


func get_effective_growth_days() -> int:
	var base: int = crop_data.growth_days if crop_data else 0
	if fertility_type == "growth":
		base = maxi(base - fertility_stacks, 1)
	return base


func get_yield_bonus() -> int:
	if fertility_type == "yield":
		return fertility_stacks
	return 0


func get_grow_bay() -> GrowBay:
	var parent: Node = get_parent()
	while parent != null:
		if parent is GrowBay:
			return parent as GrowBay
		parent = parent.get_parent()
	return null


func set_crop(data: CropData) -> void:
	crop_data = data
	days_grown = 0
	water_count = 0
	missed_water_days = 0
	var quality_bonus: float = 0.2 * fertility_stacks if fertility_type == "quality" else 0.0
	quality = data.base_quality + quality_bonus


func clear_crop() -> void:
	var was_pepper: bool = crop_data != null and crop_data.crop_id == "pepper"
	crop_data = null
	days_grown = 0
	water_count = 0
	missed_water_days = 0
	quality = 1.0
	_crop_visual.texture = null
	_crop_visual.visible = false
	_growth_label.text = ""
	_water_indicator.visible = false
	if was_pepper:
		fertility_type = "quality"
		fertility_stacks = mini(fertility_stacks + 1, 3)
	_update_soil_color()


func apply_fertilizer(fert_type: String) -> void:
	if fert_type != fertility_type:
		fertility_type = fert_type
		fertility_stacks = 1
	else:
		fertility_stacks = mini(fertility_stacks + 1, 3)
	_update_soil_color()
	_flash_modulate(_soil_visual, Color(1, 1, 0.5, 1))


func _update_soil_color() -> void:
	var target: Color = Color.WHITE
	if fertility_stacks > 0:
		var tint: Color = Color(1.0, 0.9, 0.6, 1)
		match fertility_type:
			"growth": tint = Color(0.7, 1.0, 0.8, 1)
			"yield": tint = Color(1.0, 0.85, 0.6, 1)
			"quality": tint = Color(1.0, 0.8, 0.5, 1)
		target = Color.WHITE.lerp(tint, float(fertility_stacks) / 3.0)
	_tween_modulate(_soil_visual, target)


func _set_crop_frame(frame_x: int) -> void:
	if crop_data == null or crop_data.growth_sprite == null:
		return
	var row: int = crop_data.sprite_row
	_crop_visual.texture = crop_data.growth_sprite
	_crop_visual.region_rect = Rect2(
		frame_x * FRAME_SIZE,
		row * FRAME_SIZE,
		FRAME_SIZE,
		FRAME_SIZE
	)


# --- Visual Methods ---

func show_tilled() -> void:
	_update_soil_color()
	_crop_visual.visible = false
	if fertility_stacks > 0:
		_growth_label.text = "%s x%d" % [fertility_type.to_upper(), fertility_stacks]
	else:
		_growth_label.text = "TILLED"
	_water_indicator.visible = false


func show_planted() -> void:
	if crop_data == null:
		return
	_crop_visual.visible = true
	_crop_visual.modulate = Color.WHITE
	_set_crop_frame(0)
	_growth_label.text = crop_data.get_active_name()
	_water_indicator.visible = false


func show_watered() -> void:
	_water_indicator.visible = true
	_water_indicator.modulate = Color(1, 1, 1, 0)
	var tw: Tween = create_tween()
	tw.tween_property(_water_indicator, "modulate:a", 1.0, 0.15)


func update_growth_visual() -> void:
	if crop_data == null:
		return
	var effective_days: int = get_effective_growth_days()
	var progress: float = clampf(float(days_grown) / float(effective_days), 0.0, 1.0)
	var frame: int = 1 + int(progress * 4.0)
	frame = clampi(frame, 1, 5)
	_crop_visual.visible = true
	_crop_visual.modulate = Color.WHITE
	_set_crop_frame(frame)
	_growth_label.text = "%d/%d" % [days_grown, effective_days]
	_water_indicator.visible = false


func show_wilting() -> void:
	if crop_data == null:
		return
	_crop_visual.visible = true
	_crop_visual.modulate = Color(0.7, 0.6, 0.4, 1)
	_growth_label.text = "WILTING"
	_water_indicator.visible = false
	_shake()


func show_harvestable() -> void:
	if crop_data == null:
		return
	_crop_visual.visible = true
	_crop_visual.modulate = Color.WHITE
	_set_crop_frame(6)
	_growth_label.text = "READY"
	_water_indicator.visible = false
	_pulse()


func show_harvest_result(food: int, crop_name: String) -> void:
	_spawn_float_text("+%d %s" % [food, crop_name], Color(0.3, 1.0, 0.3, 1))


func show_damage() -> void:
	_crop_visual.modulate = Color(1.0, 0.4, 0.4, 1)
	var tw: Tween = create_tween()
	tw.tween_property(_crop_visual, "modulate", Color.WHITE, 0.3)


# --- Tween Helpers ---

func _tween_modulate(target: Node2D, color: Color) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(target, "modulate", color, TWEEN_SPEED)


func _flash_modulate(target: Node2D, flash: Color) -> void:
	var original: Color = target.modulate
	var tw: Tween = create_tween()
	tw.tween_property(target, "modulate", flash, 0.1)
	tw.tween_property(target, "modulate", original, 0.2)


func _shake() -> void:
	var original_pos: Vector2 = _crop_visual.position
	var tw: Tween = create_tween()
	tw.tween_property(_crop_visual, "position", original_pos + Vector2(3, 0), 0.05)
	tw.tween_property(_crop_visual, "position", original_pos + Vector2(-3, 0), 0.05)
	tw.tween_property(_crop_visual, "position", original_pos + Vector2(2, 0), 0.05)
	tw.tween_property(_crop_visual, "position", original_pos + Vector2(-1, 0), 0.05)
	tw.tween_property(_crop_visual, "position", original_pos, 0.05)


func _pulse() -> void:
	var tw: Tween = create_tween().set_loops()
	tw.tween_property(_crop_visual, "modulate:a", 0.7, 0.6)
	tw.tween_property(_crop_visual, "modulate:a", 1.0, 0.6)


func _spawn_float_text(text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.modulate = color
	label.position = Vector2(-30, -30)
	label.z_index = 10
	add_child(label)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 30, 1.0)
	tw.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.5)
	tw.chain().tween_callback(label.queue_free)
