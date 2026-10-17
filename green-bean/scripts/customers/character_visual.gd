class_name CharacterVisual
extends Node3D

## Animated Kenney character with a skin and procedural accessories.
## Used by customers and by background pedestrians. Faces +Z.

const CHARACTER_SCENE := preload("res://assets/models/characters/characterMedium.fbx")
const IDLE_ANIM_SCENE := preload("res://assets/models/characters/idle.fbx")
const RUN_ANIM_SCENE := preload("res://assets/models/characters/run.fbx")
const JUMP_ANIM_SCENE := preload("res://assets/models/characters/jump.fbx")
const SKIN_PATH := "res://assets/models/characters/skins/customer_%02d.png"
const SKIN_COUNT := 10
# characterMedium.fbx imports 3.76 units tall; this scale makes a 1.7 m person.
const BASE_SCALE := 0.4516
# The pack has no walk cycle, so walking is the run played slowly.
# At 2 m/s the run looks right at about 55% speed.
const WALK_ANIM_SPEED_PER_MPS := 0.275
const ANIM_IDLE := "character/idle"
const ANIM_RUN := "character/run"
const ANIM_JUMP := "character/jump"

static var _anim_library: AnimationLibrary = null
static var _skin_materials: Array[StandardMaterial3D] = []

var profile: CustomerProfile = null
var _anim: AnimationPlayer = null
var _skeleton: Skeleton3D = null
var _hand_holder: Node3D = null
var _hand_item: Node3D = null
var _one_shot_playing := false

func setup(p: CustomerProfile) -> void:
	profile = p

func _ready() -> void:
	if profile == null:
		profile = CustomerProfile.generate()
	var character: Node3D = CHARACTER_SCENE.instantiate()
	character.scale = Vector3.ONE * BASE_SCALE * profile.height_scale
	add_child(character)
	var skin := _get_skin_material(profile.skin_index)
	for node in character.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = skin
	var skeletons := character.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0] as Skeleton3D

	# Accessories are measured on the rest pose, so build them before animating.
	_build_accessories()

	_anim = AnimationPlayer.new()
	character.add_child(_anim)
	_anim.add_animation_library("character", _get_anim_library())
	_anim.animation_finished.connect(_on_animation_finished)
	_anim.play(ANIM_IDLE)
	_anim.seek(randf() * 1.0, true)

## Walking speed in metres per second; 0 means stand idle.
func set_moving(speed: float) -> void:
	if _anim == null or _one_shot_playing:
		return
	if speed > 0.1:
		if _anim.current_animation != ANIM_RUN:
			_anim.play(ANIM_RUN, 0.25)
		_anim.speed_scale = speed * WALK_ANIM_SPEED_PER_MPS
	else:
		if _anim.current_animation != ANIM_IDLE:
			_anim.play(ANIM_IDLE, 0.25)
		_anim.speed_scale = 1.0

func play_jump() -> void:
	if _anim == null:
		return
	_one_shot_playing = true
	_anim.speed_scale = 1.0
	_anim.play(ANIM_JUMP, 0.15)

func _on_animation_finished(anim_name: StringName) -> void:
	if String(anim_name) == ANIM_JUMP:
		_one_shot_playing = false
		_anim.play(ANIM_IDLE, 0.2)

## Puts a node in the right hand (phone, takeaway cup). Pass null to empty it.
func hold_in_hand(item: Node3D) -> void:
	if _hand_item and is_instance_valid(_hand_item):
		_hand_item.queue_free()
	_hand_item = item
	if item and _hand_holder:
		_hand_holder.add_child(item)

static func make_phone() -> Node3D:
	var phone := CSGBox3D.new()
	phone.size = Vector3(0.07, 0.13, 0.012)
	phone.position = Vector3(0, 0.02, 0.06)
	phone.rotation_degrees = Vector3(-50, 0, 0)
	phone.material = _mat(Color(0.08, 0.08, 0.1), 0.3)
	return phone

