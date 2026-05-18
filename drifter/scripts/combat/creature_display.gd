class_name CreatureDisplay
extends Control

@onready var _sprite: AnimatedSprite2D = %CreatureSprite

const CREATURE_ANIMS: Dictionary = {
	"lurker": {
		"frame_w": 62, "frame_h": 33, "horizontal": true,
		"anims": {
			"idle": {"path": "res://assets/sprites/enemies/ghoul/static idle.png", "frames": 1, "fps": 1.0, "loop": true},
			"attack": {"path": "res://assets/sprites/enemies/ghoul/Attack.png", "frames": 7, "fps": 10.0, "loop": false},
			"hit": {"path": "res://assets/sprites/enemies/ghoul/hit.png", "frames": 4, "fps": 8.0, "loop": false},
			"death": {"path": "res://assets/sprites/enemies/ghoul/death.png", "frames": 8, "fps": 8.0, "loop": false},
			"wake": {"path": "res://assets/sprites/enemies/ghoul/Wake.png", "frames": 4, "fps": 8.0, "loop": false},
		}
	},
	"spewer": {
		"frame_w": 57, "frame_h": 39, "horizontal": true,
		"anims": {
			"idle": {"path": "res://assets/sprites/enemies/spitter/idle.png", "frames": 6, "fps": 6.0, "loop": true},
			"attack": {"path": "res://assets/sprites/enemies/spitter/attack.png", "frames": 8, "fps": 10.0, "loop": false},
			"hit": {"path": "res://assets/sprites/enemies/spitter/hit.png", "frames": 3, "fps": 8.0, "loop": false},
			"death": {"path": "res://assets/sprites/enemies/spitter/death.png", "frames": 9, "fps": 8.0, "loop": false},
		}
	},
	"hive_caller": {
		"frame_w": 46, "frame_h": 44, "horizontal": true,
		"anims": {
			"idle": {"path": "res://assets/sprites/enemies/summoner/idle.png", "frames": 6, "fps": 6.0, "loop": true},
			"attack": {"path": "res://assets/sprites/enemies/summoner/summon.png", "frames": 9, "fps": 10.0, "loop": false},
			"hit": {"path": "res://assets/sprites/enemies/summoner/hit.png", "frames": 4, "fps": 8.0, "loop": false},
			"death": {"path": "res://assets/sprites/enemies/summoner/death.png", "frames": 10, "fps": 8.0, "loop": false},
		}
	},
	"the_warden": {
		"frame_w": 171, "frame_h": 101, "horizontal": true,
		"anims": {
			"idle": {"path": "res://assets/sprites/boss/Turtle Mech-Idle.png", "frames": 12, "fps": 8.0, "loop": true},
			"attack": {"path": "res://assets/sprites/boss/Turtle Mech-Cannon Blast.png", "frames": 40, "fps": 14.0, "loop": false},
			"hit": {"path": "res://assets/sprites/boss/Turtle Mech-Hit.png", "frames": 3, "fps": 8.0, "loop": false},
			"death": {"path": "res://assets/sprites/boss/Turtle Mech-Death.png", "frames": 15, "fps": 10.0, "loop": false},
			"punch": {"path": "res://assets/sprites/boss/Turtle Mech-Magnetic Punch.png", "frames": 35, "fps": 14.0, "loop": false},
		}
	},
}

var _creature_id: String = ""


func setup(creature_data: CreatureData) -> void:
	_creature_id = creature_data.id


func _ready() -> void:
	_sprite.animation_finished.connect(_on_anim_finished)


func build_anims() -> void:
	if _creature_id.is_empty() or _creature_id not in CREATURE_ANIMS:
		return

	var config: Dictionary = CREATURE_ANIMS[_creature_id]
	var fw: int = config["frame_w"] as int
	var fh: int = config["frame_h"] as int
	var is_horiz: bool = config["horizontal"] as bool

	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")

	var anims: Dictionary = config["anims"]
	for anim_name: String in anims:
		var data: Dictionary = anims[anim_name]
		var tex: Texture2D = load(data["path"]) as Texture2D
		if not tex:
			continue
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, data["fps"] as float)
		sf.set_animation_loop(anim_name, data.get("loop", false) as bool)

		var frame_count: int = data["frames"] as int
		for i: int in frame_count:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			if is_horiz:
				atlas.region = Rect2(i * fw, 0, fw, fh)
			else:
				atlas.region = Rect2(0, i * fh, fw, fh)
			sf.add_frame(anim_name, atlas)

	_sprite.sprite_frames = sf

	if sf.has_animation(&"wake"):
		_sprite.play(&"wake")
	else:
		_sprite.play(&"idle")


func play_attack() -> void:
	_sprite.play(&"attack")


func play_hit() -> void:
	_sprite.play(&"hit")


func play_death() -> void:
	_sprite.play(&"death")


func shake() -> void:
	var origin: Vector2 = _sprite.position
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "position", origin + Vector2(-6, 2), 0.04)
	tween.tween_property(_sprite, "position", origin + Vector2(5, -3), 0.04)
	tween.tween_property(_sprite, "position", origin + Vector2(-3, 1), 0.04)
	tween.tween_property(_sprite, "position", origin + Vector2(2, -1), 0.04)
	tween.tween_property(_sprite, "position", origin, 0.04)


func play_punch() -> void:
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"punch"):
		_sprite.play(&"punch")
	else:
		play_attack()


func _on_anim_finished() -> void:
	match _sprite.animation:
		&"death":
			pass
		&"wake":
			_sprite.stop()
		_:
			_sprite.play(&"idle")
