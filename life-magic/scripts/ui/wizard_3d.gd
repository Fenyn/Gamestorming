extends SubViewportContainer

@onready var _viewport: SubViewport = $SubViewport

var _scene_root: Node3D
var _mote_root: Node3D
var _wizard: Node3D
var _platform: MeshInstance3D
var _orb: MeshInstance3D
var _staff: MeshInstance3D
var _arm_l: Node3D
var _arm_r: Node3D
var _head: MeshInstance3D

var _platform_mat: StandardMaterial3D
var _orb_mat: StandardMaterial3D

var _time: float = 0.0
var _anim_time: float = 0.0
var _smooth_hr: float = 1.0

var _motes: Dictionary = {}
var _mote_data: Dictionary = {}

const MAX_MOTES := 50
const BASE_EMISSION := 1.5


func _ready() -> void:
	_setup_viewport()
	_build_scene()

	EventBus.generator_purchased.connect(_on_generator_purchased)
	EventBus.tick_fired.connect(func(_t): _on_tick())
	EventBus.seasonal_rebirth_executed.connect(_on_prestige)
	EventBus.heart_rate_updated.connect(_on_hr_updated)
	EventBus.cascade_echo_triggered.connect(_on_cascade_echo)
	EventBus.harmonic_beat_triggered.connect(_on_harmonic_beat)
	EventBus.bloom_burst_triggered.connect(_on_bloom_burst)

	_sync_all_motes()
	_on_hr_updated(HeartRateManager.smoothed_bpm, HeartRateManager.get_hr_factor())


func _setup_viewport() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.25, 0.35)
	env.ambient_light_energy = 0.5
	env_node.environment = env
	_viewport.add_child(env_node)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.0, 5.5)
	camera.look_at(Vector3(0, 0.45, 0))
	camera.fov = 28
	_viewport.add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	light.light_energy = 0.7
	_viewport.add_child(light)


func _build_scene() -> void:
	_scene_root = Node3D.new()
	_viewport.add_child(_scene_root)

	_mote_root = Node3D.new()
	_viewport.add_child(_mote_root)

	_build_platform()
	_build_wizard()
	_apply_prestige_visuals()


func _build_platform() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.6
	mesh.bottom_radius = 0.65
	mesh.height = 0.06
	mesh.radial_segments = 12
	_platform = _create_mesh(mesh, Color(0.15, 0.25, 0.15))
	_platform_mat = _platform.material_override
	_platform_mat.emission_enabled = true
	_platform_mat.emission = Color(0.2, 0.5, 0.3)
	_platform_mat.emission_energy_multiplier = 1.5
	_scene_root.add_child(_platform)

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.55
	ring_mesh.outer_radius = 0.6
	ring_mesh.rings = 16
	ring_mesh.ring_segments = 8
	var ring := _create_mesh(ring_mesh, Color(0.1, 0.3, 0.15))
	var ring_mat := ring.material_override as StandardMaterial3D
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.2, 0.6, 0.3)
	ring_mat.emission_energy_multiplier = 1.0
	ring.position.y = 0.04
	_scene_root.add_child(ring)