static func make_takeaway_cup() -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0, 0.03, 0.05)
	var cup := CSGCylinder3D.new()
	cup.radius = 0.045
	cup.height = 0.13
	cup.sides = 12
	cup.material = _mat(Color(0.95, 0.95, 0.9), 0.85)
	root.add_child(cup)
	var sleeve := CSGCylinder3D.new()
	sleeve.radius = 0.047
	sleeve.height = 0.045
	sleeve.sides = 12
	sleeve.material = _mat(Color(0.62, 0.45, 0.3), 0.95)
	root.add_child(sleeve)
	var lid := CSGCylinder3D.new()
	lid.radius = 0.049
	lid.height = 0.012
	lid.position.y = 0.07
	lid.sides = 12
	lid.material = _mat(Color(0.2, 0.15, 0.12), 0.4)
	root.add_child(lid)
	return root

# ── Accessories ────────────────────────────────────────────────────────────

## A node that follows a bone but has world-scale, character-facing axes, so
## accessories can be sized in metres. Measured at the rest pose.
func _make_bone_holder(bone: String) -> Node3D:
	if _skeleton == null or _skeleton.find_bone(bone) < 0:
		return null
	var attach := BoneAttachment3D.new()
	attach.bone_name = bone
	_skeleton.add_child(attach)
	var bone_index := _skeleton.find_bone(bone)
	# The attachment only follows the bone after the next skeleton update, so
	# place it by hand now; it keeps the same local transform afterwards.
	var rest := _skeleton.get_bone_global_rest(bone_index)
	attach.transform = rest
	var bone_world: Vector3 = (_skeleton.global_transform * rest).origin
	var holder := Node3D.new()
	attach.add_child(holder)
	var basis := global_transform.basis.orthonormalized().scaled(Vector3.ONE * profile.height_scale)
	holder.global_transform = Transform3D(basis, bone_world)
	return holder

func _build_accessories() -> void:
	var head := _make_bone_holder("Head")
	var chest := _make_bone_holder("Chest")
	_hand_holder = _make_bone_holder("RightHand")
	if head:
		match profile.hat:
			"beanie":
				head.add_child(_make_beanie(profile.accessory_color))
			"cap":
				head.add_child(_make_cap(profile.accessory_color))
		if profile.glasses:
			head.add_child(_make_glasses())
		if profile.headphones:
			head.add_child(_make_headphones(profile.accessory_color_2))
	if chest and profile.backpack:
		chest.add_child(_make_backpack(profile.accessory_color_2))

static var _material_cache := {}

## Shared material per colour, so a crowd doesn't create hundreds of materials.
static func _mat(color: Color, roughness: float = 0.8) -> StandardMaterial3D:
	var key := "%s/%.2f" % [color.to_html(), roughness]
	if _material_cache.has(key):
		return _material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	_material_cache[key] = m
	return m

# Head holder origin is the neck joint (about 1.22 m). The head is a big
# cartoon head: roughly 0.5 m tall and 0.5 m wide, centred about 0.22 m up.
const HEAD_CENTER_Y := 0.22

static func _make_beanie(color: Color) -> Node3D:
	var root := Node3D.new()
	var dome := CSGSphere3D.new()
	dome.radius = 0.26
	dome.radial_segments = 16
	dome.rings = 8
	dome.scale = Vector3(1.0, 0.75, 1.0)
	dome.position = Vector3(0, 0.36, -0.01)
	dome.material = _mat(color, 0.95)
	root.add_child(dome)
	var cuff := CSGCylinder3D.new()
	cuff.radius = 0.265
	cuff.height = 0.07
	cuff.sides = 16
	cuff.position = Vector3(0, 0.34, -0.01)
	cuff.material = _mat(color.darkened(0.2), 0.95)
	root.add_child(cuff)
	return root

static func _make_cap(color: Color) -> Node3D:
	var root := Node3D.new()
	var crown := CSGSphere3D.new()
	crown.radius = 0.255
	crown.radial_segments = 16
	crown.rings = 8
	crown.scale = Vector3(1.0, 0.6, 1.0)
	crown.position = Vector3(0, 0.38, -0.01)
	crown.material = _mat(color, 0.9)
	root.add_child(crown)
	var brim := CSGBox3D.new()
	brim.size = Vector3(0.3, 0.025, 0.2)
	brim.position = Vector3(0, 0.37, 0.27)
	brim.material = _mat(color.darkened(0.25), 0.9)
	root.add_child(brim)
	return root

