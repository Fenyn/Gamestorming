class_name LimbHitbox
extends Area3D
## Aim-only hitbox for a limb still attached to a FelledTree. The box
## matches the limb mesh's AABB, so chops land where the branch looks
## like it is; it takes no part in physics. Freed together with its
## limb.

var tree: FelledTree = null
var limb: MeshInstance3D = null


func receive_chop(_damage: float, point: Vector3, normal: Vector3) -> void:
	if tree != null and is_instance_valid(tree):
		tree.chop_limb(limb, point, normal)
