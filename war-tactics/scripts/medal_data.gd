class_name MedalData
extends Resource

enum MedalType { MOVE, DAMAGE, DEFENSE, ACCURACY, MELEE }

@export var medal_type: MedalType = MedalType.MOVE
@export var label: String = ""
@export var buff_value: int = 0
@export var color: Color = Color.WHITE
