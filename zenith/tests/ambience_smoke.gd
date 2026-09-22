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
	var table: Node3D = Node3D.new()
	table.name = "Table"
	world.add_child(table)
	var inlay: MeshInstance3D = MeshInstance3D.new()
	inlay.name = "Inlay"
	var surface: ShaderMaterial = ShaderMaterial.new()
	surface.shader = load("res://assets/arena_surface.gdshader")
	inlay.material_override = surface
	table.add_child(inlay)
	var atmosphere: ArenaAtmosphere = ArenaAtmosphere.new()
	world.add_child(atmosphere)
	var fx: DuelFx = DuelFx.new()
	world.add_child(fx)
	root.add_child(world)
	atmosphere.set_schools(Palette.school_ui("root"), Palette.school_ui("pyre"))
	_check(atmosphere._surface != surface, "School tint must not mutate the shared arena resource")
	_check(atmosphere._surface.get_shader_parameter("seat_zero") == Palette.school_ui("root"), "Seat zero must use its public school")
	_check(atmosphere._mist.get_shader_parameter("seat_one") == Palette.school_ui("pyre"), "Mist must match seat one's public school")
	atmosphere.reduced_motion = true
	var frozen: float = atmosphere._clock
	atmosphere._process(0.5)
	_check(atmosphere._clock == frozen, "Reduced motion must freeze the arena shaders")
	for particles: GPUParticles3D in atmosphere._embers:
		_check(not particles.visible and not particles.emitting, "Reduced motion must immediately hide and stop motes")
	atmosphere.reduced_motion = false
	atmosphere._process(0.5)
	_check(atmosphere._clock > frozen, "Ambient animation must resume after toggling motion back on")
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