func _build_wizard() -> void:
	_wizard = Node3D.new()
	_scene_root.add_child(_wizard)

	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.15
	body_mesh.bottom_radius = 0.28
	body_mesh.height = 0.55
	body_mesh.radial_segments = 6
	var body := _create_mesh(body_mesh, Color(0.12, 0.08, 0.3))
	body.position = Vector3(0, 0.33, 0)
	_wizard.add_child(body)

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.14
	head_mesh.height = 0.28
	head_mesh.radial_segments = 8
	head_mesh.rings = 4
	_head = _create_mesh(head_mesh, Color(0.85, 0.7, 0.55))
	_head.position = Vector3(0, 0.72, 0)
	_wizard.add_child(_head)

	var hat_mesh := CylinderMesh.new()
	hat_mesh.top_radius = 0.0
	hat_mesh.bottom_radius = 0.18
	hat_mesh.height = 0.35
	hat_mesh.radial_segments = 6
	var hat := _create_mesh(hat_mesh, Color(0.2, 0.08, 0.35))
	hat.position = Vector3(0, 1.0, 0)
	_wizard.add_child(hat)

	var brim_mesh := CylinderMesh.new()
	brim_mesh.top_radius = 0.22
	brim_mesh.bottom_radius = 0.22
	brim_mesh.height = 0.03
	brim_mesh.radial_segments = 8
	var brim := _create_mesh(brim_mesh, Color(0.2, 0.08, 0.35))
	brim.position = Vector3(0, 0.84, 0)
	_wizard.add_child(brim)

	var arm_mesh := CylinderMesh.new()
	arm_mesh.top_radius = 0.04
	arm_mesh.bottom_radius = 0.035
	arm_mesh.height = 0.3
	arm_mesh.radial_segments = 4

	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.17, 0.55, 0)
	var arm_l_vis := _create_mesh(arm_mesh, Color(0.12, 0.08, 0.3))
	arm_l_vis.position = Vector3(-0.15, -0.04, 0)
	arm_l_vis.rotation_degrees.z = 70
	_arm_l.add_child(arm_l_vis)
	_wizard.add_child(_arm_l)

	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.17, 0.55, 0)
	var arm_r_vis := _create_mesh(arm_mesh.duplicate(), Color(0.12, 0.08, 0.3))
	arm_r_vis.position = Vector3(0.15, -0.04, 0)
	arm_r_vis.rotation_degrees.z = -70
	_arm_r.add_child(arm_r_vis)
	_wizard.add_child(_arm_r)

	var staff_mesh := CylinderMesh.new()
	staff_mesh.top_radius = 0.02
	staff_mesh.bottom_radius = 0.025
	staff_mesh.height = 0.9
	staff_mesh.radial_segments = 4
	_staff = _create_mesh(staff_mesh, Color(0.35, 0.22, 0.1))
	_staff.position = Vector3(0.2, 0.1, 0.05)
	_arm_r.add_child(_staff)

	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.07
	orb_mesh.height = 0.14
	orb_mesh.radial_segments = 6
	orb_mesh.rings = 3
	_orb = _create_mesh(orb_mesh, Color(0.3, 0.9, 0.4))
	_orb.position = Vector3(0.2, 0.55, 0.05)
	_orb_mat = _orb.material_override
	_orb_mat.emission_enabled = true
	_orb_mat.emission = Color(0.3, 0.9, 0.4)
	_orb_mat.emission_energy_multiplier = 2.0
	_arm_r.add_child(_orb)


func _apply_prestige_visuals() -> void:
	var cycles := GameState.life_cycles
	if cycles <= 0:
		return

	var robe_color := Color(0.12, 0.08, 0.3)
	if cycles >= 10:
		robe_color = Color(0.5, 0.35, 0.1)
	elif cycles >= 6:
		robe_color = Color(0.15, 0.1, 0.45)
	elif cycles >= 3:
		robe_color = Color(0.1, 0.12, 0.4)
	elif cycles >= 1:
		robe_color = Color(0.08, 0.1, 0.35)

	for child in _wizard.get_children():
		if child is MeshInstance3D and child != _head and child != _staff and child != _orb:
			var mat: StandardMaterial3D = child.material_override
			if mat and mat.albedo_color.is_equal_approx(Color(0.12, 0.08, 0.3)):
				mat.albedo_color = robe_color

	if _orb_mat and cycles >= 3:
		var glow := 2.0 + cycles * 0.3
		_orb_mat.emission_energy_multiplier = minf(glow, 6.0)

	if cycles >= 6:
		_orb_mat.emission = Color(0.9, 0.7, 0.2)
		_orb_mat.albedo_color = Color(0.9, 0.7, 0.2)


func _create_mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mi.material_override = mat
	return mi


# --- Mote System ---


func clear_all_motes() -> void:
	for tier in _motes:
		for mote in _motes[tier]:
			mote.queue_free()
	_motes.clear()
	_mote_data.clear()


func update_motes(tier: int) -> void:
	if tier < 0 or tier > 7:
		return

	var owned := int(GameState.get_generator_owned(tier))
	var produced := GameState.get_generator_produced(tier)
	var target := mini(owned, MAX_MOTES)

	if not _motes.has(tier):
		_motes[tier] = []
		_mote_data[tier] = []

	var current: Array = _motes[tier]

	while current.size() < target:
		var mote := _create_mote(tier)
		mote.visible = false
		_mote_root.add_child(mote)
		current.append(mote)
		var orbit_data := _create_mote_orbit_data(tier)
		orbit_data["visible"] = false
		_mote_data[tier].append(orbit_data)

	while current.size() > target:
		var mote: MeshInstance3D = current.pop_back()
		_mote_data[tier].pop_back()
		mote.queue_free()

	var bonus_glow := clampf(log(produced + 1.0) * 0.4, 0.0, 3.0)
	var bonus_scale := 1.0 + clampf(log(produced + 1.0) * 0.08, 0.0, 0.6)
	for i in current.size():
		var mat := current[i].material_override as StandardMaterial3D
		mat.emission_energy_multiplier = BASE_EMISSION + bonus_glow
		_mote_data[tier][i]["bonus_scale"] = bonus_scale


