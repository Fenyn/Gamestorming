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
@export var reduced_motion: bool = false


## A number or word that pops in over `pos`, drifts up and fades.
func float_text(pos: Vector3, text: String, color: Color, size: int = 64) -> void:
	# A new beat replaces lingering text at this source instead of printing over it.
	for child in get_children():
		if child is Label3D and child.has_meta("float_anchor"):
			var anchor: Vector3 = child.get_meta("float_anchor")
			if anchor.distance_to(pos) < 0.6:
				(child as Label3D).hide()
	var l: Label3D = Label3D.new()
	l.set_meta("float_anchor", pos)
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
	l.scale = Vector3.ONE if reduced_motion else Vector3.ONE * 0.65
	add_child(l)
	var t: Tween = create_tween()
	t.tween_property(l, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "position:y", l.position.y + (0.0 if reduced_motion else TEXT_RISE), TEXT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, TEXT_TIME * 0.45).set_delay(TEXT_TIME * 0.55)
	t.parallel().tween_property(l, "outline_modulate:a", 0.0, TEXT_TIME * 0.45).set_delay(TEXT_TIME * 0.55)
	t.tween_callback(l.queue_free)


## Sparks thrown out from `pos` that fall and fade.
func burst(pos: Vector3, color: Color, count: int = 28, speed: float = 2.2) -> void:
	if reduced_motion:
		return
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
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.019
	mesh.height = 0.038
	mesh.radial_segments = 6
	mesh.rings = 3
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
	quad.size = Vector2(length, 0.055)
	quad.orientation = PlaneMesh.FACE_Y
	var m: MeshInstance3D = MeshInstance3D.new()
	m.mesh = quad
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color, 0.9)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	var origin: Vector3 = Vector3(from.x, maxf(from.y, to.y) + 0.12, from.z)
	m.position = origin + dir * 0.025
	m.basis = Basis(Vector3.UP, atan2(-dir.z, dir.x)).scaled(Vector3(0.05, 1.0, 1.0))
	add_child(m)
	var t: Tween = create_tween()
	if reduced_motion:
		m.position = origin + dir * 0.5
		m.scale.x = 1.0
		t.tween_property(mat, "albedo_color:a", 0.0, SLASH_TIME)
	else:
		# The leading edge leaves the source and arrives at the target; it does not grow
		# backwards through the attacker as a centre-scaled rectangle would.
		t.tween_property(m, "scale:x", 1.0, SLASH_TIME * 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(m, "position", origin + dir * 0.5, SLASH_TIME * 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(mat, "albedo_color:a", 0.0, SLASH_TIME * 0.45)
	t.tween_callback(m.queue_free)


## A ring that spreads out from `pos` and fades: a shield going up, a seal changing hands.
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
	m.scale = Vector3(1.7, 0.6, 1.7) * size if reduced_motion else Vector3(0.3, 0.3, 0.3)
	add_child(m)
	var t: Tween = create_tween()
	t.tween_property(m, "scale", Vector3(1.7, 0.6, 1.7) * size, RING_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(mat, "albedo_color:a", 0.0, RING_TIME).set_delay(RING_TIME * 0.25)
	t.tween_callback(m.queue_free)


## Successful protection closes inward, distinct from an outward damage shock.
func ward(pos: Vector3, color: Color, size: float = 1.0) -> void:
	var crest: MeshInstance3D = _halo(pos, color, 0.58 * size, 0.035)
	crest.scale = Vector3.ONE * (1.0 if reduced_motion else 1.28)
	var mat: StandardMaterial3D = crest.material_override as StandardMaterial3D
	var t: Tween = create_tween()
	t.tween_property(crest, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.15)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.22)
	t.tween_callback(crest.queue_free)
	if not reduced_motion:
		var inner: MeshInstance3D = _halo(pos + Vector3(0, 0.015, 0), color.lightened(0.3), 0.49 * size, 0.012)
		_fade_mesh(inner, 0.45)


## Only call for resolved damage, never merely declaring an attack.
func impact(pos: Vector3, color: Color, strength: float = 1.0) -> void:
	var weight: float = clampf(strength, 0.5, 1.8)
	ring(pos, color, 0.65 * weight)
	burst(pos, color, int(12 * weight), 1.5 * weight)


## Brief ordered rings make a rank change larger than routine resource feedback.
func ascend(pos: Vector3, color: Color, rising: bool = true) -> void:
	if reduced_motion:
		ring(pos, color, 1.2)
		return
	for i in range(3):
		var halo: MeshInstance3D = _halo(pos, color, 0.45 + i * 0.13, 0.018)
		var mat: StandardMaterial3D = halo.material_override as StandardMaterial3D
		var t: Tween = create_tween().set_parallel(true)
		t.tween_property(halo, "position:y", halo.position.y + (0.35 + i * 0.12 if rising else -0.04), 0.6).set_delay(i * 0.075).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(halo, "scale", Vector3.ONE * (1.25 if rising else 0.45), 0.6).set_delay(i * 0.075)
		t.tween_property(mat, "albedo_color:a", 0.0, 0.4).set_delay(0.2 + i * 0.075)
		t.chain().tween_callback(halo.queue_free)
	burst(pos, color, 18, 1.8)


## Gains gather inward; spending releases an outward pulse. Exact values belong to UI.
func resource_pulse(pos: Vector3, color: Color, gain: bool = true) -> void:
	var halo: MeshInstance3D = _halo(pos, color, 0.42, 0.018)
	var mat: StandardMaterial3D = halo.material_override as StandardMaterial3D
	halo.scale = Vector3.ONE * (1.0 if reduced_motion else (1.3 if gain else 0.8))
	var t: Tween = create_tween().set_parallel(true)
	if not reduced_motion:
		t.tween_property(halo, "scale", Vector3.ONE * (0.8 if gain else 1.3), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.38)
	t.chain().tween_callback(halo.queue_free)


## A small travelling mote connects the public source to the affected personality.
func resource_transfer(from: Vector3, to: Vector3, color: Color) -> void:
	if reduced_motion or from.distance_squared_to(to) < 0.02:
		resource_pulse(to, color)
		return
	var mote: MeshInstance3D = _halo(from, color, 0.055, 0.025)
	var mid: Vector3 = (from + to) * 0.5 + Vector3(0, 0.4, 0)
	var t: Tween = create_tween()
	t.tween_property(mote, "position", mid, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(mote, "position", to + Vector3(0, 0.08, 0), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(resource_pulse.bind(to, color, true))
	t.tween_callback(mote.queue_free)


func _halo(pos: Vector3, color: Color, radius: float, width: float) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = maxf(0.005, radius - width)
	mesh.outer_radius = radius + width
	mesh.rings = 32
	mesh.ring_segments = 8
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color, 0.85)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos + Vector3(0, 0.08, 0)
	add_child(node)
	return node


func _fade_mesh(node: MeshInstance3D, duration: float) -> void:
	var mat: StandardMaterial3D = node.material_override as StandardMaterial3D
	var t: Tween = create_tween()
	t.tween_property(mat, "albedo_color:a", 0.0, duration)
	t.tween_callback(node.queue_free)
