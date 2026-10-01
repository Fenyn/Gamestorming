class_name ArcaneBackdrop
extends ColorRect
## A non-interactive stone, sigil and mist backdrop over the 3D hall, shared by select, matchup,
## adventure start and the journal. The school colour only lights the sigil halo and the portal.

@export var portrait: bool = false
var _shader: ShaderMaterial
var _clock: float = 24.0
var _color: Color = ZenithTheme.FRAME
var _target: Color = ZenithTheme.FRAME
var _pulse: float = 0.0
var _hall_viewport: SubViewport
var _hall: Node3D
static var reduced_motion: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader = ShaderMaterial.new()
	_shader.shader = preload("res://assets/arcane_backdrop.gdshader")
	_shader.set_shader_parameter("portrait", portrait)
	material = _shader
	# A browser on Windows (ANGLE over Direct3D) takes most of a minute to compile the hall's lit
	# stone and particles on a first visit, so the web build shows the backdrop alone.
	if not portrait and DisplayServer.get_name() != "headless" and not OnlineGate.is_web():
		_hall_viewport = SubViewport.new()
		_hall_viewport.own_world_3d = true
		_hall_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		add_child(_hall_viewport)
		_hall = load("res://scripts/ui/sanctum_set.gd").new()
		_hall_viewport.add_child(_hall)
		var hall_image: TextureRect = TextureRect.new()
		hall_image.texture = _hall_viewport.get_texture()
		hall_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hall_image.stretch_mode = TextureRect.STRETCH_SCALE
		hall_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hall_image.show_behind_parent = true
		add_child(hall_image)
		hall_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_shader.set_shader_parameter("hall_visible", true)
	resized.connect(_resize)
	_resize()


static func motion_reduced() -> bool:
	return reduced_motion or DevArgs.user_args().has("--reduced-motion")


func set_school(color_value: Color, immediate: bool = false) -> void:
	_target = color_value
	if immediate or motion_reduced():
		_color = _target


func set_rival(color_value: Color) -> void:
	_shader.set_shader_parameter("rival_color", color_value)


func confirm() -> void:
	if not motion_reduced():
		_pulse = 1.0


func _resize() -> void:
	_shader.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	if _hall_viewport != null:
		var ratio: float = minf(0.75, 1440.0 / maxf(size.x, 1.0))
		_hall_viewport.size = Vector2i(maxi(2, int(size.x * ratio)), maxi(2, int(size.y * ratio)))


func _process(delta: float) -> void:
	if not motion_reduced():
		_clock += delta
	_color = _target if motion_reduced() else _color.lerp(_target, 1.0 - exp(-delta * 6.0))
	_pulse = 0.0 if motion_reduced() else move_toward(_pulse, 0.0, delta * 2.4)
	_shader.set_shader_parameter("clock", _clock)
	_shader.set_shader_parameter("school_color", _color)
	_shader.set_shader_parameter("pulse", _pulse)
	if _hall != null:
		_hall.set("_school", _color)
		var pointer: Vector2 = get_local_mouse_position() / Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0)) - Vector2.ONE * 0.5
		_hall.set("_pointer", pointer.clamp(-Vector2.ONE * 0.5, Vector2.ONE * 0.5))
