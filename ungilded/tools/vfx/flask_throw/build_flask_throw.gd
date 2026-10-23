# Builds the thrown acid flask (the projectile that lobs from the thrower's hand to the target
# before the acid splash) and saves it as res://scenes/fx/flask_throw.tscn. Every number lives
# here; a review round edits this file and rebuilds. Frames: draw_flask.py. Round log:
# tools/vfx/flask_throw/NOTES.md.
#
#   <mono console exe> --path . --headless -s res://tools/vfx/flask_throw/build_flask_throw.gd
#   ... -- --handoff=1   also writes HANDOFF, a review scene only: this throw plus the acid splash
#                        on the rat at the sheet's end, set up as the presenter sets it for a rat
#
# HD-2D: every layer is pixel art on the locked palette, sampled nearest, one texel = PX metres
# at scale 1, the Prologue sprites' PixelSize. FlaskThrow.cs scales %Flask and %Shadow by the
# thrower's sprite pixel size over PX.
#
# Layout: the root sits at the thrower's feet. %Body/%Flask is the flask (one particle whose
# flipbook is the tumble), carrying %Trail (drops shed in world space). %Ground/%Shadow
# is a flat disc on the floor under the flask. In the game FlaskThrow.cs moves %Flask and %Shadow
# along the arc from Start to End on its tween and never plays %Anim. %Anim's "play" exists for the
# contact sheets only: it flies the fixed SHEET_* throw (4 tiles toward +X in SHEET_FLIGHT s) by
# keying Body/Flask:position, Ground/Shadow:position, :frame, :modulate and :visible, and
# Body/Flask/Trail:emitting.
extends SceneTree

const OUT := "res://scenes/fx/flask_throw.tscn"
const HANDOFF := "res://tools/vfx/flask_throw/handoff_test.tscn"
const SPLASH := "res://scenes/fx/acid_splash.tscn"
# The presenter's splash on a rat: ImpactHeight = HP bar 0.53 x 0.6, Body scale = FxScale floor
# 0.66 x AcidSplash.BodyPixelScale 1.08.
const SPLASH_IMPACT := 0.318
const SPLASH_BODY_SCALE := 0.713
const SHADER_DIR := "res://assets/shaders/vfx/"
const TEX_DIR := "res://assets/fx/flask_throw/"
const SCRIPT := "res://scripts/fx/FlaskThrow.cs"
const PX := 0.02  # metres per texel at scale 1

const FLASK_CELL := 17
const FLASK_FRAMES := 8
# Turns over the flight. The flipbook loops, so 1.75 plays the eight frames fourteen times, a new
# frame every 32 ms of the 0.45 s sheet flight: at 1.5 two sheet tiles 33 ms apart showed the same
# frame (review 2). The flask leaves the hand cork up.
const TURNS := 1.75
const TRAIL_CELL := 4
const SHADOW_FRAMES := 6  # discs 11 down to 6 texels across

# Shadow from the flask's height above the surface under it (in the game the drawn board surface
# FlaskThrow.cs samples, on the sheets the line between the two feet): frame = clamp(round(h *
# FRAMES_PER_M - LIFT), 0, FRAMES - 1), alpha = clamp(ALPHA_GROUND - h * ALPHA_PER_M, ALPHA_MIN,
# ALPHA_GROUND), times clamp((left - GONE_M) / FADE_M, 0, 1), where left is the ground track still
# to go. At the sheet's heights: 11 texels and 0.61 at the rat's 0.32 m, 10 and 0.56 at the hand's
# 0.71 m, 6 and 0.44 at the 1.72 m apex, so it shrinks and lightens toward the top (the user asked
# for a realistic shadow, 2026-10-22). At alpha 0.36 and 6 texels the apex shadow vanished at 24 m
# on the grid stage (r02), and at 0.71 the landing shadow was the darkest thing on screen (review 1). The fade keeps it from showing
# as a black tuft above the target's back as the flask comes down beside it (review 1): over the
# last 12 percent of the flight (r06) it still showed at 0.4 s, over the last metre (r07) it is a
# faint grey there. Gone within 0.45 m (r08) lost the blind A/B (review 2): the shadow went while
# the flask was still 0.84 m up.
# FlaskThrow.cs reads the same values from its exports, which this script writes onto the root.
const SHADOW_FRAMES_PER_M := 3.6
const SHADOW_FRAME_LIFT := 1.15
const SHADOW_ALPHA_GROUND := 0.65
const SHADOW_ALPHA_PER_M := 0.12
const SHADOW_ALPHA_MIN := 0.4
# No end fade (r09 test) put a full black tuft on the rat's head at 0.40 s. Render order cannot
# hide it: the tokens' lit_sprite is alpha-scissor in the opaque pass and the shadow is already
# below them (priority -1 against 1); the tuft is floor shadow behind the rat, outside its outline.
const SHADOW_GONE_M := 0.0
const SHADOW_FADE_M := 1.0  # about the target's own tile

