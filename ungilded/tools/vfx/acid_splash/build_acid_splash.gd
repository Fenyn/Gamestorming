# Builds the acid splash impact (a thrown flask shattering on a creature) and saves it as
# res://scenes/fx/acid_splash.tscn. Every number lives here; a review round edits this file
# and rebuilds. Frames: draw_acid_frames.py. Round log: tools/vfx/acid_splash/NOTES.md.
#
#   <mono console exe> --path . --headless -s res://tools/vfx/acid_splash/build_acid_splash.gd
#
# HD-2D: every layer is a pixel-art flipbook on the locked palette, sampled nearest, one texel
# = PX metres, so the effect's pixels match the sprites'. Quads are sized cell px x PX and never
# scaled per particle; variety comes from drawn variants (Random row flipbooks), not from
# scale or rotation, which would break the pixel grid.
#
# Layout: Body (y = IMPACT_HEIGHT) holds the layers that hit the creature; Ground holds the
# puddle ring. AcidSplash.cs (when present) moves Body to the real impact height and scales it
# by FxScale; the ground stays one tile wide because splash reach is a rule, not a size.
extends SceneTree

const OUT := "res://scenes/fx/acid_splash.tscn"
const SHADER_DIR := "res://assets/shaders/vfx/"
const TEX_DIR := "res://assets/fx/acid_splash/"
const SCRIPT := "res://scripts/fx/AcidSplash.cs"
const IMPACT_HEIGHT := 1.05  # hero: HeroHpBarY 1.75 * ImpactHeightFraction 0.6
const PX := 0.028  # metres per texel at FxScale 1

const ACID_BRIGHT := Color("A9BF58")
# render layer 5, unnamed in the project: the splat draws there so its own light can skip it
const SPLAT_LAYER := 1 << 4


func _initialize() -> void:
	var root := Node3D.new()
	root.name = "AcidSplash"
	var ground := Node3D.new()
	ground.name = "Ground"
	ground.position = Vector3(0.0, 0.02, 0.0)
	root.add_child(ground)
	var body := Node3D.new()
	body.name = "Body"
	body.position = Vector3(0.0, IMPACT_HEIGHT, 0.0)
	root.add_child(body)

	# no vapour layer: four designs read as hair, a bush, moss and a dither pattern (r16)
	_add_ring(ground)
	_add_puddles(ground)
	_add_droplets(body)
	_add_splat(body)
	_add_glass(body)
	_add_bubbles(body)
	_add_flash(body)
	_add_light(root, body)

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
	print("BUILT ", ProjectSettings.globalize_path(OUT))
	quit()


# A ring of spray racing out across the floor to the edge of the splash reach.
func _add_ring(parent: Node3D) -> void:
	var p := _emitter("Ring", 1, 0.3)
	p.explosiveness = 1.0
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_DISABLED
	var m := _still()
	m.anim_speed_min = 1.0
	m.anim_speed_max = 1.0
	m.color_ramp = _ramp([[0.0, Color.WHITE], [1.0, Color.WHITE]])
	p.process_material = m
	p.draw_pass_1 = _flat(112)
	var mat := _flipbook("pixel_mix", "ring.png", 7, 1, 0, false)
	# no emission boost: liquid on the floor, not a glowing shockwave
	mat.set_shader_parameter("emission_scaler", 1.0)
	mat.render_priority = -3
	p.draw_pass_1.surface_set_material(0, mat)
	parent.add_child(p)


