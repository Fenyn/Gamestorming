extends Node3D

const PAD: float = 2.0
const MAX_ROW_WIDTH: float = 120.0

var _mouse_captured: bool = false

@onready var _player: CharacterBody3D = $Player
@onready var _camera: Camera3D = $Player/Camera3D

var _camera_rot_x: float = 0.0
var _camera_rot_y: float = 0.0

var _asset_folders: Array[String] = [
	"res://assets/buildings",
	"res://assets/props",
	"res://assets/nature",
	"res://assets/animals",
	"res://assets/vehicles",
]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true
	_spawn_all_assets()


func _get_aabb(node: Node3D) -> AABB:
	var combined: AABB = AABB()
	var found: bool = false
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			var mesh_aabb: AABB = mi.get_aabb()
			var transformed: AABB = mi.transform * mesh_aabb
			if not found:
				combined = transformed
				found = true
			else:
				combined = combined.merge(transformed)
		if child is Node3D:
			var child_aabb: AABB = _get_aabb(child as Node3D)
			if child_aabb.size != Vector3.ZERO:
				if not found:
					combined = child_aabb
					found = true
				else:
					combined = combined.merge(child_aabb)
	return combined


func _add_mesh_collision(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi.mesh != null:
				mi.create_trimesh_collision()
		if child is Node:
			_add_mesh_collision(child)


func _spawn_all_assets() -> void:
	var cursor_x: float = 0.0
	var cursor_z: float = 0.0
	var row_max_depth: float = 0.0

	for folder_path in _asset_folders:
		var dir: DirAccess = DirAccess.open(folder_path)
		if dir == null:
			continue

		# Collect and sort file names
		var files: Array[String] = []
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".glb"):
				files.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		files.sort()

		# New row for each category
		if cursor_x > 0.0:
			cursor_z += row_max_depth + PAD * 3.0
			cursor_x = 0.0
			row_max_depth = 0.0

		# Section header
		var section_label: Label3D = Label3D.new()
		section_label.text = folder_path.get_file().to_upper()
		section_label.position = Vector3(0.0, 5.0, cursor_z)
		section_label.font_size = 72
		section_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		section_label.modulate = Color.YELLOW
		add_child(section_label)
		cursor_z += PAD

		for fname in files:
			var full_path: String = folder_path + "/" + fname
			var scene: PackedScene = load(full_path) as PackedScene
			if scene == null:
				continue

			var instance: Node3D = scene.instantiate() as Node3D
			add_child(instance)

			# Generate trimesh collision from every mesh
			_add_mesh_collision(instance)

			# Measure after adding to tree so transforms resolve
			var aabb: AABB = _get_aabb(instance)
			var width: float = maxf(aabb.size.x, 1.0)
			var depth: float = maxf(aabb.size.z, 1.0)

			# Wrap to next row if this item would exceed max width
			if cursor_x > 0.0 and cursor_x + width > MAX_ROW_WIDTH:
				cursor_z += row_max_depth + PAD * 2.0
				cursor_x = 0.0
				row_max_depth = 0.0

			# Position: offset so the model's min corner aligns with cursor
			var offset_x: float = -aabb.position.x
			var offset_z: float = -aabb.position.z
			instance.position = Vector3(cursor_x + offset_x, 0.0, cursor_z + offset_z)

			# Name label above, scaled to model size
			var label: Label3D = Label3D.new()
			var display_name: String = fname.replace(".glb", "").replace("SM_", "")
			var height: float = maxf(aabb.size.y, 1.0)
			label.text = display_name
			label.position = Vector3(cursor_x + width * 0.5, height + 0.5, cursor_z + depth * 0.5)
			var label_scale: float = clampf(maxf(width, depth) * 0.15, 0.5, 3.0)
			label.pixel_size = 0.005 * label_scale
			label.font_size = 48
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.modulate = Color.WHITE
			label.outline_size = 8
			label.outline_modulate = Color.BLACK
			add_child(label)

			cursor_x += width + PAD
			row_max_depth = maxf(row_max_depth, depth)

		# Gap between categories
		cursor_z += row_max_depth + PAD * 4.0
		cursor_x = 0.0
		row_max_depth = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_camera_rot_y -= motion.relative.x * 0.002
		_camera_rot_x -= motion.relative.y * 0.002
		_camera_rot_x = clampf(_camera_rot_x, -PI / 2.0, PI / 2.0)
		_player.rotation.y = _camera_rot_y
		_camera.rotation.x = _camera_rot_x

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			if _mouse_captured:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_mouse_captured = false
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_mouse_captured = true


func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var speed: float = 10.0
	if Input.is_action_pressed("sprint"):
		speed = 25.0

	var direction: Vector3 = (_player.transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if Input.is_action_pressed("jump"):
		_player.velocity.y = 5.0
	else:
		_player.velocity.y -= 20.0 * delta

	if direction != Vector3.ZERO:
		_player.velocity.x = direction.x * speed
		_player.velocity.z = direction.z * speed
	else:
		_player.velocity.x = move_toward(_player.velocity.x, 0.0, speed)
		_player.velocity.z = move_toward(_player.velocity.z, 0.0, speed)

	_player.move_and_slide()
