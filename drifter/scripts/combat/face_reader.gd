class_name FaceReader

# Maps local-space face normals to pip values.
# Standard D6: opposite faces sum to 7.
# These MUST be calibrated after FBX import — rotate the die to known
# orientations in a test scene and verify each mapping.
const FACE_NORMALS: Array[Vector3] = [
	Vector3.UP,
	Vector3.DOWN,
	Vector3.RIGHT,
	Vector3.LEFT,
	Vector3.FORWARD,
	Vector3.BACK,
]
const FACE_VALUES: Array[int] = [1, 6, 2, 5, 3, 4]


static func read_top_face(die: Node3D) -> int:
	var best_dot: float = -1.0
	var best_value: int = 1
	for i: int in FACE_NORMALS.size():
		var world_normal: Vector3 = die.global_transform.basis * FACE_NORMALS[i]
		var dot: float = world_normal.dot(Vector3.UP)
		if dot > best_dot:
			best_dot = dot
			best_value = FACE_VALUES[i]
	return best_value