# Drops leave the flask from TRAIL_FROM to TRAIL_UNTIL of the flight and live TRAIL_LIFE, so the
# last one is gone by about the arrival.
const TRAIL_FROM := 0.1
const TRAIL_UNTIL := 0.5
const TRAIL_LIFE := 0.22

# The sheet throw: hand of a 1.18 m thrower (0.6 of the body) to a rat's impact point 4 tiles away.
const SHEET_START := Vector3(0.15, 0.71, 0.0)
const SHEET_END := Vector3(4.0, 0.32, 0.0)
const SHEET_APEX := 1.2
const SHEET_FLIGHT := 0.45

# Self glow of the lit flask and drops: enough that they do not go black between torches. At 0.35
# the bulb bloomed into a soft halo on the neutral stage (r01).
const GLOW := 0.2


func _initialize() -> void:
	var root := Node3D.new()
	root.name = "FlaskThrow"
	var ground := Node3D.new()
	ground.name = "Ground"
	ground.position = Vector3(0.0, 0.015, 0.0)
	root.add_child(ground)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)

	var shadow := _add_shadow(ground)
	var flask := _add_flask(body)
	var trail := _add_trail(flask)
	# no light: a faint green light on the flask lit nothing visible in flight and tinted the target
	# green just before the splash (r01)
	_add_anim(root, flask, trail, shadow)

	if ResourceLoader.exists(SCRIPT):
		root.set_script(load(SCRIPT))
		_set_exports(root)
	_own(root, root)
	for n in [ground, body]:
		n.unique_name_in_owner = true
	var packed := PackedScene.new()
	var err: Error = packed.pack(root)
	if err != OK:
		push_error("pack failed: %d" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, OUT)
	if err != OK:
		push_error("save failed: %d" % err)
		quit(1)
		return
	print("BUILT ", ProjectSettings.globalize_path(OUT))
	if "--handoff=1" in OS.get_cmdline_user_args():
		_build_handoff()
	quit()


# Review scene: the throw, and the acid splash on the rat where the throw ends. The capture starts
# the splash at the arrival (--delayed=Splash --delay=SHEET_FLIGHT) and strips both scripts.
func _build_handoff() -> void:
	var root := Node3D.new()
	root.name = "HandoffTest"
	var throw: Node3D = (load(OUT) as PackedScene).instantiate()
	throw.name = "Throw"
	root.add_child(throw)
	throw.owner = root
	var splash: Node3D = (load(SPLASH) as PackedScene).instantiate()
	splash.name = "Splash"
	splash.position = Vector3(SHEET_END.x, 0.0, SHEET_END.z)
	root.add_child(splash)
	splash.owner = root
	root.set_editable_instance(splash, true)
	var body: Node3D = splash.get_node("Body")
	body.position = Vector3(0.0, SPLASH_IMPACT, 0.0)
	body.scale = Vector3.ONE * SPLASH_BODY_SCALE
	var packed := PackedScene.new()
	if packed.pack(root) != OK or ResourceSaver.save(packed, HANDOFF) != OK:
		push_error("handoff save failed")
		return
	print("BUILT ", ProjectSettings.globalize_path(HANDOFF))


# The flask: one particle that lives the whole flight and plays the eight 45 degree tumble frames
# TURNS times. Lit like the unit sprites, with a little self glow so it does not go black in the
# sewer between torches; only the glass glint passes the glow threshold.
func _add_flask(parent: Node3D) -> GPUParticles3D:
	var p := _emitter("Flask", 1, SHEET_FLIGHT)
	p.one_shot = true
	p.explosiveness = 1.0
	p.position = SHEET_START
	var m := _still()
	m.anim_speed_min = TURNS
	m.anim_speed_max = TURNS
	m.color_ramp = _ramp([[0.0, Color.WHITE], [1.0, Color.WHITE]])
	p.process_material = m
	p.draw_pass_1 = _quad(FLASK_CELL)
	var mat := _flipbook("pixel_lit", "flask.png", FLASK_FRAMES, 1, 0, true)
	_lit(mat, 0.8, 0.35, GLOW)
	mat.set_shader_parameter("light_desaturate", 0.5)
	# over the thrower at the release and over the target at the arrival: both billboards stand
	# at the flask's own depth there
	mat.set_shader_parameter("depth_pull", 0.3)
	mat.render_priority = 2
	p.draw_pass_1.surface_set_material(0, mat)
	parent.add_child(p)
	return p


