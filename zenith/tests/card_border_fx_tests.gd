extends SceneTree
## Effect activation, role colors, per-card isolation, and reduced-motion behavior.

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	var scene: PackedScene = load("res://scenes/duel/card_3d.tscn")
	var card: Node3D = scene.instantiate()
	var other: Node3D = scene.instantiate()
	root.add_child(card)
	root.add_child(other)
	_check(not card.border_fx.sparks.emitting, "Idle cards must not emit particles")
	card.set_highlight(true)
	_check(card.border_fx.sparks.emitting and card.glow.visible, "Playable cards show both border and edge particles")
	card.set_role(ZenithTheme.DEFEND)
	_check(card.border_fx._material.get_shader_parameter("tint") == Color(ZenithTheme.ACCENT, 1.0), "A legal choice keeps the legal border over its fight role")
	card.set_highlight(false)
	_check(card.border_fx._material.get_shader_parameter("tint") == Color(ZenithTheme.DEFEND, 1.0), "Defender particles use the defense color")
	card.set_highlight(true)
	other.set_role(ZenithTheme.ATTACK)
	_check(card.border_fx._material != other.border_fx._material, "Cards must not share mutable particle colors")
	_check(card.border_fx._material.get_shader_parameter("tint") != other.border_fx._material.get_shader_parameter("tint"), "Attacker and defender retain distinct colors")
	card.reduced_motion = true
	_check(not card.border_fx.sparks.emitting and not card.border_fx.visible, "Reduced motion hides remaining particles immediately")
	_check(card.glow.visible and card._glow_mat.get_shader_parameter("motion") == 0.0, "Reduced motion retains a bright static border")
	card.reduced_motion = false
	_check(card.border_fx.sparks.emitting, "Motion can resume while the same card remains highlighted")
	card.set_highlight(false)
	card.set_role(Color.TRANSPARENT)
	_check(not card.border_fx.sparks.emitting, "Clearing legality and role stops the emitter")
	card.set_hovered(true)
	_check(card.border_fx.sparks.emitting, "Hover inspection works even without a legal play")
	card.set_hovered(false)
	_check(not card.border_fx.sparks.emitting, "Leaving an idle card ends hover particles")
	# The duelist's slot scales the card 2.6x, height included; the glow must stay just under the
	# face rather than sink through the mat.
	card.transform = Transform3D(Basis().scaled(Vector3.ONE * 2.4), Vector3(0, 0.01, 0))
	await process_frame
	_check(is_equal_approx(card.glow.global_position.y, 0.01 - card.GLOW_DROP), "A scaled card's legal glow stays %s under its face" % card.GLOW_DROP)
	_check(is_equal_approx(card.role.global_position.y, 0.01 - card.ROLE_DROP), "and so does its role aura")
	card.free()
	other.free()
	await process_frame
	print("Card border FX: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