static func _make_glasses() -> Node3D:
	var root := Node3D.new()
	var frame := _mat(Color(0.1, 0.08, 0.07), 0.4)
	for side in [-1.0, 1.0]:
		var lens := CSGCylinder3D.new()
		lens.radius = 0.06
		lens.height = 0.015
		lens.sides = 12
		lens.rotation_degrees = Vector3(90, 0, 0)
		lens.position = Vector3(0.1 * float(side), 0.2, 0.235)
		lens.material = frame
		root.add_child(lens)
	var bridge := CSGBox3D.new()
	bridge.size = Vector3(0.08, 0.015, 0.015)
	bridge.position = Vector3(0, 0.21, 0.24)
	bridge.material = frame
	root.add_child(bridge)
	return root

static func _make_headphones(color: Color) -> Node3D:
	var root := Node3D.new()
	var dark := _mat(Color(0.12, 0.12, 0.14), 0.5)
	# Headband: the top half of a ring running ear to ear over the crown.
	# CSGTorus3D lies flat around Y; turning it 90 degrees about X stands it up
	# facing forward, so it spans left-right. A box below the centre cuts off
	# the lower half so nothing crosses the face or chin.
	var band := CSGTorus3D.new()
	band.inner_radius = 0.27
	band.outer_radius = 0.31
	band.sides = 20
	band.ring_sides = 6
	band.rotation_degrees = Vector3(90, 0, 0)
	band.position = Vector3(0, HEAD_CENTER_Y, -0.02)
	band.material = dark
	var cut := CSGBox3D.new()
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut.size = Vector3(0.8, 0.8, 0.4)
	# In the band's own space, Z points down after the X rotation.
	cut.position = Vector3(0, 0, 0.2)
	band.add_child(cut)
	root.add_child(band)
	for side in [-1.0, 1.0]:
		var cup := CSGCylinder3D.new()
		cup.radius = 0.08
		cup.height = 0.07
		cup.sides = 14
		cup.rotation_degrees = Vector3(0, 0, 90)
		cup.position = Vector3(0.28 * float(side), HEAD_CENTER_Y, -0.02)
		cup.material = _mat(color, 0.5)
		root.add_child(cup)
	return root

static func _make_backpack(color: Color) -> Node3D:
	var root := Node3D.new()
	var bag := CSGBox3D.new()
	bag.size = Vector3(0.3, 0.34, 0.14)
	bag.position = Vector3(0, -0.02, -0.19)
	bag.material = _mat(color, 0.9)
	root.add_child(bag)
	var pocket := CSGBox3D.new()
	pocket.size = Vector3(0.22, 0.14, 0.05)
	pocket.position = Vector3(0, -0.1, -0.27)
	pocket.material = _mat(color.darkened(0.25), 0.9)
	root.add_child(pocket)
	return root

# ── Shared resources ───────────────────────────────────────────────────────

static func _get_skin_material(index: int) -> StandardMaterial3D:
	if _skin_materials.is_empty():
		for i in range(SKIN_COUNT):
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = load(SKIN_PATH % (i + 1))
			mat.roughness = 0.9
			_skin_materials.append(mat)
	return _skin_materials[index % _skin_materials.size()]

## Idle, run and jump come from separate FBX files that share the character's
## skeleton. Copy their animations into one library, once.
static func _get_anim_library() -> AnimationLibrary:
	if _anim_library:
		return _anim_library
	_anim_library = AnimationLibrary.new()
	_anim_library.add_animation("idle", _extract_animation(IDLE_ANIM_SCENE, "Idle", true))
	_anim_library.add_animation("run", _extract_animation(RUN_ANIM_SCENE, "Run", true))
	_anim_library.add_animation("jump", _extract_animation(JUMP_ANIM_SCENE, "Jump", false))
	return _anim_library

static func _extract_animation(scene: PackedScene, name_suffix: String, looping: bool) -> Animation:
	var root := scene.instantiate()
	var found: Animation = null
	for node in root.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		for anim_name in player.get_animation_list():
			if String(anim_name).ends_with(name_suffix):
				found = player.get_animation(anim_name).duplicate() as Animation
	root.free()
	if found == null:
		push_warning("CharacterVisual: no '%s' animation found" % name_suffix)
		return Animation.new()
	found.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	return found