# Acid drops shed behind the flask: emitted in world space while the flask flies, falling under
# gravity, each shrinking to a speck over its life. Thrown forward and up at 1.5 to 3 m/s (r08) they
# hung level and lost the blind A/B (review 2). FlaskThrow.cs turns the direction along the throw
# on its own copy of this process material; turning the node turned the billboard quads edge-on for
# a throw toward -X. Emitting is switched on and off along the flight (FlaskThrow.cs in the game,
# %Anim on the sheets).
func _add_trail(flask: GPUParticles3D) -> GPUParticles3D:
	var p := _emitter("Trail", 3, TRAIL_LIFE)
	p.one_shot = false
	p.explosiveness = 0.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-3.0, -3.0, -3.0), Vector3(6.0, 6.0, 6.0))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.05
	m.direction = Vector3(0.0, -1.0, 0.0)
	m.spread = 60.0
	m.initial_velocity_min = 0.2
	m.initial_velocity_max = 0.6
	m.inherit_velocity_ratio = 0.5
	m.gravity = Vector3(0.0, -9.8, 0.0)
	m.lifetime_randomness = 0.2
	m.anim_speed_min = 1.0
	m.anim_speed_max = 1.0
	m.color_ramp = _ramp([[0.0, Color.WHITE], [1.0, Color.WHITE]])
	p.process_material = m
	p.draw_pass_1 = _quad(TRAIL_CELL)
	var mat := _flipbook("pixel_lit", "trail.png", 4, 3, 1, false)
	_lit(mat, 0.8, 0.35, GLOW)
	mat.set_shader_parameter("light_desaturate", 0.5)
	mat.set_shader_parameter("depth_pull", 0.1)
	mat.render_priority = 1
	p.draw_pass_1.surface_set_material(0, mat)
	flask.add_child(p)
	return p


# The flask's shadow: a flat black disc on the floor, smaller and fainter the higher the flask.
# A Sprite3D so the game can pick its frame from the height on every tick.
func _add_shadow(parent: Node3D) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = "Shadow"
	s.unique_name_in_owner = true
	s.texture = load(TEX_DIR + "shadow.png")
	s.hframes = SHADOW_FRAMES
	s.pixel_size = PX
	s.axis = Vector3.AXIS_Y
	s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	s.shaded = false
	s.double_sided = true
	s.transparent = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.render_priority = -1
	s.modulate = Color(1.0, 1.0, 1.0, shadow_alpha(SHEET_START.y, SHEET_END.x - SHEET_START.x))
	s.frame = shadow_frame(SHEET_START.y)
	s.position = Vector3(SHEET_START.x, 0.0, SHEET_START.z)
	parent.add_child(s)
	return s


