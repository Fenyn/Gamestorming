class_name CamaroPartData
extends Resource

enum PartSlot {
	ENGINE_BLOCK, HEADS, INTAKE, EXHAUST, CARBURETOR,
	TRANSMISSION, SUSPENSION, BODY_PANELS, INTERIOR,
	ELECTRICAL, PAINT
}

@export var part_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var slot: PartSlot = PartSlot.ENGINE_BLOCK
@export var price: float = 0.0
@export var prerequisites: Array[String] = []
@export var installed_mesh: PackedScene = null
