class_name Allomancy
extends Node

# Tunable constants — keep here for easy iteration.
const SEARCH_RADIUS := 30.0
const MAX_ANCHORS := 32
const BASE_FORCE := 1500.0
const PULL_MULTIPLIER := 1.75
const BURN_MIN := 0.25
const BURN_MAX := 3.0
const BURN_STEP := 0.15
const FOV_PAD_DEG := 10.0
const TARGET_CONE_COS := 0.94  # ~20 deg half-angle for fallback aim assist
const PLAYER_MASS := 40.0
const TERMINAL_SPEED := 30.0
# Distance falloff: force is full at FALLOFF_REF_DIST and closer,
# then decays as ref²/(ref²+dist²). At 2×ref force is 20%, at 3×ref ~10%.
const FALLOFF_REF_DIST := 8.0
# Safety cap on loose targets (coins, light cans) — a 3x burn push on a 0.5 kg
# coin would otherwise produce ~190 m/s per frame, which feels like a railgun
# rather than a coin shot. Caps at fast-bullet speed.
const LOOSE_TARGET_SPEED_CAP := 80.0
const MIN_VIABLE_FORCE := 300.0
const PULL_APPROACH_DIST := 4.0
const PULL_APPROACH_DECEL := 35.0
const INTENT_OPPOSING_DAMP := 0.15
const MAX_LOCKED_TARGETS := 8

@export var burn_intensity: float = 1.0

var nearby_anchors: Array = []          # Nodes in group "metal" within range and roughly in FOV.
var current_target: Node = null         # The primary (most recent) target for HUD display.
var _locked_targets: Array = []         # All targets held while push/pull key is down.
var _is_locked: bool = false
var last_effective_force: float = 0.0   # Total force applied last tick (with falloff).

@onready var player: CharacterBody3D = get_parent()
@onready var camera: Camera3D = player.get_node("Camera3D")
@onready var aim_ray: RayCast3D = camera.get_node("AimRay")

func _process(_delta: float) -> void:
	_refresh_nearby_anchors()
	if _is_locked:
		var origin := player.global_position
		_locked_targets = _locked_targets.filter(func(t):
			if not is_instance_valid(t) or not t.is_inside_tree():
				return false
			return (t as Node3D).global_position.distance_to(origin) <= SEARCH_RADIUS
		)
		if _locked_targets.is_empty():
			unlock_target()
			current_target = null
		else:
			var aimed := _pick_target()
			if aimed != null and aimed not in _locked_targets and _locked_targets.size() < MAX_LOCKED_TARGETS:
				_locked_targets.append(aimed)
			current_target = aimed if aimed != null else _locked_targets.back()
	else:
		current_target = null

func lock_target() -> void:
	var target := _pick_target()
	if target != null and target not in _locked_targets:
		_locked_targets.append(target)
	_is_locked = true

func unlock_target() -> void:
	_locked_targets.clear()
	_is_locked = false

func locked_count() -> int:
	return _locked_targets.size()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("burn_up"):
		burn_intensity = clampf(burn_intensity + BURN_STEP, BURN_MIN, BURN_MAX)
	elif event.is_action_pressed("burn_down"):
		burn_intensity = clampf(burn_intensity - BURN_STEP, BURN_MIN, BURN_MAX)

# Apply impulses for all locked targets each physics tick.
func apply_push_pull(delta: float, push_pressed: bool, pull_pressed: bool) -> void:
	var targets: Array = []
	if _is_locked and not _locked_targets.is_empty():
		targets = _locked_targets.filter(func(t): return is_instance_valid(t) and t.is_inside_tree())
	elif current_target != null:
		targets = [current_target]

	if targets.is_empty():
		last_effective_force = 0.0
		return
	if not (push_pressed or pull_pressed):
		last_effective_force = 0.0
		return

	var sign_player := -1.0 if push_pressed else 1.0
	var sign_anchor := 1.0 if push_pressed else -1.0
	var pull_scale: float = PULL_MULTIPLIER if pull_pressed else 1.0

	var total_player_dv := Vector3.ZERO
	var total_force := 0.0
	var nearest_pull_dist := INF

	for target in targets:
		if not is_instance_valid(target) or not target.is_inside_tree():
			continue

		var target_pos := _node_position(target)
		var to_target: Vector3 = target_pos - player.global_position
		if to_target.length_squared() < 0.0001:
			continue
		var dir: Vector3 = to_target.normalized()
		var dist: float = to_target.length()

		var ref2: float = FALLOFF_REF_DIST * FALLOFF_REF_DIST
		var falloff: float = ref2 / (ref2 + dist * dist)
		var force_n: float = BASE_FORCE * burn_intensity * falloff * pull_scale

		var anchored: bool = is_world_anchored(target)

		if target.has_method("on_allomantic_force"):
			target.call("on_allomantic_force")

		var player_force: float = force_n
		var target_force: float = force_n
		if not anchored:
			var target_mass: float = get_anchor_mass(target)
			var total_mass: float = PLAYER_MASS + target_mass
			player_force = force_n * (target_mass / total_mass)
			target_force = force_n * (PLAYER_MASS / total_mass)

		var push_dir: Vector3 = dir * sign_player
		var speed_along: float = player.velocity.dot(push_dir)
		if speed_along > 0.0:
			var ratio: float = clampf(speed_along / TERMINAL_SPEED, 0.0, 1.0)
			player_force *= (1.0 - ratio * ratio)

		total_force += player_force
		total_player_dv += push_dir * (player_force / PLAYER_MASS) * delta

		if not anchored and target is RigidBody3D:
			var rb: RigidBody3D = target
			var impulse: Vector3 = dir * sign_anchor * target_force * delta
			rb.apply_central_impulse(impulse)
			if rb.linear_velocity.length() > LOOSE_TARGET_SPEED_CAP:
				rb.linear_velocity = rb.linear_velocity.normalized() * LOOSE_TARGET_SPEED_CAP

		if pull_pressed and dist < nearest_pull_dist:
			nearest_pull_dist = dist

	last_effective_force = total_force

	# Intent dampening on the combined force
	var ix := Input.get_axis("move_left", "move_right")
	var iz := Input.get_axis("move_forward", "move_back")
	var wish_local := Vector3(ix, 0.0, iz)
	if wish_local.length_squared() > 0.001:
		var wish_world := (player.transform.basis * wish_local.normalized())
		wish_world.y = 0.0
		if wish_world.length_squared() > 0.001:
			wish_world = wish_world.normalized()
			var dv_against := total_player_dv.dot(wish_world)
			if dv_against < 0.0:
				total_player_dv -= wish_world * dv_against * (1.0 - INTENT_OPPOSING_DAMP)

	player.velocity += total_player_dv

	# Pull approach deceleration — use nearest pull target
	if pull_pressed and nearest_pull_dist < PULL_APPROACH_DIST:
		var approach := 1.0 - nearest_pull_dist / PULL_APPROACH_DIST
		var damp_rate := PULL_APPROACH_DECEL * approach
		var speed := player.velocity.length()
		if speed > 0.0:
			var new_speed := maxf(0.0, speed - damp_rate * delta)
			player.velocity *= new_speed / speed

func _refresh_nearby_anchors() -> void:
	nearby_anchors.clear()
	var origin := player.global_position
	var cam_basis := camera.global_transform.basis
	var forward: Vector3 = -cam_basis.z
	var fov_rad: float = deg_to_rad(camera.fov + FOV_PAD_DEG)
	var cos_half_fov: float = cos(fov_rad * 0.5)

	var candidates: Array = get_tree().get_nodes_in_group("metal")
	# Score: distance — keep closest MAX_ANCHORS that are within FOV.
	var scored: Array = []
	for n in candidates:
		if n == null or not (n is Node3D):
			continue
		var pos: Vector3 = (n as Node3D).global_position
		var d_vec: Vector3 = pos - origin
		var dist: float = d_vec.length()
		if dist > SEARCH_RADIUS or dist < 0.001:
			continue
		var dot_fwd: float = d_vec.normalized().dot(forward)
		if dot_fwd < cos_half_fov:
			continue
		var ref2: float = FALLOFF_REF_DIST * FALLOFF_REF_DIST
		var falloff: float = ref2 / (ref2 + dist * dist)
		var force: float = BASE_FORCE * burn_intensity * falloff
		if not is_world_anchored(n):
			var t_mass: float = get_anchor_mass(n)
			force *= t_mass / (PLAYER_MASS + t_mass)
		if force < MIN_VIABLE_FORCE:
			continue
		scored.append({"node": n, "dist": dist})
	scored.sort_custom(func(a, b): return a["dist"] < b["dist"])
	var limit: int = min(MAX_ANCHORS, scored.size())
	for i in range(limit):
		nearby_anchors.append(scored[i]["node"])

func _pick_target() -> Node:
	# 1. Whatever the aim ray hits, if it's metal.
	if aim_ray.is_colliding():
		var hit: Object = aim_ray.get_collider()
		if hit and hit is Node and (hit as Node).is_in_group("metal"):
			return hit
	# 2. Recently spawned coin (auto-target assist).
	var origin := camera.global_position
	var cam_basis := camera.global_transform.basis
	var forward: Vector3 = -cam_basis.z
	var best: Node = null
	var best_dot: float = TARGET_CONE_COS
	for n in nearby_anchors:
		if n is Coin and (n as Coin).age_seconds() < 1.0:
			var d: Vector3 = ((n as Node3D).global_position - origin).normalized()
			var dot_v: float = d.dot(forward)
			if dot_v > best_dot:
				best_dot = dot_v
				best = n
	if best:
		return best
	# 3. Fallback: nearest anchor inside a tight forward cone.
	best_dot = TARGET_CONE_COS
	for n in nearby_anchors:
		var d2: Vector3 = ((n as Node3D).global_position - origin).normalized()
		var dot_v2: float = d2.dot(forward)
		if dot_v2 > best_dot:
			best_dot = dot_v2
			best = n
	return best

static func _node_position(n: Node) -> Vector3:
	return (n as Node3D).global_position

static func is_world_anchored(n: Node) -> bool:
	if n is RigidBody3D:
		return (n as RigidBody3D).freeze
	# Look for a MetalAnchor child marking the static prop's metadata.
	for child in n.get_children():
		if child is MetalAnchor:
			return (child as MetalAnchor).is_anchored
	# Static collider with no anchor component — treat as world-anchored.
	return true

static func get_anchor_mass(n: Node) -> float:
	if n is RigidBody3D:
		return (n as RigidBody3D).mass
	for child in n.get_children():
		if child is MetalAnchor:
			return (child as MetalAnchor).mass_kg
	return 1000.0
