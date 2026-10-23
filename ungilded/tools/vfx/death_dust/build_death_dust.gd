# Builds the death dust (a slain creature breaks into its own pixels, which drift away as ash) and
# saves it as res://scenes/fx/death_dust.tscn. Every number lives here; a review round edits this
# file and rebuilds. Round log: tools/vfx/death_dust/NOTES.md.
#
#   <mono console exe> --path . --headless -s res://tools/vfx/death_dust/build_death_dust.gd
#
# Two halves play together:
# - the body erodes in lit_sprite.gdshader: death_progress runs 0 to 1 over SWEEP. The token drives
#   it in the game; %Anim drives it on %Preview, the stand-in rat, for the sheets.
# - the dust is the sprite's own texels as GPUParticles3D squares (EMISSION_SHAPE_POINTS). Texels go
#   in bands by their erosion threshold: band k holds the texels whose threshold is in [k, k + 1) /
#   BANDS and starts when the sweep reaches that slice (%Anim keys its speed_scale from 0 to 1), so
#   pixels leave from where the body is breaking. DeathDust.cs fills each band's point and colour
#   textures from the dying frame; this script fills them from the rat frame for %Preview.
#
# The threshold below mirrors erosion_threshold in lit_sprite.gdshader and SpriteErosion.cs.
#
# Layout: the root sits at the unit's feet. %Body sits at the sprite's centre and faces the camera
# (DeathDust.cs turns it every frame; the sheets turn it with capture_sheet_dd.gd --orient=Body).
# %Ground is empty. %Preview is the rat at its in-game PixelSize (0.02 m, not the 0.028 m capture
# convention), drawn with the token's lit material; DeathDust.cs hides it.
extends SceneTree

const OUT := "res://scenes/fx/death_dust.tscn"
const SCRIPT := "res://scripts/fx/DeathDust.cs"
const TOKEN_SPRITE := "res://scenes/combat/billboard_sprite.tscn"
const DUST_SHADER := "res://assets/fx/death_dust/dust_pixel.gdshader"
const PREVIEW_FRAME := "res://assets/sprites/enemies/rat_v1/idle_1.png"
const PREVIEW_NORMAL := "res://assets/sprites/enemies/rat_v1/idle_1_n.png"
const PREVIEW_PX := 0.02  # rat_v1/sprite.tres PixelSize
const PREVIEW_FEET := 4  # rat_v1/sprite.tres FootMarginPixels
const PREVIEW_SEED := 7
const SPRITE_LAYER := 2  # billboard_sprite.tscn layers: the spectacles glow skips it

# The front moves down the screen (UnitVisual3D.DeathSweep, Vector2.Down): the back goes first, so
# the rising dust leaves into empty air instead of crossing the body still standing (r05).
const SWEEP_DIR := Vector2(0.0, 1.0)
const SWEEP := 0.6  # seconds the body takes to break up (DeathDust.SweepSeconds)
const BANDS := 6  # dust emitters Dust0 .. Dust5 (DeathDust.cs Bands)
const PX := 0.02  # draw pass square side in metres; DeathDust.cs scales it to the sprite's pixel size
const TEX_WIDTH := 256  # texels per row of the point and colour textures (DeathDust.cs)

# Dust motion and look.
const LIFE := 0.65
const LIFE_RANDOM := 0.45
const DRIFT := Vector3(0.6, 1.0, 0.0)  # Body space: right and up on screen
const SPREAD := 40.0
# Each pixel leaves fast and settles into a slow drift: the launch speed is capped to DRIFT_SPEED by
# DRIFT_AT of its life (velocity_limit_curve). Damping stays off: damping above the pull of RISE and
# WIND stops a pixel dead.
const SPEED := Vector2(1.2, 2.4)
const DRIFT_SPEED := 0.9
const DRIFT_AT := 0.25
const DAMPING := Vector2(0.0, 0.0)
const RISE := 0.7  # world up, m/s^2
# m/s^2 along the camera's right, so the dust blows the same way on screen from any yaw; DeathDust.cs
# sets it from the game camera, the build from the sheet cameras' right (both sit at yaw 45).
const WIND := 1.5
const SHEET_RIGHT := Vector3(0.7071, 0.0, -0.7071)
const TURBULENCE := 1.0
const TURBULENCE_SCALE := 2.0
# Share of each particle's velocity turned toward the noise field every frame: above a few percent
# the field steers the pixels at random and the dust stays put.
const TURBULENCE_INFLUENCE := Vector2(0.01, 0.04)
const FADE_FROM := 0.45  # share of the life the square holds full alpha
# A pixel is born glowing as the edge texel it was (the edge's colour and energy, read from the
# token's material) and cools to its own colour over EMBER_LIFE of its life, then toward ASH.
const EMBER_LIFE := 0.15
const ASH := Color(0.29, 0.251, 0.227)  # 4A403A
const ASH_LIFE := Vector2(0.15, 0.7)
const ASH_SHARE := 0.85
const DEPTH_PULL := 0.05
# Metres the stand-in moves on alternate frames of the sweep. A torch's shadow is re-rendered only
# when a caster moves, so without it the floor keeps the whole rat's shadow (UnitVisual3D does the
# same to the token).
const NUDGE := 0.0001

