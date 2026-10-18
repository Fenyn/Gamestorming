extends Node

## Shared visual-effect helpers: particle materials, one-shot bursts and floating text.

const COIN_COLOR := Color(1.0, 0.8, 0.25)

var _soft_texture: GradientTexture2D = null

func soft_texture() -> Texture2D:
	if _soft_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		_soft_texture = GradientTexture2D.new()
		_soft_texture.gradient = gradient
		_soft_texture.fill = GradientTexture2D.FILL_RADIAL
		_soft_texture.fill_from = Vector2(0.5, 0.5)
		_soft_texture.fill_to = Vector2(0.5, 0.0)
		_soft_texture.width = 64
		_soft_texture.height = 64
	return _soft_texture

## Unshaded camera-facing material for particle quads. Particle colour comes from the
## process material's colour ramp through vertex colour.
func particle_material(color: Color, soft: bool = true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	if soft:
		mat.albedo_texture = soft_texture()
	return mat

## Colour ramp that fades in quickly, holds, then fades out.
func alpha_ramp(color: Color, peak_alpha: float) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color, 0.0))
	gradient.set_color(1, Color(color, 0.0))
	gradient.add_point(0.15, Color(color, peak_alpha))
	gradient.add_point(0.6, Color(color, peak_alpha * 0.6))
	var tex := GradientTexture1D.new()
	tex.gradient = gradient
	return tex

func curve_texture(points: Array) -> CurveTexture:
	var curve := Curve.new()
	curve.max_value = 4.0
	for p in points:
		curve.add_point(p as Vector2)
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex

## Small falling specks, used for grind dust and drips.
func make_specks(color: Color, speck_size: float, gravity_y: float, life: float, count: int) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = count
	particles.lifetime = life
	particles.local_coords = false
	particles.emitting = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.008
	pm.direction = Vector3.DOWN
	pm.spread = 20.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.08
	pm.gravity = Vector3(0, gravity_y, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.color = color
	particles.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(speck_size, speck_size)
	quad.material = particle_material(Color.WHITE, false)
	particles.draw_pass_1 = quad
	return particles

func _scene_root() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	return scene

## Spinning gold coins that pop up and fall. Frees itself.
func coin_burst(world_pos: Vector3, count: int = 14) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = count
	particles.lifetime = 1.1
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 0.9
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0, -5.0, 0)
	pm.scale_curve = curve_texture([Vector2(0.0, 1.0), Vector2(0.8, 1.0), Vector2(1.0, 0.0)])
	particles.process_material = pm
	var coin := CylinderMesh.new()
	coin.top_radius = 0.012
	coin.bottom_radius = 0.012
	coin.height = 0.003
	coin.radial_segments = 10
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COIN_COLOR
	mat.metallic = 0.8
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = COIN_COLOR * 0.25
	coin.material = mat
	particles.draw_pass_1 = coin
	_scene_root().add_child(particles)
	particles.global_position = world_pos
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(particles.queue_free)

## Soft glowing sparkles, used for great reviews. Frees itself.
func sparkle_burst(world_pos: Vector3, color: Color = Color(1.0, 0.9, 0.4), count: int = 18) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = count
	particles.lifetime = 0.9
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	pm.direction = Vector3.UP
	pm.spread = 80.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0, -0.4, 0)
	pm.damping_min = 0.8
	pm.damping_max = 1.2
	pm.color_ramp = alpha_ramp(color, 1.0)
	pm.scale_curve = curve_texture([Vector2(0.0, 1.0), Vector2(1.0, 0.2)])
	particles.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 0.03)
	var mat := particle_material(Color(1.6, 1.5, 1.2, 1.0))
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = mat
	particles.draw_pass_1 = quad
	_scene_root().add_child(particles)
	particles.global_position = world_pos
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(particles.queue_free)

## Droplets thrown up and out, for spills and splashes. Frees itself.
func splash(world_pos: Vector3, color: Color, count: int = 12, size: float = 0.005, speed: float = 0.5) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = count
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.01
	pm.direction = Vector3.UP
	pm.spread = 70.0
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -6.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.color = color
	particles.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = particle_material(Color.WHITE)
	particles.draw_pass_1 = quad
	_scene_root().add_child(particles)
	particles.global_position = world_pos
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.4).timeout.connect(particles.queue_free)

## Text that pops in, drifts up and fades out, e.g. "+$4.20". Frees itself.
func float_text(world_pos: Vector3, text: String, color: Color = Color(0.55, 1.0, 0.55), font_size: int = 48) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.0015
	UiStyle.world_label(label, UiStyle.W_BLACK, color)
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	_scene_root().add_child(label)
	label.global_position = world_pos
	label.scale = Vector3.ONE * 0.4
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position", world_pos + Vector3(0, 0.35, 0), 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(1.0)
	tween.chain().tween_callback(label.queue_free)

## Quick overshoot "pop" on a node's scale. Only use on visual nodes, not physics bodies.
func pop(node: Node3D, from_scale: float = 1.3, duration: float = 0.25) -> void:
	if node == null or not is_instance_valid(node):
		return
	var rest := node.scale
	node.scale = rest * from_scale
	var tween := node.create_tween()
	tween.tween_property(node, "scale", rest, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