func _create_mote_orbit_data(tier: int) -> Dictionary:
	var d := {
		"angle": randf() * TAU,
		"phase": randf() * TAU,
		"bonus_scale": 1.0,
	}
	match tier:
		0:
			d["rise_phase"] = randf()
			d["wobble_freq"] = randf_range(2.0, 4.0)
		1:
			d["strand"] = randi() % 2
			d["vert_offset"] = randf() * 1.2
		2:
			d["height"] = randf_range(0.35, 0.75)
			d["speed_mult"] = randf_range(0.8, 1.2)
		3:
			d["tilt"] = randf_range(0.4, 1.3)
			d["pulse_speed"] = randf_range(1.5, 3.0)
		4:
			d["fall_phase"] = randf()
			d["spin_speed"] = randf_range(1.0, 2.5)
	return d


func _create_mote(tier: int) -> MeshInstance3D:
	var mesh: Mesh
	match tier:
		0:
			var s := SphereMesh.new()
			s.radius = 0.025
			s.height = 0.05
			s.radial_segments = 4
			s.rings = 2
			mesh = s
		1:
			var b := BoxMesh.new()
			b.size = Vector3(0.04, 0.04, 0.04)
			mesh = b
		2:
			var s := SphereMesh.new()
			s.radius = 0.045
			s.height = 0.09
			s.radial_segments = 6
			s.rings = 3
			mesh = s
		3:
			var s := SphereMesh.new()
			s.radius = 0.055
			s.height = 0.11
			s.radial_segments = 8
			s.rings = 4
			mesh = s
		4:
			var p := PrismMesh.new()
			p.size = Vector3(0.05, 0.08, 0.05)
			mesh = p

	var color: Color = ThemeBuilder.get_tier_color(tier)
	var mi := _create_mesh(mesh, color)
	var mat := mi.material_override as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	return mi


# --- Animation ---


func _process(delta: float) -> void:
	_time += delta
	var hr_factor := HeartRateManager.get_hr_factor()
	_smooth_hr = lerpf(_smooth_hr, hr_factor, 2.0 * delta)
	_anim_time += delta * lerpf(0.65, 8.0, clampf((_smooth_hr - 1.0) / 2.0, 0.0, 1.0))

	var bob_amp := lerpf(0.02, 0.07, clampf((_smooth_hr - 1.0) / 2.0, 0.0, 1.0))
	_wizard.position.y = sin(_time * 0.8) * bob_amp
	_scene_root.rotation.y += delta * 0.15

	var swing := clampf((_smooth_hr - 0.8) * 0.6, 0.08, 0.8)
	_arm_l.rotation_degrees.z = sin(_anim_time * 0.5) * 15 * swing
	_arm_l.rotation_degrees.x = sin(_anim_time * 0.309) * 10 * swing
	_arm_r.rotation_degrees.z = sin(_anim_time * 0.5 + 2.4) * 15 * swing
	_arm_r.rotation_degrees.x = sin(_anim_time * 0.309 + 1.4) * 10 * swing
	_head.rotation_degrees.x = sin(_anim_time * 0.185) * 4 * swing
	_head.rotation_degrees.z = sin(_anim_time * 0.115) * 3 * swing

	var intensity := 1.0 + (_smooth_hr - 1.0) * 3.0
	_orb_mat.emission_energy_multiplier = intensity

	_animate_motes()


func _animate_motes() -> void:
	if _motes.has(0):
		_animate_heartmotes()
	if _motes.has(1):
		_animate_pulse_glyphs()
	if _motes.has(2):
		_animate_familiars()
	if _motes.has(3):
		_animate_wardens()
	if _motes.has(4):
		_animate_spires()


func _animate_heartmotes() -> void:
	var list: Array = _motes[0]
	var data_list: Array = _mote_data[0]
	for i in list.size():
		var mote: MeshInstance3D = list[i]
		var d: Dictionary = data_list[i]
		if not d.get("visible", true):
			continue
		var rp: float = d["rise_phase"]
		var wf: float = d["wobble_freq"]
		var a: float = d["angle"]
		var p: float = d["phase"]
		var rise := fmod(_anim_time * 0.12 + rp, 1.0)
		var y := lerpf(0.7, 1.8, rise)
		var r := 0.3 + sin(rise * PI) * 0.2
		var wobble_x := sin(_anim_time * wf * 0.5 + a) * r
		var wobble_z := cos(_anim_time * wf * 0.35 + p) * r
		mote.position = Vector3(wobble_x, y, wobble_z)
		var fade := sin(rise * PI)
		var bs: float = d["bonus_scale"]
		mote.scale = Vector3.ONE * maxf(fade, 0.3) * 0.8 * bs


