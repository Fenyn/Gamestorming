class_name DuelFx
extends Node3D
## Table feedback: transient impacts and one reusable attack filament. Transient meshes
## free themselves after their tweens; the filament holds the public response state.
## Colours come from ZenithTheme roles, passed through `tone`.

## On the courtyard stone the HUD's saturated defence blue glows like neon and bone reads as a
## white hole, so the table effects draw those two roles in weathered tones. The HUD keeps its own
## colours.
const WARD_TONE: Color = Color(0.72, 0.78, 0.82)   # pale slate
const RISE_TONE: Color = Color(0.93, 0.87, 0.72)   # old ivory
const OUTLINE: Color = Color(0.03, 0.025, 0.03, 0.9)
const TEXT_RISE: float = 0.5
const TEXT_TIME: float = 1.2
const TEXT_LIFT: float = 0.3
const SLASH_TIME: float = 0.4
const RING_TIME: float = 0.55
## The pack effects the duel plays, which `prewarm` compiles ahead of the first real hit.
const PREWARM_EFFECTS: Array[String] = ["impacts/impact_1", "impacts/impact_4", "ground_effects/ground_effect_1", "loot/power_up"]
@export var reduced_motion: bool = false
var _attack_link: MeshInstance3D = null
var _link_state: StringName = &""
var _link_from: Vector3
var _link_to: Vector3


## A quiet, static filament while a public attack is awaiting a response. Geometry
## carries direction and result even with reduced motion; it never intercepts input.
func show_attack_link(from: Vector3, to: Vector3, state: StringName = &"pending") -> void:
	if _attack_link != null and _attack_link.visible and _link_state == state \
		and _link_from.is_equal_approx(from) and _link_to.is_equal_approx(to):
		return
	var travel: Vector3 = to - from
	travel.y = 0.0
	if travel.length() < 1.1:
		clear_attack_link()
		return
	_link_from = from
	_link_to = to
	_link_state = state
	if _attack_link == null:
		_attack_link = MeshInstance3D.new()
		_attack_link.name = "AttackFilament"
		_attack_link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_attack_link.material_override = material
		add_child(_attack_link)
	_attack_link.show()
	var direction: Vector3 = travel.normalized()
	var side: Vector3 = direction.cross(Vector3.UP).normalized()
	var start: Vector3 = from + direction * 0.48
	var end: Vector3 = to - direction * 0.32
	var height: float = maxf(from.y, to.y) + 0.12
	start.y = height
	end.y = height
	var middle: Vector3 = (start + end) * 0.5 + side * 0.28 + Vector3.UP * 0.14
	# A landed attack keeps the attack colour and thickens, so the hit reads as the same line
	# arriving rather than turning into something paler.
	var color: Color = ZenithTheme.ATTACK.lightened(0.25)
	var width: float = 0.021
	if state == &"stopped":
		color = WARD_TONE
	elif state == &"landed":
		color = ZenithTheme.ATTACK
		width = 0.034
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous: Vector3 = start
	for i in range(1, 25):
		var ratio: float = float(i) / 24.0
		var point: Vector3 = start.lerp(middle, ratio).lerp(middle.lerp(end, ratio), ratio)
		_link_segment(mesh, previous, point, width, Color(color, 0.38 if state == &"stopped" else (0.85 if state == &"landed" else 0.64)))
		previous = point
	if state == &"stopped":
		# A transverse ward closes the path; a stopped attack never gets an arrowhead.
		_link_segment(mesh, end - side * 0.13, end + side * 0.13, 0.022, Color(color, 0.9))
	else:
		_link_chevron(mesh, end, direction, side, color)
		if state == &"landed":
			_link_chevron(mesh, end - direction * 0.14, direction, side, color)
	mesh.surface_end()
	_attack_link.mesh = mesh


func clear_attack_link() -> void:
	_link_state = &""
	if _attack_link != null:
		_attack_link.hide()


func _link_chevron(mesh: ImmediateMesh, tip: Vector3, direction: Vector3, side: Vector3, color: Color) -> void:
	_link_segment(mesh, tip - direction * 0.17 + side * 0.09, tip, 0.026, Color(color, 0.95))
	_link_segment(mesh, tip - direction * 0.17 - side * 0.09, tip, 0.026, Color(color, 0.95))


func _link_segment(mesh: ImmediateMesh, from: Vector3, to: Vector3, width: float, color: Color) -> void:
	var side: Vector3 = (to - from).cross(Vector3.UP).normalized() * width * 0.5
	mesh.surface_set_color(color)
	for point in [from - side, from + side, to + side, from - side, to + side, to - side]:
		mesh.surface_add_vertex(to_local(point))


## A number or word that pops in over `pos`, drifts up and fades.
## The table's version of a HUD role colour: defence and accent become WARD_TONE and RISE_TONE,
## everything else passes through.
static func tone(color: Color) -> Color:
	if color == ZenithTheme.DEFEND:
		return WARD_TONE
	if color == ZenithTheme.ACCENT:
		return RISE_TONE
	return color


