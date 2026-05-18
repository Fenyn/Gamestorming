class_name MedalFactory
extends RefCounted

const MEDAL_DEFS: Array[Dictionary] = [
	{"type": MedalData.MedalType.MOVE, "label": "+AP", "value": 1, "color": Color(0.3, 0.7, 1.0)},
	{"type": MedalData.MedalType.DAMAGE, "label": "+DMG", "value": 5, "color": Color(1.0, 0.4, 0.3)},
	{"type": MedalData.MedalType.DEFENSE, "label": "+DEF", "value": 5, "color": Color(0.3, 0.6, 1.0)},
	{"type": MedalData.MedalType.ACCURACY, "label": "+ACC", "value": 10, "color": Color(0.9, 0.8, 0.2)},
	{"type": MedalData.MedalType.MELEE, "label": "+MEL", "value": 10, "color": Color(0.8, 0.4, 0.9)},
]


static func create_random() -> MedalData:
	var def: Dictionary = MEDAL_DEFS[randi() % MEDAL_DEFS.size()]
	var medal: MedalData = MedalData.new()
	medal.medal_type = def["type"] as MedalData.MedalType
	medal.label = def["label"] as String
	medal.buff_value = def["value"] as int
	medal.color = def["color"] as Color
	return medal