func _animate_pulse_glyphs() -> void:
	var list: Array = _motes[1]
	var data_list: Array = _mote_data[1]
	var count := list.size()
	for i in count:
		var mote: MeshInstance3D = list[i]
		var d: Dictionary = data_list[i]
		if not d.get("visible", true):
			continue
		var a: float = d["angle"]
		var p: float = d["phase"]
		var vo: float = d["vert_offset"]
		var base_angle := TAU * float(i) / float(maxi(count, 1)) + _anim_time * 0.35
		var r := 0.5 + sin(_anim_time * 0.3 + a) * 0.08
		var x := r * cos(base_angle)
		var z := r * sin(base_angle)
		var y := 0.4 + vo * 0.3 + sin(_anim_time * 0.5 + p) * 0.06
		mote.position = Vector3(x, y, z)
		var bs: float = d["bonus_scale"]
		mote.scale = Vector3.ONE * bs
		mote.rotation.y = _anim_time * 0.8 + a
		mote.rotation.x = sin(_anim_time * 0.4 + p) * 0.3


func _animate_familiars() -> void:
	var list: Array = _motes[2]
	var data_list: Array = _mote_data[2]
	for i in list.size():
		var mote: MeshInstance3D = list[i]
		var d: Dictionary = data_list[i]
		if not d.get("visible", true):
			continue
		var a: float = d["angle"]
		var p: float = d["phase"]
		var sm: float = d["speed_mult"]
		var t: float = _anim_time * 0.3 * sm + a
		var y := 0.15 + absf(sin(t * 1.2)) * 1.1
		var wander_x := sin(t * 0.7 + p) * 0.5
		var wander_z := cos(t * 0.5 + a) * 0.5
		mote.position = Vector3(wander_x, y, wander_z)
		var bs: float = d["bonus_scale"]
		mote.scale = Vector3.ONE * bs


func _animate_wardens() -> void:
	var list: Array = _motes[3]
	var data_list: Array = _mote_data[3]
	for i in list.size():
		var mote: MeshInstance3D = list[i]
		var d: Dictionary = data_list[i]
		if not d.get("visible", true):
			continue
		var a: float = d["angle"]
		var p: float = d["phase"]
		var ps: float = d["pulse_speed"]
		var slot := float(i) / float(maxi(list.size(), 1))
		var fixed_angle := slot * TAU + a
		var r := 0.9 + sin(_anim_time * 0.2 + p) * 0.1
		var x := r * cos(fixed_angle)
		var z := r * sin(fixed_angle)
		var y := 0.3 + sin(_anim_time * 0.15 + p) * 0.4 + sin(_anim_time * 0.243 + a) * 0.2
		mote.position = Vector3(x, y, z)
		var bs: float = d["bonus_scale"]
		var pulse := 1.0 + sin(_anim_time * ps * 0.3 + p) * 0.12
		mote.scale = Vector3.ONE * pulse * bs


func _animate_spires() -> void:
	var list: Array = _motes[4]
	var data_list: Array = _mote_data[4]
	for i in list.size():
		var mote: MeshInstance3D = list[i]
		var d: Dictionary = data_list[i]
		if not d.get("visible", true):
			continue
		var a: float = d["angle"]
		var fp: float = d["fall_phase"]
		var ss: float = d["spin_speed"]
		var fall := fmod(_anim_time * 0.06 + fp, 1.0)
		var y := lerpf(1.8, 0.05, fall)
		var spiral_angle := a + fall * TAU * 2.0
		var r := 0.7 + sin(fall * PI) * 0.3
		var x := r * cos(spiral_angle)
		var z := r * sin(spiral_angle)
		mote.position = Vector3(x, y, z)
		var bs: float = d["bonus_scale"]
		var fade := sin(fall * PI)
		mote.scale = Vector3.ONE * (0.3 + fade * 0.7) * bs
		mote.rotation.y = _anim_time * ss * 0.4
		mote.rotation.z = _anim_time * ss * 0.25


# --- Events ---


