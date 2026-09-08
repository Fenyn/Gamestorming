class_name SellBin
extends StaticBody3D
## Roadside sell bin. Wood bodies dropped (or tossed) into the SellZone
## are sold after a short delay: value scales with mass, so hauling a
## whole dragged trunk in pays the same as bucking it first. Emits
## EventBus.item_sold; GameManager turns that into money. Bodies the
## player is still holding (meta "carried") don't sell until released.

const SELL_DELAY: float = 0.7
const SCAN_INTERVAL: float = 0.25
const LOG_PRICE_PER_KG: float = 0.15
const BRANCH_PRICE_PER_KG: float = 0.075
## Processed wood pays double the raw rate: splitting is worth the work.
const FIREWOOD_PRICE_PER_KG: float = 0.3

var _pending: Dictionary[RigidBody3D, float] = {}
var _scan_accum: float = 0.0

@onready var _zone: Area3D = $SellZone


func _physics_process(delta: float) -> void:
	for body: RigidBody3D in _pending.keys():
		if not is_instance_valid(body) or not _zone.overlaps_body(body) \
				or bool(body.get_meta("carried", false)):
			_pending.erase(body)
			continue
		_pending[body] -= delta
		if _pending[body] <= 0.0:
			_pending.erase(body)
			_sell(body)

	# Poll instead of relying on body_entered alone: a body released
	# inside the zone, or one that was carried when it entered, still
	# gets picked up by the next scan.
	_scan_accum += delta
	if _scan_accum < SCAN_INTERVAL:
		return
	_scan_accum = 0.0
	for node in _zone.get_overlapping_bodies():
		var body: RigidBody3D = node as RigidBody3D
		if body == null or _pending.has(body) \
				or bool(body.get_meta("carried", false)) or _value_of(body) <= 0:
			continue
		_pending[body] = SELL_DELAY


## Sale price in whole dollars; 0 marks the body unsellable.
func _value_of(body: RigidBody3D) -> int:
	if body is Firewood:
		return maxi(1, roundi(body.mass * FIREWOOD_PRICE_PER_KG))
	if body is TrunkPiece:
		return maxi(1, roundi(body.mass * LOG_PRICE_PER_KG))
	if body is LimbDebris and not (body as LimbDebris).foliage:
		return maxi(1, roundi(body.mass * BRANCH_PRICE_PER_KG))
	return 0


func _sell(body: RigidBody3D) -> void:
	var value: int = _value_of(body)
	var product_id: String = "branch"
	if body is Firewood:
		product_id = "firewood"
	elif body is TrunkPiece:
		product_id = "log" if (body as TrunkPiece).is_log() else "timber"
	Fx.dust_puff(self, body.global_position, 0.5)
	_spawn_cash_label(body.global_position + Vector3.UP * 0.5, value)
	body.queue_free()
	EventBus.item_sold.emit(product_id, value)


## Floating "+$n" that drifts up from the sale and fades out.
func _spawn_cash_label(pos: Vector3, value: int) -> void:
	var label: Label3D = Label3D.new()
	label.text = "+$%d" % value
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56
	label.outline_size = 12
	label.pixel_size = 0.005
	label.modulate = Color(0.65, 1.0, 0.6)
	add_child(label)
	label.global_position = pos
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", pos + Vector3.UP * 0.9, 1.1) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.1) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