# Acid on the eight squares around the target: one world-aligned 3.58 m ground flipbook with a
# splat on every neighbour tile centre and four spatters between, landing staggered 0.13 to
# 0.33 s, soaking to the mid green and drying to specks by 1.44 s. A random ring of twelve
# puddles left the far side thin at 24 m. The quad is not rotated, so the splats stay on the
# board's tiles; every throw shows the same floor layout.
func _add_puddles(parent: Node3D) -> void:
	var p := _emitter("Puddles", 1, 1.44)
	p.explosiveness = 1.0
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_DISABLED
	var m := _still()
	m.anim_speed_min = 1.0
	m.anim_speed_max = 1.0
	# no fade: the frames dry to specks and empty out; a dithered fade left checkerboard specks
	m.color_ramp = _ramp([[0.0, Color.WHITE], [1.0, Color.WHITE]])
	p.process_material = m
	p.draw_pass_1 = _flat(128)
	# lit wet floor: the mesh normal plus the page, smooth enough for torch glints
	var mat := _flipbook("pixel_lit", "puddles.png", 9, 4, 0, false)
	# 0.35 self glow: at 0.6 the lit floor outshone the acid on the body after 0.5 s
	_lit(mat, "puddles_n.png", 1, 1.0, 0.3, 0.35)
	# under a warm torch the green turned lemon yellow: 60 percent of each light's colour is
	# taken as plain brightness in the diffuse, and the glint is halved, so the puddles stay
	# green and only their glint carries the torch's warmth
	mat.set_shader_parameter("light_desaturate", 0.6)
	mat.set_shader_parameter("glint", 0.5)
	mat.render_priority = -2
	p.draw_pass_1.surface_set_material(0, mat)
	parent.add_child(p)


# The splat: one hand-timed 18-frame flipbook at 46 ms a frame. Shatter, crown of tongues,
# break into beads, sag and drip, then the acid clings to the target as darkening stains.
# Drawn over the target (depth_pull) as liquid on its body.
func _add_splat(parent: Node3D) -> void:
	var p := _emitter("Splat", 1, 0.828)
	p.explosiveness = 1.0
	var m := _still()
	m.anim_speed_min = 1.0
	m.anim_speed_max = 1.0
	# no fade: the last frames are already sparse specks, and a dithered fade read as a net
	m.color_ramp = _ramp([[0.0, Color.WHITE], [1.0, Color.WHITE]])
	p.process_material = m
	p.draw_pass_1 = _quad(48)
	# lit like the sprite it sits on by the scene's lights, but not by its own green light (the
	# acid is that light's source, 1.3 m away, and it lifted every palette step one level); only a
	# few pale texels emit above the glow threshold
	p.layers = SPLAT_LAYER
	var mat := _flipbook("pixel_lit", "splat.png", 6, 3, 0, false)
	_lit(mat, "splat_n.png", 0, 0.9, 0.35, 0.12)
	# the torch side turned yellow-olive: half of each light's colour taken as plain brightness
	mat.set_shader_parameter("light_desaturate", 0.5)
	mat.set_shader_parameter("depth_pull", 0.5)
	mat.render_priority = 1
	p.draw_pass_1.surface_set_material(0, mat)
	parent.add_child(p)


# Beads of acid flung out and down under gravity; four drawn sizes, each shrinking over life.
func _add_droplets(parent: Node3D) -> void:
	# 0.45 s at most: from 1.05 m at 2 to 4 m/s a drop is still in the air by then, and its last
	# life frame is one pixel, so none lands at full size with no splash under it
	var p := _emitter("Droplets", 20, 0.45)
	p.explosiveness = 0.95
	# teardrops lead with their head: the texture's top follows the velocity
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	p.visibility_aabb = AABB(Vector3(-7.0, -7.0, -7.0), Vector3(14.0, 14.0, 14.0))
	var m := ParticleProcessMaterial.new()
	# born at the rim of the splat and drawn behind it, so they leave the crown instead of
	# piling up over its middle
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	m.emission_sphere_radius = 0.32
	m.direction = Vector3(0.0, 1.0, 0.0)
	m.spread = 110.0
	m.initial_velocity_min = 2.0
	m.initial_velocity_max = 4.0
	m.gravity = Vector3(0.0, -9.8, 0.0)
	m.damping_min = 0.2
	m.damping_max = 0.5
	m.lifetime_randomness = 0.4
	m.anim_speed_min = 1.0
	m.anim_speed_max = 1.0
	# hidden for the first 40 ms so they do not ring the flash; the frames do the fade (shorter
	# tail, then one pixel), with no dither, which left checkerboard specks
	m.color_ramp = _ramp([[0.0, Color(1, 1, 1, 0.0)], [0.08, Color(1, 1, 1, 0.0)], [0.09, Color.WHITE], [1.0, Color.WHITE]])
	p.process_material = m
	p.draw_pass_1 = _quad(8)
	var mat := _flipbook("pixel_mix", "droplets.png", 4, 4, 1, false)
	# 1.0: green drops stay under the glow threshold, so only the white glass glints in flight
	mat.set_shader_parameter("emission_scaler", 1.0)
	mat.set_shader_parameter("depth_pull", 0.15)
	mat.render_priority = -1
	p.draw_pass_1.surface_set_material(0, mat)
	parent.add_child(p)