const M32 := 0xFFFFFFFF


func _initialize() -> void:
	var token_mat: ShaderMaterial = _token_material()
	if token_mat == null:
		push_error("no lit material on " + TOKEN_SPRITE)
		quit(1)
		return
	# the PNG itself: headless, a texture's get_image() comes back empty
	var frame: Image = Image.load_from_file(ProjectSettings.globalize_path(PREVIEW_FRAME))
	frame.convert(Image.FORMAT_RGBA8)
	var plan := _plan(frame, token_mat)

	var root := Node3D.new()
	root.name = "DeathDust"
	var ground := Node3D.new()
	ground.name = "Ground"
	root.add_child(ground)
	var centre := Vector3(0.0, (frame.get_height() * 0.5 - PREVIEW_FEET) * PREVIEW_PX, 0.0)
	var body := Node3D.new()
	body.name = "Body"
	body.position = centre
	root.add_child(body)
	_add_preview(root, frame, plan, token_mat, centre.y)

	var bands: Array = _bands(frame, plan)
	var dust_mat := _dust_material(token_mat)
	for k in range(BANDS):
		_add_band(body, k, bands[k], dust_mat)
	_add_anim(root)

	if ResourceLoader.exists(SCRIPT):
		root.set_script(load(SCRIPT))
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
	var counts := []
	for b in bands:
		counts.append((b[0] as PackedVector3Array).size())
	print("BUILT ", ProjectSettings.globalize_path(OUT), " texels per band ", counts)
	root.free()
	quit()


# The token's lit material as billboard_sprite.tscn authors it, read without instancing the scene.
func _token_material() -> ShaderMaterial:
	var state: SceneState = (load(TOKEN_SPRITE) as PackedScene).get_state()
	for i in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0, i) == "material_override":
			return state.get_node_property_value(0, i) as ShaderMaterial
	return null


# ---------------------------------------------------------------- erosion (lit_sprite.gdshader)

func _plan(frame: Image, token_mat: ShaderMaterial) -> Dictionary:
	var dir: Vector2 = SWEEP_DIR.normalized()
	var lo := INF
	var hi := -INF
	for y in range(frame.get_height()):
		for x in range(frame.get_width()):
			if frame.get_pixel(x, y).a < 0.5:
				continue
			var d: float = (x + 0.5) * dir.x + (y + 0.5) * dir.y
			lo = minf(lo, d)
			hi = maxf(hi, d)
	var plan := {
		"dir": dir, "span": Vector2(lo, hi), "seed": PREVIEW_SEED,
		"mix": token_mat.get_shader_parameter("death_mix") as Vector3,
		"cell": float(token_mat.get_shader_parameter("death_cell")),
		"range": Vector2(0.0, 1.0),
	}
	var low := INF
	var high := -INF
	for y in range(frame.get_height()):
		for x in range(frame.get_width()):
			if frame.get_pixel(x, y).a >= 0.5:
				low = minf(low, _sum(x, y, plan))
				high = maxf(high, _sum(x, y, plan))
	plan["range"] = Vector2(low, high)
	return plan


func _unit(x: int, y: int, seed: int) -> float:
	var h: int = ((x * 73856093) & M32) ^ ((y * 19349663) & M32) ^ ((seed * 83492791) & M32)
	h ^= h >> 16
	h = (h * 2246822519) & M32
	h ^= h >> 13
	h = (h * 3266489917) & M32
	h ^= h >> 16
	return float(h >> 8) / 16777216.0


func _noise(x: int, y: int, seed: int, cell: float) -> float:
	var fx: float = (x + 0.5) / cell
	var fy: float = (y + 0.5) / cell
	var ix: float = floorf(fx)
	var iy: float = floorf(fy)
	var ux: float = fx - ix
	var uy: float = fy - iy
	ux = ux * ux * (3.0 - 2.0 * ux)
	uy = uy * uy * (3.0 - 2.0 * uy)
	var a: float = _unit(int(ix), int(iy), seed)
	var b: float = _unit(int(ix) + 1, int(iy), seed)
	var c: float = _unit(int(ix), int(iy) + 1, seed)
	var d: float = _unit(int(ix) + 1, int(iy) + 1, seed)
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uy)


