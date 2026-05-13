class_name CreatureData
extends Resource

@export var id: String = ""
@export var display_name: String = ""

@export_group("Stats")
@export var max_hp: int = 20

@export_group("Behavior")
@export var intent_pattern: Array[IntentData] = []

@export_group("Visuals")
@export var sprite_frames: SpriteFrames
@export var is_boss: bool = false