# Glass from the broken flask: angular shards that tumble in quarter turns and glint.
func _add_glass(parent: Node3D) -> void:
	var p := _emitter("Glass", 8, 0.4)
	p.explosiveness = 1.0
	p.visibility_aabb = AABB(Vector3(-5.0, -5.0, -5.0), Vector3(10.0, 10.0, 10.0))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.05
	m.direction = Vector3(0.0, 1.0, 0.0)
	m.spread = 90.0
	m.initial_velocity_min = 3.0
	m.initial_velocity_max = 5.0
	m.gravity = Vector3(0.0, -10.0, 0.0)
	m.lifetime_randomness = 0.3
	m.anim_speed_min = 3.0
	m.anim_speed_max = 4.0
	# the glint dims instead of dithering out: a dithered 3 px shard left a checkerboard speck
	m.color_ramp = _ramp([[0.0, Color.WHITE], [0.6, Color.WHITE], [1.0, Color(0.35, 0.35, 0.35, 1.0)]])
	p.process_material = m
	p.draw_pass_1 = _quad(8)
	var mat := _flipbook("pixel_mix", "glass.png", 4, 4, 1, true)
	mat.set_shader_parameter("emission_scaler", 2.2)
	mat.set_shader_parameter("depth_pull", 0.2)
	mat.render_priority = 3
	p.draw_pass_1.surface_set_material(0, mat)
	parent.add_child(p)


# Sizzle: bubbles swelling and popping on the target over the first second.
func _add_bubbles(parent: Node3D) -> void:
	# Nine boil-and-pop beads in three sizes on the area where the splat's runs and stains sit
	# (0.25 m below the impact, 0.4 x 0.3 m), well below the eyes. Each lives 0.64 s: up to
	# 0.19 s of empty lead cells (a random start offset skips up to two), then 0.45 s of rise,
	# swell, pale cap, pop and residue. Spawned over the first 0.35 s, so they show from about
	# 0.12 to 1.0 s and never in step.
	var p := _emitter("Bubbles", 9, 0.64)
	p.explosiveness = 0.45
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(0.2, 0.15, 0.05)
	m.emission_shape_offset = Vector3(0.0, -0.25, 0.0)
	m.gravity = Vector3.ZERO
	m.anim_speed_min = 1.0
	m.anim_speed_max = 1.0
	m.anim_offset_min = 0.0
	m.anim_offset_max = 0.2
	m.color_ramp = _ramp([[0.0, Color.WHITE], [1.0, Color.WHITE]])
	p.process_material = m
	p.draw_pass_1 = _quad(12)
	var mat := _flipbook("pixel_mix", "bubbles.png", 10, 3, 1, false)
	# 1.1: at 1.6 a cluster of bubbles read as a luminous mass on the chest
	mat.set_shader_parameter("emission_scaler", 1.1)
	mat.set_shader_parameter("depth_pull", 0.55)
	mat.render_priority = 4
	p.draw_pass_1.surface_set_material(0, mat)
	parent.add_child(p)