func _sum(x: int, y: int, plan: Dictionary) -> float:
	var dir: Vector2 = plan["dir"]
	var span: Vector2 = plan["span"]
	var mix: Vector3 = plan["mix"]
	var sweep: float = clampf(((x + 0.5) * dir.x + (y + 0.5) * dir.y - span.x) / maxf(span.y - span.x, 0.001), 0.0, 1.0)
	var noise: float = _noise(x, y, int(plan["seed"]) + 1, float(plan["cell"]))
	var grain: float = _unit(x, y, int(plan["seed"]))
	return sweep * mix.x + noise * mix.y + grain * mix.z


func _threshold(x: int, y: int, plan: Dictionary) -> float:
	var r: Vector2 = plan["range"]
	return clampf((_sum(x, y, plan) - r.x) / maxf(r.y - r.x, 0.001), 0.0, 0.99999)


# ---------------------------------------------------------------- layers

# The stand-in: the rat as the token draws it, eroded by %Anim.
func _add_preview(root: Node3D, frame: Image, plan: Dictionary, token_mat: ShaderMaterial, lift: float) -> void:
	var sprite := Sprite3D.new()
	sprite.name = "Preview"
	sprite.unique_name_in_owner = true
	sprite.texture = load(PREVIEW_FRAME)
	sprite.pixel_size = PREVIEW_PX
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.layers = SPRITE_LAYER
	sprite.position = Vector3(0.0, lift, 0.0)
	var mat := token_mat.duplicate() as ShaderMaterial
	mat.set_shader_parameter("sprite_tex", load(PREVIEW_FRAME))
	mat.set_shader_parameter("normal_tex", load(PREVIEW_NORMAL))
	mat.set_shader_parameter("has_normal_tex", true)
	mat.set_shader_parameter("feet_y", -lift)
	mat.set_shader_parameter("death_origin", Vector2.ZERO)
	mat.set_shader_parameter("death_frame", Vector2(frame.get_width(), frame.get_height()))
	mat.set_shader_parameter("death_dir", plan["dir"])
	mat.set_shader_parameter("death_span", plan["span"])
	mat.set_shader_parameter("death_seed", plan["seed"])
	mat.set_shader_parameter("death_range", plan["range"])
	mat.set_shader_parameter("death_progress", 0.0)
	sprite.material_override = mat
	root.add_child(sprite)


# Each opaque texel's place (Body space, metres from the sprite centre, x right, y up) and colour,
# sorted into the band of its threshold.
func _bands(frame: Image, plan: Dictionary) -> Array:
	# plain Arrays: a packed array read out of an Array is a copy, so appending to it is lost
	var bands := []
	for k in range(BANDS):
		bands.append([[], []])
	var w: int = frame.get_width()
	var h: int = frame.get_height()
	for y in range(h):
		for x in range(w):
			var c: Color = frame.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var k: int = mini(int(_threshold(x, y, plan) * BANDS), BANDS - 1)
			var at := Vector3((x + 0.5 - w * 0.5) * PREVIEW_PX, (h * 0.5 - y - 0.5) * PREVIEW_PX, 0.0)
			(bands[k][0] as Array).append(at)
			(bands[k][1] as Array).append(Color(c.r, c.g, c.b, 1.0))
	for k in range(BANDS):
		bands[k] = [PackedVector3Array(bands[k][0]), PackedColorArray(bands[k][1])]
	return bands