func float_text(pos: Vector3, text: String, color: Color, size: int = 64, rise: float = TEXT_RISE) -> void:
	color = tone(color)
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
	l.outline_modulate = OUTLINE
	l.outline_size = 14
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.shaded = false
	l.position = pos + Vector3(0, TEXT_LIFT, 0)
	l.scale = Vector3.ONE if reduced_motion else Vector3.ONE * 0.65
	add_child(l)
	var t: Tween = create_tween()
	t.tween_property(l, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "position:y", l.position.y + (0.0 if reduced_motion else rise), TEXT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, TEXT_TIME * 0.45).set_delay(TEXT_TIME * 0.55)
	t.parallel().tween_property(l, "outline_modulate:a", 0.0, TEXT_TIME * 0.45).set_delay(TEXT_TIME * 0.55)
	t.tween_callback(l.queue_free)


## A word that travels from `from` to `to` and fades there, for something moving between two
## places on the table (Energy spilling over into wounds). Reduced motion shows it at `to`.
func slide_text(from: Vector3, to: Vector3, text: String, color: Color, time: float, size: int = 60) -> void:
	color = tone(color)
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_modulate = OUTLINE
	l.outline_size = 14
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.shaded = false
	var lift: Vector3 = Vector3(0, TEXT_LIFT, 0)
	l.position = (to if reduced_motion else from) + lift
	add_child(l)
	var t: Tween = create_tween()
	if not reduced_motion:
		t.tween_property(l, "position", to + lift, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_interval(0.35)
	t.tween_property(l, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(l, "outline_modulate:a", 0.0, 0.3)
	t.tween_callback(l.queue_free)


## Authored EffectBlocks sparks radiate from `pos` and fade.
func burst(pos: Vector3, color: Color, count: int = 28, speed: float = 2.2) -> void:
	color = tone(color)
	if reduced_motion:
		return
	var particles: GPUParticles3D = EffectBlocks.play(self, "impacts/impact_4", pos, color, 1.0, 0.8) as GPUParticles3D
	particles.amount = count
	var material: ParticleProcessMaterial = particles.process_material
	material.initial_velocity_min = speed * 0.4
	material.initial_velocity_max = speed
	particles.restart()


## A bright streak from one card to another, lying just above the table, that fades.
func slash(from: Vector3, to: Vector3, color: Color) -> void:
	color = tone(color)
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
	color = tone(color)
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
	color = tone(color)
	if not reduced_motion:
		var ward_effect: Node3D = EffectBlocks.play(self, "ground_effects/ground_effect_1", pos, color, size * 1.2, 0.65)
		var close: Tween = create_tween()
		close.tween_property(ward_effect, "scale", ward_effect.scale * 0.6, 0.6)
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


## Plays each pack effect the duel uses once, shrunk to nothing at the middle of the table, so
## their materials are ready before the first real hit instead of hitching on it.
func prewarm() -> void:
	for effect in PREWARM_EFFECTS:
		prewarm_one(effect)


func prewarm_one(effect: String) -> void:
	EffectBlocks.play(self, effect, Vector3.ZERO, Color.WHITE, 0.001, 0.3)


## Only call for resolved damage, never merely declaring an attack.
func impact(pos: Vector3, color: Color, strength: float = 1.0) -> void:
	var weight: float = clampf(strength, 0.5, 1.8)
	ring(pos, color, 0.65 * weight)
	burst(pos, color.lightened(0.2), int(22 * weight), 2.0 * weight)
	if not reduced_motion:
		EffectBlocks.play(self, "impacts/impact_1", pos, color, 0.8 * weight, 1.0)


## A rising power-up effect distinguishes ascension from routine resource feedback.
func ascend(pos: Vector3, color: Color, rising: bool = true) -> void:
	color = tone(color)
	if reduced_motion:
		ring(pos, color, 1.2)
		return
	if rising:
		var effect: Node3D = EffectBlocks.play(self, "loot/power_up", pos + Vector3.UP * 0.5, color, 1.2, 1.3)
		var arrows: GPUParticles3D = effect.get_node("PowerUp")
		var arrow_material: StandardMaterial3D = arrows.draw_pass_1.surface_get_material(0)
		arrow_material.albedo_color.a = 0.24
		arrow_material.emission_energy_multiplier = 4.0
		arrows.lifetime = 0.8
		arrows.explosiveness = 0.5
		arrows.restart()
		var fade: Tween = create_tween()
		fade.tween_interval(0.75)
		fade.tween_property(effect, "scale", Vector3.ONE * 0.05, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		ward(pos, color, 1.2)
	burst(pos, color.lightened(0.25), 32, 1.6)


## Gains gather inward; spending releases an outward pulse. Exact values belong to UI.
func resource_pulse(pos: Vector3, color: Color, gain: bool = true) -> void:
	color = tone(color)
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
	color = tone(color)
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
