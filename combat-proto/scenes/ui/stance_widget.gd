class_name StanceWidget
extends Control

@export var widget_radius: float = 40.0
@export var dot_radius_active: float = 10.0
@export var dot_radius_inactive: float = 6.0
@export var active_color: Color = Color(0.2, 0.85, 1.0, 1.0)
@export var inactive_color: Color = Color(0.4, 0.4, 0.5, 0.5)
@export var line_color: Color = Color(0.5, 0.5, 0.6, 0.3)
@export var label_color: Color = Color(0.7, 0.7, 0.8, 0.8)

var _current_direction: StanceDirection.Direction = StanceDirection.Direction.TOP
var _target_fighter: Node = null
var _flash_timer: float = 0.0
var _flash_color: Color = Color.WHITE


func setup(fighter: Node) -> void:
	_target_fighter = fighter
	EventBus.stance_changed.connect(_on_stance_changed)


func flash(color: Color, duration: float = 0.3) -> void:
	_flash_color = color
	_flash_timer = duration


func _on_stance_changed(fighter: Node, new_direction: int) -> void:
	if fighter == _target_fighter:
		_current_direction = new_direction as StanceDirection.Direction
		queue_redraw()


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		queue_redraw()


func _draw() -> void:
	var center: Vector2 = size / 2.0

	var positions: Dictionary = {}
	for dir: int in [StanceDirection.Direction.TOP, StanceDirection.Direction.BOTTOM_LEFT, StanceDirection.Direction.BOTTOM_RIGHT]:
		var unit: Vector2 = StanceDirection.to_widget_position(dir as StanceDirection.Direction)
		positions[dir] = center + unit * widget_radius

	var dirs: Array[int] = [StanceDirection.Direction.TOP, StanceDirection.Direction.BOTTOM_LEFT, StanceDirection.Direction.BOTTOM_RIGHT]
	for i: int in range(dirs.size()):
		var next: int = (i + 1) % dirs.size()
		draw_line(positions[dirs[i]], positions[dirs[next]], line_color, 2.0, true)

	var labels: Dictionary = {
		StanceDirection.Direction.TOP: "T",
		StanceDirection.Direction.BOTTOM_LEFT: "BL",
		StanceDirection.Direction.BOTTOM_RIGHT: "BR",
	}

	for dir: int in dirs:
		var pos: Vector2 = positions[dir]
		var is_active: bool = dir == _current_direction
		var color: Color = active_color if is_active else inactive_color
		var radius: float = dot_radius_active if is_active else dot_radius_inactive

		if is_active and _flash_timer > 0.0:
			color = _flash_color

		if is_active:
			draw_circle(pos, radius + 3.0, Color(color.r, color.g, color.b, 0.2))
		draw_circle(pos, radius, color)

		var label_text: String = labels[dir]
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 12
		var text_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var label_offset: Vector2 = StanceDirection.to_widget_position(dir as StanceDirection.Direction) * 16.0
		draw_string(font, pos + label_offset - text_size / 2.0 + Vector2(0, font_size * 0.35), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, label_color)
