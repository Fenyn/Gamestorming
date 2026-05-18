class_name DrifterDisplay
extends Control

@onready var _sprite: AnimatedSprite2D = %DrifterSprite

const FRAME_W: int = 128
const FRAME_H: int = 64

const ANIM_DATA: Dictionary = {
	"idle": {"path": "res://assets/sprites/hero/Idle.png", "frames": 1, "fps": 1.0, "loop": true},
	"melee": {"path": "res://assets/sprites/hero/Chain Attack.png", "frames": 17, "fps": 14.0, "loop": false},
	"supercharged": {"path": "res://assets/sprites/hero/Supercharged attack.png", "frames": 14, "fps": 12.0, "loop": false},
	"dash": {"path": "res://assets/sprites/hero/dash teleport.png", "frames": 7, "fps": 10.0, "loop": false},
	"hit": {"path": "res://assets/sprites/hero/damaged & death & knock back.png", "frames": 4, "fps": 8.0, "loop": false},
	"death": {"path": "res://assets/sprites/hero/damaged & death & knock back.png", "frames": 8, "fps": 8.0, "loop": false, "offset": 4},
	"blaster_light": {"path": "res://assets/sprites/hero_addons/blaster light.png", "frames": 6, "fps": 10.0, "loop": false},
	"blaster_heavy": {"path": "res://assets/sprites/hero_addons/blaster heavy.png", "frames": 7, "fps": 10.0, "loop": false},
	"ranged_orb": {"path": "res://assets/sprites/hero_addons/attack 4.png", "frames": 10, "fps": 10.0, "loop": false},
}


func _ready() -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")

	for anim_name: String in ANIM_DATA:
		var data: Dictionary = ANIM_DATA[anim_name]
		var tex: Texture2D = load(data["path"]) as Texture2D
		if not tex:
			continue
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, data["fps"] as float)
		sf.set_animation_loop(anim_name, data.get("loop", false) as bool)

		var frame_offset: int = data.get("offset", 0) as int
		var frame_count: int = data["frames"] as int
		for i: int in frame_count:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(0, (frame_offset + i) * FRAME_H, FRAME_W, FRAME_H)
			sf.add_frame(anim_name, atlas)

	_sprite.sprite_frames = sf
	_sprite.play(&"idle")
	_sprite.animation_finished.connect(_on_anim_finished)


func play_attack(attack_anim: ModuleData.AttackAnim) -> void:
	var anim_name: StringName
	match attack_anim:
		ModuleData.AttackAnim.MELEE_COMBO:
			anim_name = &"melee"
		ModuleData.AttackAnim.SUPERCHARGED:
			anim_name = &"supercharged"
		ModuleData.AttackAnim.RANGED_ORB:
			anim_name = &"ranged_orb"
		ModuleData.AttackAnim.BLASTER_LIGHT:
			anim_name = &"blaster_light"
		ModuleData.AttackAnim.BLASTER_HEAVY:
			anim_name = &"blaster_heavy"
		ModuleData.AttackAnim.DASH:
			anim_name = &"dash"
	_sprite.play(anim_name)


func play_hit() -> void:
	_sprite.play(&"hit")


func play_death() -> void:
	_sprite.play(&"death")


func shake() -> void:
	var origin: Vector2 = _sprite.position
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "position", origin + Vector2(6, -2), 0.04)
	tween.tween_property(_sprite, "position", origin + Vector2(-5, 3), 0.04)
	tween.tween_property(_sprite, "position", origin + Vector2(3, -1), 0.04)
	tween.tween_property(_sprite, "position", origin + Vector2(-2, 1), 0.04)
	tween.tween_property(_sprite, "position", origin, 0.04)


func _on_anim_finished() -> void:
	if _sprite.animation != &"death":
		_sprite.play(&"idle")
