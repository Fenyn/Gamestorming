class_name LimbDebris
extends RigidBody3D
## A limb snapped off a felled trunk. Chopping foliage debris destroys
## it (clearing the big green tiers out of the way); wood stub debris
## is a keepable prop and just takes a knock.

var foliage: bool = false
var burst_radius: float = 0.5
## Local direction of the branch's long axis, from the mesh AABB.
## CarrySystem holds the piece lying along this.
var carry_axis_local: Vector3 = Vector3.UP


func _ready() -> void:
	# Wood stubs are haulable props; foliage exists only to be cleared.
	if not foliage:
		add_to_group("carryable")
	# Debris layer: rests on the world and other debris, never blocks
	# the player's capsule underfoot.
	collision_layer = 0b100
	collision_mask = 0b101
	# Light sticks otherwise spin and skate forever: ground them with
	# damping and a grippy, dead material.
	angular_damp = 3.0
	linear_damp = 0.2
	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = 1.0
	mat.bounce = 0.0
	physics_material_override = mat


func carry_axis() -> Vector3:
	return carry_axis_local


func receive_chop(_damage: float, point: Vector3, normal: Vector3) -> void:
	if foliage:
		Fx.needle_burst(self, global_position, burst_radius)
		queue_free()
	else:
		apply_impulse(-normal * 6.0, point - global_position)