# The glass-break flash: a 1 px green-white cross held for two cells, then glass arcs and glints;
# additive. Four 20 ms cells (0.08 s): the white leaves before the crown peaks, so the crown
# reads as green liquid. Emission is low enough that only the white cross passes the glow
# threshold (at 2.5 the cream core bloomed into a 2 m halo).
func _add_flash(parent: Node3D) -> void:
	var p := _emitter("Flash", 1, 0.08)
	p.explosiveness = 1.0
	var m := _still()
	m.anim_speed_min = 1.0
	m.anim_speed_max = 1.0
	m.color_ramp = _ramp([[0.0, Color.WHITE], [1.0, Color.WHITE]])
	p.process_material = m
	p.draw_pass_1 = _quad(32)
	var mat := _flipbook("pixel_add", "flash.png", 4, 1, 0, false)
	# 1.2: at 1.6 the glow spread an olive haze over the dark backdrop at 0.03 s
	mat.set_shader_parameter("emission_scaler", 1.2)
	mat.set_shader_parameter("depth_pull", 0.6)
	mat.render_priority = 5
	p.draw_pass_1.surface_set_material(0, mat)
	parent.add_child(p)


# A green light pulse, driven by the Anim player's "play" (and by AcidSplash.cs in the game).
# The green spill rides on Body, 0.9 m above the impact point, so the adapter's impact height and
# unit scale move it too. Above the target, not on its axis: the lit sprite shader takes each
# pixel's light at the body's axis at that pixel's height, so a light on the axis blew out a
# band across the body at its own height. A bright short peak with the hit, then a dim hold
# while the acid clings.
func _add_light(root: Node3D, body: Node3D) -> void:
	var light := OmniLight3D.new()
	light.name = "Light"
	light.unique_name_in_owner = true
	# 1.3 m above the impact, about 0.7 m over a hero's head: at 0.9 m the hair blew out, and the
	# floor a tile away took almost nothing
	light.position = Vector3(0.0, 1.3, 0.0)
	light.light_color = ACID_BRIGHT
	light.light_energy = 0.0
	light.omni_range = 4.0
	light.omni_attenuation = 1.0
	light.light_cull_mask = 0xFFFFF & ~SPLAT_LAYER
	light.shadow_enabled = false
	body.add_child(light)
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	ap.unique_name_in_owner = true
	var anim := Animation.new()
	anim.length = 0.8
	var track: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath("Body/Light:light_energy"))
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, 0.04, 2.6)
	anim.track_insert_key(track, 0.1, 1.3)
	anim.track_insert_key(track, 0.3, 0.65)
	anim.track_insert_key(track, 0.6, 0.35)
	anim.track_insert_key(track, 0.8, 0.0)
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
	return m


# Camera-facing quad of `cells` texels on a side.
func _quad(cells: int) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE * float(cells) * PX
	return q


# Quad of `cells` texels laid flat on the ground.
func _flat(cells: int) -> QuadMesh:
	var q := _quad(cells)
	q.orientation = PlaneMesh.FACE_Y
	return q


func _vfx(kind: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_DIR + "vfx_essential_%s.gdshader" % kind)
	return mat


# Lit pixel material values: the normal page with the same cells, normal base (0 billboard
# leaning up like lit_sprite, 1 the mesh normal), emission on the palest texels, roughness.
# lit_sprite's own wrap (0.35) and camera lean (0.5) so the effect is lit as the unit is.
func _lit(mat: ShaderMaterial, normal_texture: String, base: int, emission: float, rough: float, glow: float) -> void:
	mat.set_shader_parameter("normal_tex", load(TEX_DIR + normal_texture))
	mat.set_shader_parameter("has_normal_tex", true)
	mat.set_shader_parameter("normal_base", base)
	mat.set_shader_parameter("face_camera", 0.5)
	mat.set_shader_parameter("light_wrap", 0.35)
	mat.set_shader_parameter("roughness", rough)
	mat.set_shader_parameter("glint", 1.0)
	mat.set_shader_parameter("emission_luma", 0.8)
	mat.set_shader_parameter("emission_strength", emission)
	# acid glows a little by itself: under a warm torch alone the green turned to honey
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


# points: [[x, y], ...]. RGB texture mode: ParticleProcessMaterial reads scale_curve as .rgb.
func _curve(points: Array, min_value: float = 0.0, max_value: float = 1.0) -> CurveTexture:
	var c := Curve.new()
	c.min_value = min_value
	c.max_value = max_value
	for p in points:
		c.add_point(Vector2(p[0], p[1]))
	var t := CurveTexture.new()
	t.curve = c
	t.width = 256
	return t


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
