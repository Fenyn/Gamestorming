class_name CellData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

@export_group("Faces")
@export var faces: Array[int] = [1, 2, 3, 4, 5, 6]

@export_group("Flags")
@export var is_wild: bool = false

@export_group("Visuals")
@export var tint: Color = Color(0.3, 0.9, 0.95)
@export var glow_color: Color = Color(0.4, 0.8, 0.9)


func roll() -> int:
	return faces[randi() % faces.size()]


func get_min_face() -> int:
	var result: int = 999
	for f: int in faces:
		result = mini(result, f)
	return result


func get_max_face() -> int:
	var result: int = 0
	for f: int in faces:
		result = maxi(result, f)
	return result


func get_face_summary() -> String:
	if is_wild:
		return "Wild"
	var unique: Array[int] = []
	for f: int in faces:
		if f not in unique:
			unique.append(f)
	unique.sort()
	if unique.size() == faces.size():
		return str(get_min_face()) + "-" + str(get_max_face())
	var parts: Array[String] = []
	for f: int in unique:
		var count: int = faces.count(f)
		if count > 1:
			parts.append(str(f) + "x" + str(count))
		else:
			parts.append(str(f))
	return ", ".join(parts)
