extends SceneTree
## Atmosphere must respect motion settings, use public identity, and clean up bursts.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	var world: Node3D = Node3D.new()
	var table: MeshInstance3D = MeshInstance3D.new()
	table.name = "Table"
	table.mesh = BoxMesh.new()
	world.add_child(table)
	var inlay: MeshInstance3D = MeshInstance3D.new()
	inlay.name = "Inlay"
	var surface: StandardMaterial3D = StandardMaterial3D.new()
	inlay.material_override = surface
	table.add_child(inlay)
	var atmosphere: ArenaAtmosphere = ArenaAtmosphere.new()
	world.add_child(atmosphere)
	var fx: DuelFx = DuelFx.new()
	world.add_child(fx)
	root.add_child(world)
	atmosphere.set_schools(Palette.school_ui("root"), Palette.school_ui("pyre"))
	_check(inlay.material_override == surface, "The playmat is the scene's own and the atmosphere must leave it alone")
	_check(table.get_surface_override_material(0) is StandardMaterial3D, "The table under the mat must be lit courtyard stone")
	# The courtyard set itself: its drifting leaves stop the moment motion is reduced.
	var courtyard: CourtyardSet = CourtyardSet.new()
	world.add_child(courtyard)
	_check(not courtyard._leaves.is_empty(), "The courtyard must carry its drifting leaves")
	courtyard.reduced_motion = true
	courtyard._process(0.5)
	for particles: GPUParticles3D in courtyard._leaves:
		_check(not particles.visible and not particles.emitting, "Reduced motion must immediately hide and stop the leaves")
	courtyard.reduced_motion = false
	courtyard._process(0.5)
	for particles: GPUParticles3D in courtyard._leaves:
		_check(particles.visible and particles.emitting, "The leaves must resume after toggling motion back on")
	var backdrop: ArcaneBackdrop = ArcaneBackdrop.new()
	root.add_child(backdrop)
	ArcaneBackdrop.reduced_motion = true
	backdrop.set_school(Palette.school_ui("shade"))
	backdrop.confirm()
	var before: float = backdrop._clock
	backdrop._process(0.5)
	_check(backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Decorative backdrop must never intercept selection input")
	_check(backdrop._clock == before and backdrop._pulse == 0.0, "Reduced motion must suppress backdrop movement and confirmation flashes")
	_check(backdrop._color == Palette.school_ui("shade"), "Reduced motion must still update selected school identity")
	ArcaneBackdrop.reduced_motion = false
	var first: GPUParticles3D = EffectBlocks.make("impacts/impact_4") as GPUParticles3D
	var second: GPUParticles3D = EffectBlocks.make("impacts/impact_4") as GPUParticles3D
	EffectBlocks.tint(first, Color.RED)
	EffectBlocks.tint(second, Color.BLUE)
	_check(first.process_material != second.process_material, "Pack particle materials must be private per instance")
	_check(first.process_material.color == Color.RED, "Tinting another effect must not recolor the first")
	_check(first.get_script() == null, "Pack demo keyboard triggers must be detached")
	first.free()
	second.free()
	_check(DuelFx.tone(ZenithTheme.DEFEND) == DuelFx.WARD_TONE and DuelFx.tone(ZenithTheme.ACCENT) == DuelFx.RISE_TONE, "Table effects must draw defence and accent in the courtyard tones")
	_check(DuelFx.tone(ZenithTheme.ATTACK) == ZenithTheme.ATTACK, "Other role colours must pass through unchanged")
	fx.impact(Vector3.ZERO, ZenithTheme.ATTACK)
	fx.ward(Vector3.RIGHT, ZenithTheme.DEFEND)
	fx.ascend(Vector3.LEFT, ZenithTheme.ACCENT)
	_check(fx.get_child_count() > 0, "Combat effects must create their visual geometry")
	await create_timer(1.5).timeout
	_check(fx.get_child_count() == 0, "All transient combat meshes and particles must clean up")
	fx.reduced_motion = true
	fx.impact(Vector3.ZERO, ZenithTheme.ATTACK)
	fx.ward(Vector3.RIGHT, ZenithTheme.DEFEND)
	fx.ascend(Vector3.LEFT, ZenithTheme.ACCENT)
	for child: Node in fx.get_children():
		_check(not child is CPUParticles3D and not child is GPUParticles3D, "Reduced effects must not emit sparks")
		if child is MeshInstance3D:
			_check(not child.material_override is ShaderMaterial, "Reduced effects must omit expanding waves and light columns")
	await create_timer(1.0).timeout
	_check(fx.get_child_count() == 0, "Reduced feedback must also clean up")
	world.queue_free()
	backdrop.queue_free()
	await process_frame
	print("Ambience smoke: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
