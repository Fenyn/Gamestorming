# Builds the Treat Wounds heal (first aid: a linen roll, two turns of bandage and a knot round the
# chest, a pinch of powder, a few plain sparkles once it is done) and saves it as
# res://scenes/fx/treat_wounds.tscn. Every number lives here; a review round edits this file and
# rebuilds. Frames: draw_treat_frames.py. Round log: tools/vfx/treat_wounds/NOTES.md.
#
#   <mono console exe> --path . --headless -s res://tools/vfx/treat_wounds/build_treat_wounds.gd
#   ... -- --low=1 --out=res://tools/vfx/treat_wounds/rat_test.tscn   (rat check only)
#
# HD-2D: every layer is a pixel-art flipbook on the locked palette, sampled nearest, one texel
# = PX metres at Body scale 1. The wraps are drawn on the unit sprites' own pixel grids, so Body is
# scaled by the sprite's PixelSize / PX and each wrap texel lands on a sprite texel.
#
# The game and the capture restart every emitter at t = 0, so each layer's delay is drawn into
# its frames (leading empty cells).
#
# Layout: the root sits at the unit's feet. Body (y = 0) holds two sets: Tall (the hero's wrap and
# sparkles) and Low (the rat's, hidden by default). Ground is empty: nothing here touches the floor.
extends SceneTree

const OUT := "res://scenes/fx/treat_wounds.tscn"
const SHADER_DIR := "res://assets/shaders/vfx/"
const TEX_DIR := "res://assets/fx/treat_wounds/"
const LIT_SHADER := "res://assets/fx/treat_wounds/pixel_lit_flipbook.gdshader"
const SCRIPT := "res://scripts/fx/TreatWounds.cs"
const PX := 0.028  # metres per texel at Body scale 1
# The wrap cells share the sprites' layout, so each quad is centred where its sprite is: the hero
# sprite (72 rows, feet on row 65) 30 texels above the feet, the rat (44 rows, feet on row 41) 20.
const WRAP_CENTRE := 30.0 * PX
const WRAP_LOW_CENTRE := 20.0 * PX
const WRAP_FRAMES := 17
const WRAP_LIFE := 1.36  # 80 ms a frame
const CHEST := 0.98  # hero chest rows 28 to 32, above the feet
const LOW_CHEST := 0.45

const LANTERN := Color(1.0, 0.72, 0.42)  # hand_lantern.tscn


func _initialize() -> void:
	var opts := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var eq: int = arg.find("=")
			opts[arg.substr(2, eq - 2)] = arg.substr(eq + 1)
	var out_path: String = String(opts.get("out", OUT))
	var body_scale: float = float(opts.get("fx-scale", "1.0"))
	var low: bool = opts.get("low", "0") == "1"

	var root := Node3D.new()
	root.name = "TreatWounds"
	var ground := Node3D.new()
	ground.name = "Ground"
	root.add_child(ground)
	var body := Node3D.new()
	body.name = "Body"
	body.scale = Vector3.ONE * body_scale
	root.add_child(body)
	var tall := Node3D.new()
	tall.name = "Tall"
	tall.visible = not low
	body.add_child(tall)
	var short := Node3D.new()
	short.name = "Low"
	short.visible = low
	body.add_child(short)

	_add_wrap(tall, "Wrap", "wrap.png", 72, WRAP_CENTRE)
	# born on the band, so they read as glints on fresh linen (r17's sparkles above the band, beside
	# the face, lost the blind A/B: they read as a spell twinkle)
	_add_sparkles(tall, "Sparkles", 4, CHEST, Vector3(0.18, 0.06, 0.08), 0.1, 0.2)
	_add_wrap(short, "WrapLow", "wrap_low.png", 44, WRAP_LOW_CENTRE)
	_add_sparkles(short, "SparklesLow", 2, LOW_CHEST - 0.1, Vector3(0.2, 0.04, 0.08), 0.05, 0.1)
	_add_light(root)

	if ResourceLoader.exists(SCRIPT):
		root.set_script(load(SCRIPT))
	_own(root, root)
	for n in [ground, body, tall, short]:
		n.unique_name_in_owner = true
	var packed := PackedScene.new()
	var err: Error = packed.pack(root)
	if err != OK:
		push_error("pack failed: %d" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, out_path)
	if err != OK:
		push_error("save failed: %d" % err)
		quit(1)
		return
	print("BUILT ", ProjectSettings.globalize_path(out_path))
	quit()


# The bandage: one hand-timed flipbook on the sprite's grid. Roll on the chest, two turns, pulled
# taut, the knot, a pinch of powder; held, then faded evenly from 1.05 to 1.35 s. Drawn over the
# unit (depth_pull) because it lies on its body.
func _add_wrap(parent: Node3D, name: String, texture: String, rows: int, centre: float) -> void:
	var p := _emitter(name, 1, WRAP_LIFE)
	p.explosiveness = 1.0
	p.position = Vector3(0.0, centre, 0.0)
	var m := _still()
	var fade_from: float = 1.05 / WRAP_LIFE
	var gone_at: float = 1.35 / WRAP_LIFE
	m.color_ramp = _ramp([[0.0, Color.WHITE], [fade_from, Color.WHITE], [gone_at, Color(1, 1, 1, 0)], [1.0, Color(1, 1, 1, 0)]])
	p.process_material = m
	p.draw_pass_1 = _quad(32, rows)
	# lit, unlike the VFX Essential shaders: linen on a unit takes the room's light like the unit
	var mat := ShaderMaterial.new()
	mat.shader = load(LIT_SHADER)
	mat.set_shader_parameter("frames", load(TEX_DIR + texture))
	mat.set_shader_parameter("h_frames", WRAP_FRAMES)
	mat.set_shader_parameter("depth_pull", 0.4)
	mat.render_priority = 1
	p.draw_pass_1.surface_set_material(0, mat)
	parent.add_child(p)


# "Feels better": a few small plain sparkles rising slowly from the chest once the wrap is on.
# Frames 0 to 5 of each are empty, so they show from 0.6 s; no bloom (emission 1).
func _add_sparkles(parent: Node3D, name: String, amount: int, height: float, extents: Vector3, v_min: float, v_max: float) -> void:
	var p := _emitter(name, amount, 1.0)
	p.explosiveness = 0.7
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = extents
	m.emission_shape_offset = Vector3(0.0, height, 0.0)
	m.direction = Vector3(0.0, 1.0, 0.0)
	m.spread = 10.0
	m.initial_velocity_min = v_min
	m.initial_velocity_max = v_max
	m.damping_min = 0.05
	m.damping_max = 0.1
	m.gravity = Vector3.ZERO
	m.anim_speed_min = 1.0
	m.anim_speed_max = 1.0
	p.process_material = m
	p.draw_pass_1 = _quad(7, 7)
	var mat := _flipbook("pixel_mix", "sparkle.png", 10, 2, 1)
	# under 1, so in a dark room the glint is no brighter than the lit linen it rises from
	mat.set_shader_parameter("emission_scaler", 0.8)
	mat.set_shader_parameter("depth_pull", 0.3)
	mat.render_priority = 2
	p.draw_pass_1.surface_set_material(0, mat)
	parent.add_child(p)


# A faint lantern-coloured light on the chest while the medic works, on Anim "play".
func _add_light(root: Node3D) -> void:
	var light := OmniLight3D.new()
	light.name = "Light"
	light.unique_name_in_owner = true
	# above the head with a short reach: a faint lift on the head and shoulders, no hot spot on
	# the lit wrap (a light on the unit's axis sits almost on the billboards) and no floor pool
	light.position = Vector3(0.0, 1.9, 0.0)
	light.light_color = LANTERN
	light.light_energy = 0.0
	light.omni_range = 1.1
	light.shadow_enabled = false
	root.add_child(light)
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	ap.unique_name_in_owner = true
	var anim := Animation.new()
	anim.length = 0.9
	var track: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath("Light:light_energy"))
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, 0.1, 0.3)
	anim.track_insert_key(track, 0.6, 0.3)
	anim.track_insert_key(track, 0.9, 0.0)
	var lib := AnimationLibrary.new()
	lib.add_animation("play", anim)
	ap.add_animation_library("", lib)
	root.add_child(ap)


func _emitter(name: String, amount: int, lifetime: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = name
	p.unique_name_in_owner = true
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.emitting = false
	p.local_coords = true
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


# A process material for a particle that stays where it is born.
func _still() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	m.gravity = Vector3.ZERO
	m.anim_speed_min = 1.0
	m.anim_speed_max = 1.0
	return m


# Camera-facing quad of w x h texels.
func _quad(w: int, h: int) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(float(w), float(h)) * PX
	return q


func _vfx(kind: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_DIR + "vfx_essential_%s.gdshader" % kind)
	return mat


# mode 0 plays the whole sheet once over the life; mode 1 gives each particle one random row.
func _flipbook(kind: String, texture: String, h: int, v: int, mode: int) -> ShaderMaterial:
	var mat := _vfx(kind)
	mat.set_shader_parameter("diffuse1", load(TEX_DIR + texture))
	mat.set_shader_parameter("diffuse1_wrap", 1)
	mat.set_shader_parameter("flipbook_enabled", true)
	mat.set_shader_parameter("flipbook_h_frames", h)
	mat.set_shader_parameter("flipbook_v_frames", v)
	mat.set_shader_parameter("flipbook_mode", mode)
	mat.set_shader_parameter("flipbook_loop", false)
	mat.set_shader_parameter("flipbook_blend", false)
	return mat


# stops: [[offset, Color], ...] in ascending order; add_point does not sort
func _gradient(stops: Array) -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for s in stops:
		offsets.append(s[0])
		colors.append(s[1])
	g.offsets = offsets
	g.colors = colors
	return g


func _ramp(stops: Array) -> GradientTexture1D:
	var t := GradientTexture1D.new()
	t.gradient = _gradient(stops)
	t.width = 128
	return t


func _own(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_own(c, owner)