func _add_band(body: Node3D, k: int, band: Array, dust_mat: ShaderMaterial) -> void:
	var points: PackedVector3Array = band[0]
	var colours: PackedColorArray = band[1]
	var p := GPUParticles3D.new()
	p.name = "Dust%d" % k
	p.unique_name_in_owner = true
	p.amount = maxi(points.size(), 1)
	p.visible = points.size() > 0
	p.lifetime = LIFE
	p.one_shot = true
	# each band emits over its slice of the sweep
	p.explosiveness = 1.0 - (SWEEP / BANDS) / LIFE
	p.emitting = false
	p.local_coords = false
	# held until %Anim reaches the band's slice; band 0 starts at once
	p.speed_scale = 1.0 if k == 0 else 0.0
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.layers = SPRITE_LAYER
	p.visibility_aabb = AABB(Vector3(-3.5, -3.5, -3.5), Vector3(7.0, 7.0, 7.0))

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	m.emission_point_texture = _point_texture(points)
	m.emission_color_texture = _colour_texture(colours)
	m.emission_point_count = points.size()
	m.direction = DRIFT.normalized()
	m.spread = SPREAD
	m.initial_velocity_min = SPEED.x
	m.initial_velocity_max = SPEED.y
	m.damping_min = DAMPING.x
	m.damping_max = DAMPING.y
	var limit := Curve.new()
	limit.max_value = SPEED.y
	limit.add_point(Vector2(0.0, SPEED.y))
	limit.add_point(Vector2(DRIFT_AT, DRIFT_SPEED))
	limit.add_point(Vector2(1.0, DRIFT_SPEED))
	var limit_tex := CurveTexture.new()
	limit_tex.curve = limit
	m.velocity_limit_curve = limit_tex
	m.gravity = Vector3(0.0, RISE, 0.0) + SHEET_RIGHT * WIND
	m.turbulence_enabled = true
	m.turbulence_noise_strength = TURBULENCE
	m.turbulence_noise_scale = TURBULENCE_SCALE
	m.turbulence_influence_min = TURBULENCE_INFLUENCE.x
	m.turbulence_influence_max = TURBULENCE_INFLUENCE.y
	m.lifetime_randomness = LIFE_RANDOM
	m.scale_min = PREVIEW_PX / PX
	m.scale_max = PREVIEW_PX / PX
	m.color_ramp = _ramp([[0.0, Color.WHITE], [FADE_FROM, Color.WHITE], [1.0, Color(1, 1, 1, 0)]])
	p.process_material = m

	var quad := QuadMesh.new()
	quad.size = Vector2(PX, PX)
	quad.material = dust_mat
	p.draw_pass_1 = quad
	body.add_child(p)


func _dust_material(token_mat: ShaderMaterial) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(DUST_SHADER)
	mat.set_shader_parameter("ember", token_mat.get_shader_parameter("death_edge"))
	mat.set_shader_parameter("ember_energy", token_mat.get_shader_parameter("death_edge_energy"))
	mat.set_shader_parameter("ember_life", EMBER_LIFE)
	mat.set_shader_parameter("ash", ASH)
	mat.set_shader_parameter("ash_life", ASH_LIFE)
	mat.set_shader_parameter("ash_share", ASH_SHARE)
	mat.set_shader_parameter("face_camera", token_mat.get_shader_parameter("face_camera"))
	mat.set_shader_parameter("wrap", token_mat.get_shader_parameter("wrap"))
	mat.set_shader_parameter("depth_pull", DEPTH_PULL)
	mat.render_priority = 1
	return mat


# "play": the preview's erosion over SWEEP, and each band's start.
func _add_anim(root: Node3D) -> void:
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	ap.unique_name_in_owner = true
	var anim := Animation.new()
	anim.length = SWEEP
	var erosion: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(erosion, NodePath("Preview:material_override:shader_parameter/death_progress"))
	anim.track_insert_key(erosion, 0.0, 0.0)
	anim.track_insert_key(erosion, SWEEP, 1.0)
	var preview: Node3D = root.get_node("Preview")
	var nudge: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(nudge, NodePath("Preview:position"))
	anim.value_track_set_update_mode(nudge, Animation.UPDATE_DISCRETE)
	var frames: int = int(round(SWEEP * 60.0))
	for f in range(frames + 1):
		anim.track_insert_key(nudge, f / 60.0, preview.position + Vector3(0.0, NUDGE * (f % 2), 0.0))
	for k in range(1, BANDS):
		var track: int = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track, NodePath("Body/Dust%d:speed_scale" % k))
		anim.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
		anim.track_insert_key(track, 0.0, 0.0)
		anim.track_insert_key(track, SWEEP * k / BANDS, 1.0)
	var lib := AnimationLibrary.new()
	lib.add_animation("play", anim)
	ap.add_animation_library("", lib)
	root.add_child(ap)


# ---------------------------------------------------------------- helpers

func _point_texture(points: PackedVector3Array) -> ImageTexture:
	var n: int = maxi(points.size(), 1)
	var w: int = mini(n, TEX_WIDTH)
	var h: int = ceili(float(n) / w)
	var data := PackedFloat32Array()
	data.resize(w * h * 3)
	for i in range(points.size()):
		data[i * 3] = points[i].x
		data[i * 3 + 1] = points[i].y
		data[i * 3 + 2] = points[i].z
	return ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBF, data.to_byte_array()))


func _colour_texture(colours: PackedColorArray) -> ImageTexture:
	var n: int = maxi(colours.size(), 1)
	var w: int = mini(n, TEX_WIDTH)
	var h: int = ceili(float(n) / w)
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for i in range(colours.size()):
		img.set_pixel(i % w, i / w, colours[i])
	return ImageTexture.create_from_image(img)


# stops: [[offset, Color], ...] in ascending order; add_point does not sort
func _ramp(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for s in stops:
		offsets.append(s[0])
		colors.append(s[1])
	g.offsets = offsets
	g.colors = colors
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 128
	return t


func _own(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_own(c, owner)
