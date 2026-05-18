class_name ModuleData
extends Resource

enum EffectType { DAMAGE, SHIELD, HEAL, DEBUFF_WEAK, DEBUFF_VULNERABLE, BUFF_STRENGTH }
enum AttackAnim { MELEE_COMBO, SUPERCHARGED, RANGED_ORB, BLASTER_LIGHT, BLASTER_HEAVY, DASH }
enum Category { KINETIC, RESONANCE, SIPHON, OVERCHARGE, VOLATILE }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var category: Category = Category.KINETIC

@export_group("Sockets")
@export var socket_requirements: Array[SocketRequirement] = []

@export_group("Effect")
@export var effect_type: EffectType = EffectType.DAMAGE
@export var base_value: int = 0
@export var pip_scaling: float = 0.0

@export_group("Behavior")
@export var fires_per_turn: int = 1

@export_group("Grid")
@export var grid_shape: Array[Vector2i] = [Vector2i.ZERO]

@export_group("Visuals")
@export var attack_anim: AttackAnim = AttackAnim.MELEE_COMBO


func get_rotated_shape(rotations: int) -> Array[Vector2i]:
	var shape: Array[Vector2i] = grid_shape.duplicate()
	for _r: int in rotations % 4:
		var rotated: Array[Vector2i] = []
		for cell: Vector2i in shape:
			rotated.append(Vector2i(-cell.y, cell.x))
		var min_x: int = 0
		var min_y: int = 0
		for cell: Vector2i in rotated:
			min_x = mini(min_x, cell.x)
			min_y = mini(min_y, cell.y)
		shape.clear()
		for cell: Vector2i in rotated:
			shape.append(Vector2i(cell.x - min_x, cell.y - min_y))
	return shape


func get_difficulty() -> int:
	var difficulty: int = 0
	for req: SocketRequirement in socket_requirements:
		match req.type:
			SocketRequirement.Type.ANY:
				difficulty += 1
			SocketRequirement.Type.SPECIFIC:
				difficulty += 5
			SocketRequirement.Type.RANGE:
				difficulty += 3
			SocketRequirement.Type.PARITY:
				difficulty += 2
			SocketRequirement.Type.MATCH:
				difficulty += 4
			SocketRequirement.Type.SEQUENCE:
				difficulty += 4
			SocketRequirement.Type.SUM:
				difficulty += 3
	return difficulty
