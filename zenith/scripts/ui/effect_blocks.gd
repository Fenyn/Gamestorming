class_name EffectBlocks
extends RefCounted
## Instantiates the authored pack scenes with private materials and game-owned timing.
## Demo input scripts are detached before _ready: Enter must never replay an effect.

const SCENES: Dictionary = {
	"fire/fire_light": preload("res://PolyBlocks/EffectBlocks/assets/fire/fire_light.tscn"),
	"other/dust": preload("res://PolyBlocks/EffectBlocks/assets/other/dust.tscn"),
	"other/fireflies": preload("res://PolyBlocks/EffectBlocks/assets/other/fireflies.tscn"),
	"other/portal_magic": preload("res://PolyBlocks/EffectBlocks/assets/other/portal_magic.tscn"),
	"impacts/impact_1": preload("res://PolyBlocks/EffectBlocks/assets/impacts/impact_1.tscn"),
	"impacts/impact_4": preload("res://PolyBlocks/EffectBlocks/assets/impacts/impact_4.tscn"),
	"ground_effects/ground_effect_1": preload("res://PolyBlocks/EffectBlocks/assets/ground_effects/ground_effect_1.tscn"),
	"loot/power_up": preload("res://PolyBlocks/EffectBlocks/assets/loot/power_up.tscn"),
}


static func make(effect: String) -> Node3D:
	var scene: PackedScene = SCENES[effect]
	var node: Node3D = scene.instantiate()
	_prepare(node)
	return node


static func _prepare(node: Node) -> void:
	if node.get_script() != null:
		node.set_script(null)
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is GPUParticles3D:
		node.process_material = node.process_material.duplicate(true)
		node.visibility_aabb = AABB(Vector3(-16, -8, -16), Vector3(32, 20, 32))
		node.fixed_fps = 30
		node.local_coords = true
		if not node.one_shot:
			node.preprocess = minf(node.lifetime, 3.0)
		for i in range(node.draw_passes):
			node.set_draw_pass_mesh(i, _private_mesh(node.get_draw_pass_mesh(i)))
	elif node is MeshInstance3D:
		node.mesh = _private_mesh(node.mesh)
	for child in node.get_children():
		_prepare(child)


static func _private_mesh(source: Mesh) -> Mesh:
	var mesh: Mesh = source.duplicate()
	for i in range(mesh.get_surface_count()):
		var material: Material = mesh.surface_get_material(i)
		if material != null:
			mesh.surface_set_material(i, material.duplicate(true))
	return mesh


static func tint(node: Node, color: Color) -> void:
	if node is GPUParticles3D:
		var material: ParticleProcessMaterial = node.process_material
		material.color = color
		for i in range(node.draw_passes):
			_tint_mesh(node.get_draw_pass_mesh(i), color)
	elif node is MeshInstance3D:
		_tint_mesh(node.mesh, color)
	elif node is Light3D:
		node.light_color = color
	for child in node.get_children():
		tint(child, color)


static func _tint_mesh(mesh: Mesh, color: Color) -> void:
	for i in range(mesh.get_surface_count()):
		var material: Material = mesh.surface_get_material(i)
		if material is StandardMaterial3D:
			# Particle process colors carry the tint; remove the pack's fixed palette.
			material.albedo_color = Color(1, 1, 1, material.albedo_color.a)
			material.emission = color
			material.emission_energy_multiplier = minf(material.emission_energy_multiplier, 2.0)
		elif material is ShaderMaterial:
			if material.shader.resource_path.ends_with("portal.gdshader"):
				material.set_shader_parameter("primary_color", color)
				material.set_shader_parameter("secondary_color", Color(color.darkened(0.8), 0.1))
				material.set_shader_parameter("emission_strength", 0.7)
			else:
				var texture: GradientTexture2D = material.get_shader_parameter("gradient_texture")
				if texture != null:
					for j in range(texture.gradient.get_point_count()):
						texture.gradient.set_color(j, Color(color, texture.gradient.get_color(j).a))


static func motion(node: Node3D, enabled: bool) -> void:
	# Shader TIME is engine-wide, so hide animated mesh effects along with particles.
	node.visible = enabled
	_set_emitting(node, enabled)


static func _set_emitting(node: Node, enabled: bool) -> void:
	if node is GPUParticles3D:
		node.emitting = enabled
	for child in node.get_children():
		_set_emitting(child, enabled)


static func play(parent: Node3D, effect: String, at: Vector3, color: Color, size: float = 1.0, duration: float = 1.1) -> Node3D:
	var node: Node3D = make(effect)
	node.position = at + Vector3.UP * 0.06
	node.scale *= size
	tint(node, color)
	parent.add_child(node)
	_start_burst(node)
	var cleanup: Tween = parent.create_tween()
	cleanup.tween_interval(duration)
	cleanup.tween_callback(node.queue_free)
	return node


static func _start_burst(node: Node) -> void:
	if node is GPUParticles3D:
		node.one_shot = true
		node.preprocess = 0.0
		node.explosiveness = 1.0
		node.restart()
	elif node is Light3D:
		var fade: Tween = node.create_tween()
		fade.tween_property(node, "light_energy", 0.0, 0.3)
	for child in node.get_children():
		_start_burst(child)