# The sheet throw, keyed every frame at 60 fps. The game never plays this.
func _add_anim(root: Node3D, flask: GPUParticles3D, trail: GPUParticles3D, shadow: Sprite3D) -> void:
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	ap.unique_name_in_owner = true
	var anim := Animation.new()
	anim.length = SHEET_FLIGHT + 0.1
	var pos: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(pos, NodePath("Body/Flask:position"))
	var spos: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(spos, NodePath("Ground/Shadow:position"))
	var sframe: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(sframe, NodePath("Ground/Shadow:frame"))
	anim.value_track_set_update_mode(sframe, Animation.UPDATE_DISCRETE)
	var salpha: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(salpha, NodePath("Ground/Shadow:modulate"))
	var steps: int = int(round(SHEET_FLIGHT * 60.0))
	for k in range(steps + 1):
		var t: float = SHEET_FLIGHT * float(k) / float(steps)
		var s: float = t / SHEET_FLIGHT
		var at: Vector3 = arc(SHEET_START, SHEET_END, SHEET_APEX, s)
		var floor_at := Vector3(at.x, 0.0, at.z)
		anim.track_insert_key(pos, t, at)
		anim.track_insert_key(spos, t, floor_at)
		anim.track_insert_key(sframe, t, shadow_frame(at.y))
		var left: float = Vector2(SHEET_END.x - at.x, SHEET_END.z - at.z).length()
		anim.track_insert_key(salpha, t, Color(1.0, 1.0, 1.0, shadow_alpha(at.y, left)))
	var vis: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(vis, NodePath("Ground/Shadow:visible"))
	anim.value_track_set_update_mode(vis, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(vis, 0.0, true)
	anim.track_insert_key(vis, SHEET_FLIGHT, false)
	var emit: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(emit, NodePath("Body/Flask/Trail:emitting"))
	anim.value_track_set_update_mode(emit, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(emit, 0.0, false)
	anim.track_insert_key(emit, TRAIL_FROM * SHEET_FLIGHT, true)
	anim.track_insert_key(emit, TRAIL_UNTIL * SHEET_FLIGHT, false)
	var lib := AnimationLibrary.new()
	lib.add_animation("play", anim)
	ap.add_animation_library("", lib)
	root.add_child(ap)


# The lob: straight from start to end at an even speed across the floor, plus a parabola that
# peaks `apex` metres above the chord at the middle of the flight. FlaskThrow.cs uses the same.
static func arc(start: Vector3, end: Vector3, apex: float, s: float) -> Vector3:
	return start.lerp(end, s) + Vector3.UP * (4.0 * apex * s * (1.0 - s))


static func shadow_frame(height: float) -> int:
	return clampi(int(round(height * SHADOW_FRAMES_PER_M - SHADOW_FRAME_LIFT)), 0, SHADOW_FRAMES - 1)


# left: metres of ground track still to go to the target.
static func shadow_alpha(height: float, left: float) -> float:
	var a: float = clampf(SHADOW_ALPHA_GROUND - height * SHADOW_ALPHA_PER_M, SHADOW_ALPHA_MIN, SHADOW_ALPHA_GROUND)
	return a * clampf((left - SHADOW_GONE_M) / SHADOW_FADE_M, 0.0, 1.0)


# The adapter's tunables, written onto the root so the scene file holds them.
func _set_exports(root: Node3D) -> void:
	root.set("FramePixelSize", PX)
	root.set("TrailFrom", TRAIL_FROM)
	root.set("TrailUntil", TRAIL_UNTIL)
	root.set("ShadowFramesPerMetre", SHADOW_FRAMES_PER_M)
	root.set("ShadowFrameLift", SHADOW_FRAME_LIFT)
	root.set("ShadowAlphaGround", SHADOW_ALPHA_GROUND)
	root.set("ShadowAlphaPerMetre", SHADOW_ALPHA_PER_M)
	root.set("ShadowAlphaMin", SHADOW_ALPHA_MIN)
	root.set("ShadowGoneMetres", SHADOW_GONE_M)
	root.set("ShadowFadeMetres", SHADOW_FADE_M)


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
	return m


# Camera-facing quad of `cells` texels on a side.
func _quad(cells: int) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE * float(cells) * PX
	return q


func _vfx(kind: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_DIR + "vfx_essential_%s.gdshader" % kind)
	return mat


# Lit pixel material without a normal page: the billboard normal leans from world up toward the
# camera (lit_sprite's lean and wrap), emission on the palest texels, a little self glow.
func _lit(mat: ShaderMaterial, emission: float, rough: float, glow: float) -> void:
	mat.set_shader_parameter("has_normal_tex", false)
	mat.set_shader_parameter("normal_base", 0)
	mat.set_shader_parameter("face_camera", 0.5)
	mat.set_shader_parameter("light_wrap", 0.35)
	mat.set_shader_parameter("roughness", rough)
	mat.set_shader_parameter("glint", 0.5)
	mat.set_shader_parameter("emission_luma", 0.85)
	mat.set_shader_parameter("emission_strength", emission)
	mat.set_shader_parameter("emission_base", glow)


# mode 0 plays the whole sheet; mode 1 gives each particle one random row.
func _flipbook(kind: String, texture: String, h: int, v: int, mode: int, loop: bool) -> ShaderMaterial:
	var mat := _vfx(kind)
	mat.set_shader_parameter("diffuse1", load(TEX_DIR + texture))
	mat.set_shader_parameter("diffuse1_wrap", 1)
	mat.set_shader_parameter("flipbook_enabled", true)
	mat.set_shader_parameter("flipbook_h_frames", h)
	mat.set_shader_parameter("flipbook_v_frames", v)
	mat.set_shader_parameter("flipbook_mode", mode)
	mat.set_shader_parameter("flipbook_loop", loop)
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