func flash_tick() -> void:
	_platform_mat.emission_energy_multiplier = 2.2
	var tween := create_tween()
	tween.tween_property(_platform_mat, "emission_energy_multiplier", 1.5, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	for tier in _motes:
		var mote_list: Array = _motes[tier]
		var data_list: Array = _mote_data[tier]
		for i in mote_list.size():
			var mote: MeshInstance3D = mote_list[i]
			var d: Dictionary = data_list[i]
			if not d.get("visible", true):
				d["visible"] = true
				mote.visible = true
				mote.scale = Vector3.ZERO
				var pop_tween := create_tween()
				pop_tween.tween_property(mote, "scale", Vector3.ONE * 0.8, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			else:
				var mat := mote.material_override as StandardMaterial3D
				mat.emission_energy_multiplier = 2.5
				var mote_tween := create_tween()
				mote_tween.tween_property(mat, "emission_energy_multiplier", 1.5, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
				if tier == 0:
					var base_scale: float = d.get("bonus_scale", 1.0) * 0.8
					mote.scale = Vector3.ONE * base_scale * 1.3
					var pulse_tween := create_tween()
					pulse_tween.tween_property(mote, "scale", Vector3.ONE * base_scale, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func _on_prestige(_essence_earned: int) -> void:
	clear_all_motes()
	_apply_prestige_visuals()


func _on_hr_updated(bpm: float, _hr_factor: float) -> void:
	var zone := GameFormulas.get_hr_zone(bpm, GameState.get_age())
	set_zone_color(zone["color"])


func set_zone_color(color: Color) -> void:
	_platform_mat.emission = color.darkened(0.3)
	_platform_mat.albedo_color = color.darkened(0.6)


func _on_generator_purchased(tier: int, _count: float) -> void:
	update_motes(tier)


func _on_tick() -> void:
	flash_tick()
	_sync_all_motes()


func _sync_all_motes() -> void:
	for tier in range(8):
		if GameState.is_tier_unlocked(tier):
			update_motes(tier)
	for tier in _mote_data:
		for d in _mote_data[tier]:
			d["visible"] = true
	for tier in _motes:
		for mote in _motes[tier]:
			mote.visible = true


# --- Special Trigger VFX ---


func _on_cascade_echo(tier: int) -> void:
	var color: Color = ThemeBuilder.get_tier_color(tier)
	var flash := _create_vfx_sphere(0.15, color, 3.0)
	flash.position = Vector3(0, 0.8, 0)
	_mote_root.add_child(flash)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 4.0, 0.4).set_ease(Tween.EASE_OUT)
	var mat: StandardMaterial3D = flash.material_override
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.4)
	tween.chain().tween_callback(flash.queue_free)


func _on_harmonic_beat() -> void:
	var ring := _create_vfx_ring(0.1, 0.15, Color(1.0, 0.85, 0.2), 4.0)
	ring.position = Vector3(0, 0.5, 0)
	_mote_root.add_child(ring)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(6.0, 1.5, 6.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	var mat: StandardMaterial3D = ring.material_override
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.5)
	tween.chain().tween_callback(ring.queue_free)

	_orb_mat.emission_energy_multiplier = 5.0
	var orb_tween := create_tween()
	orb_tween.tween_property(_orb_mat, "emission_energy_multiplier", 2.0, 0.8).set_ease(Tween.EASE_OUT)


func _on_bloom_burst(_plot_id: String) -> void:
	for i in 8:
		var petal := _create_vfx_sphere(0.06, Color(0.8, 0.5, 0.85), 2.5)
		var angle: float = float(i) * TAU / 8.0
		petal.position = Vector3(0, 0.4, 0)
		_mote_root.add_child(petal)

		var target := Vector3(cos(angle) * 1.5, 0.4 + randf_range(-0.3, 0.5), sin(angle) * 1.5)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(petal, "position", target, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		var mat: StandardMaterial3D = petal.material_override
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.8).set_ease(Tween.EASE_IN).set_delay(0.3)
		tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.8).set_delay(0.3)
		tween.chain().tween_callback(petal.queue_free)

	_platform_mat.emission = Color(0.6, 0.3, 0.7)
	_platform_mat.emission_energy_multiplier = 3.0
	var plat_tween := create_tween()
	plat_tween.tween_property(_platform_mat, "emission_energy_multiplier", 1.5, 1.0).set_ease(Tween.EASE_OUT)


func _create_vfx_sphere(radius: float, color: Color, emission_power: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emission_power
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi


func _create_vfx_ring(inner: float, outer: float, color: Color, emission_power: float) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 16
	mesh.ring_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emission_power
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi
