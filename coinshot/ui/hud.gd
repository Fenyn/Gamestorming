extends Control

@onready var crosshair: Control = $Crosshair
@onready var debug_label: Label = $DebugPanel/DebugLabel
var _allomancy: Allomancy
var _player: Player
var _mist: MistVision

func _ready() -> void:
	_player = get_parent() as Player
	_allomancy = _player.get_node("Allomancy") as Allomancy
	_mist = _player.get_node("Camera3D/MistVision") as MistVision

func _process(_delta: float) -> void:
	if _allomancy == null or _player == null:
		return

	var has_target := _allomancy.current_target != null
	crosshair.modulate = Color(0.5, 0.85, 1.0, 1.0) if has_target else Color(1, 1, 1, 0.6)

	var force_n: float = _allomancy.last_effective_force
	var locked := _allomancy.locked_count()
	var action := "—"
	if Input.is_action_pressed("push"):
		action = "PUSH x%d" % locked if locked > 1 else "PUSH"
	elif Input.is_action_pressed("pull"):
		action = "PULL x%d" % locked if locked > 1 else "PULL"

	var target_line := "target: —"
	if has_target:
		var t: Node = _allomancy.current_target
		var t_name: String = t.name
		var t_mass: float = Allomancy.get_anchor_mass(t)
		var t_anchored: bool = Allomancy.is_world_anchored(t)
		var t_dist: float = (t as Node3D).global_position.distance_to(_player.global_position)
		var anchor_tag := "anchored" if t_anchored else "loose"
		target_line = "target: %s  [%s, %.1f kg, %.1f m]" % [t_name, anchor_tag, t_mass, t_dist]

	var v: Vector3 = _player.velocity
	var v_h: float = Vector2(v.x, v.z).length()

	var mist_state: String = "ON" if (_mist != null and _mist.overlay_on) else "OFF"

	debug_label.text = "fps    %d\nburn   %.2fx  (force %.0f N)\n%s\naction %s\nvel    %.1f m/s  (h %.1f, v %.1f)\ncoins  %d / %d\nanchors in range  %d\nmist-vision  %s  (Tab)\nrespawn  R" % [
		Engine.get_frames_per_second(),
		_allomancy.burn_intensity,
		force_n,
		target_line,
		action,
		v.length(),
		v_h,
		v.y,
		_player.coin_count(),
		Player.MAX_COINS,
		_allomancy.nearby_anchors.size(),
		mist_state,
	]
