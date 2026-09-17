class_name DuelFx
extends Node3D
## Transient effects over the table: floating numbers, bursts of sparks, a slash between two
## cards, and rings. Everything here is built in code from primitive meshes, frees itself when
## its tween ends, and holds no state between updates. Colours come from ZenithTheme roles.

const TEXT_RISE: float = 0.5
const TEXT_TIME: float = 1.2
const TEXT_LIFT: float = 0.3
const SLASH_TIME: float = 0.4
const RING_TIME: float = 0.55
const BURST_LIFE: float = 0.7


## A number or word that pops in over `pos`, drifts up and fades.
func float_text(pos: Vector3, text: String, color: Color, size: int = 64) -> void:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.04, 0.05, 0.9)
	l.outline_size = 14
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.shaded = false
	l.position = pos + Vector3(0, TEXT_LIFT, 0)
	l.scale = Vector3.ONE * 0.35
	add_child(l)
	var t: Tween = create_tween()
	t.tween_property(l, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "position:y", l.position.y + TEXT_RISE, TEXT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, TEXT_TIME * 0.45).set_delay(TEXT_TIME * 0.55)
	t.parallel().tween_property(l, "outline_modulate:a", 0.0, TEXT_TIME * 0.45).set_delay(TEXT_TIME * 0.55)
	t.tween_callback(l.queue_free)


## Sparks thrown out from `pos` that fall and fade.
func burst(pos: Vector3, color: Color, count: int = 28, speed: float = 2.2) -> void:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = count
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = BURST_LIFE
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.08
	p.direction = Vector3.UP
	p.spread = 85.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -5.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.045, 0.045, 0.045)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.mesh = mesh
	p.position = pos + Vector3(0, 0.05, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(BURST_LIFE + 0.2).timeout.connect(p.queue_free)


## A bright streak from one card to another, lying just above the table, that fades.
func slash(from: Vector3, to: Vector3, color: Color) -> void:
	var dir: Vector3 = to - from
	dir.y = 0.0
	var length: float = dir.length()
	if length < 0.01:
		return
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(length, 0.09)
	quad.orientation = PlaneMesh.FACE_Y
	var m: MeshInstance3D = MeshInstance3D.new()
	m.mesh = quad
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color, 0.9)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	var mid: Vector3 = (from + to) * 0.5
	m.position = Vector3(mid.x, maxf(from.y, to.y) + 0.12, mid.z)
	m.basis = Basis(Vector3.UP, atan2(-dir.z, dir.x)).scaled(Vector3(0.05, 1.0, 1.0))
	add_child(m)
	var t: Tween = create_tween()
	t.tween_property(m, "scale:x", 1.0, SLASH_TIME * 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(m, "scale:z", 1.6, SLASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(mat, "albedo_color:a", 0.0, SLASH_TIME).set_delay(SLASH_TIME * 0.3)
	t.tween_callback(m.queue_free)


## A ring that spreads out from `pos` and fades: a shield going up, a token changing hands.
func ring(pos: Vector3, color: Color, size: float = 1.0) -> void:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.30
	torus.outer_radius = 0.36
	var m: MeshInstance3D = MeshInstance3D.new()
	m.mesh = torus
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color, 0.85)
	m.material_override = mat
	m.position = pos + Vector3(0, 0.08, 0)
	m.scale = Vector3(0.3, 0.3, 0.3)
	add_child(m)
	var t: Tween = create_tween()
	t.tween_property(m, "scale", Vector3(1.7, 0.6, 1.7) * size, RING_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(mat, "albedo_color:a", 0.0, RING_TIME).set_delay(RING_TIME * 0.25)
	t.tween_callback(m.queue_free)
