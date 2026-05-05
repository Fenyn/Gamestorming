@tool
extends SceneTree

func _init() -> void:
	var dir_path: String = "res://kenney_marble-kit/Models/GLB format/"
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		print("ERROR: Could not open directory: ", dir_path)
		quit()
		return

	var key_pieces: Array[String] = [
		"straight.glb",
		"straight-wide.glb",
		"curve.glb",
		"curve-large.glb",
		"curve-wide.glb",
		"bend.glb",
		"bend-large.glb",
		"bend-medium.glb",
		"split.glb",
		"split-left.glb",
		"split-right.glb",
		"split-double.glb",
		"slant-a.glb",
		"slant-b.glb",
		"slant-long-a.glb",
		"s-curve-left.glb",
		"s-curve-right.glb",
		"s-curve-left-large.glb",
		"wave-a.glb",
		"wave-b.glb",
		"helix-half-left.glb",
		"helix-half-right.glb",
		"helix-quarter-left.glb",
		"helix-left.glb",
		"tunnel.glb",
		"funnel.glb",
		"corner.glb",
		"cross.glb",
		"bump-a.glb",
		"end-rounded.glb",
		"end-square.glb",
		"end-hole-rounded.glb",
		"ramp-start-a.glb",
		"ramp-end-a.glb",
		"ramp-long-a.glb",
		"support-single-top.glb",
		"support-single-middle.glb",
		"support-single-bottom.glb",
	]

	print("=== Marble Kit Piece Dimensions ===")
	print("")

	for filename: String in key_pieces:
		var path: String = dir_path + filename
		if not ResourceLoader.exists(path):
			print("SKIP: ", filename, " (not found)")
			continue

		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			print("SKIP: ", filename, " (could not load)")
			continue

		var instance: Node3D = scene.instantiate() as Node3D
		if instance == null:
			print("SKIP: ", filename, " (not Node3D)")
			continue

		var aabb: AABB = _get_combined_aabb(instance)
		print("%s:" % filename)
		print("  size: (%.3f, %.3f, %.3f)" % [aabb.size.x, aabb.size.y, aabb.size.z])
		print("  pos:  (%.3f, %.3f, %.3f)" % [aabb.position.x, aabb.position.y, aabb.position.z])
		print("  end:  (%.3f, %.3f, %.3f)" % [aabb.end.x, aabb.end.y, aabb.end.z])
		print("")

		instance.queue_free()

	print("=== Done ===")
	quit()

func _get_combined_aabb(node: Node3D) -> AABB:
	var result: AABB = AABB()
	var first: bool = true

	for child: Node in node.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			var mesh_aabb: AABB = mi.get_aabb()
			mesh_aabb.position += mi.position
			if first:
				result = mesh_aabb
				first = false
			else:
				result = result.merge(mesh_aabb)

		if child is Node3D:
			var child_aabb: AABB = _get_combined_aabb(child as Node3D)
			if child_aabb.size != Vector3.ZERO:
				if first:
					result = child_aabb
					first = false
				else:
					result = result.merge(child_aabb)

	return result
