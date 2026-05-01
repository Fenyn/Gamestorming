extends Node

var tips_seen: Array[String] = []

const TIPS := {
	"first_beat": "Your heart beats and mana flows! Each beat conjures resources. The faster your heart, the faster the magic.",
	"first_generator": "Heartmotes turn your pulse into mana. Higher spells conjure the ones below them, cascading all the way down.",
	"first_surge": "The wizard feels a surge building! Raise your heart rate above the threshold to channel it into power. A little movement goes a long way.",
	"first_vitality": "You have earned Vitality! Walking and moving fills this well. It lasts one day, so spend it wisely.",
	"first_milestone": "A milestone! Open the Chronicle to see your permanent bonuses. These endure forever, even through resets.",
	"first_sanctum_bloom": "Full Resonance! Every sigil has ascended. The Sanctum resets and leaves behind a lasting enchantment.",
	"first_prestige_available": "The wizard feels something stir deep within. Open the Blessings tab to begin a Life Cycle and trade your progress for permanent power.",
	"first_prestige_complete": "A new cycle begins! Spend your Essence on Blessings to grow stronger with each turn of the wheel.",
}


func _ready() -> void:
	EventBus.heartbeat_fired.connect(_on_first_beat)
	EventBus.generator_purchased.connect(_on_first_generator)
	EventBus.surge_opportunity.connect(_on_first_surge)
	EventBus.vitality_changed.connect(_on_first_vitality)
	EventBus.plot_full_bloom.connect(_on_first_bloom)


func show_tip(tip_id: String) -> void:
	if tip_id in tips_seen:
		return
	var message: String = TIPS.get(tip_id, "")
	if message.is_empty():
		return
	tips_seen.append(tip_id)
	EventBus.notification.emit(message, "tutorial")


func _on_first_beat() -> void:
	show_tip("first_beat")
	EventBus.heartbeat_fired.disconnect(_on_first_beat)


func _on_first_generator(_tier: int, _count: float) -> void:
	show_tip("first_generator")
	EventBus.generator_purchased.disconnect(_on_first_generator)


func _on_first_surge(_surge_id: String) -> void:
	show_tip("first_surge")
	EventBus.surge_opportunity.disconnect(_on_first_surge)


func _on_first_vitality(_amount: float) -> void:
	show_tip("first_vitality")
	EventBus.vitality_changed.disconnect(_on_first_vitality)


func _on_first_bloom(_plot_id: String, _bloom_count: int) -> void:
	show_tip("first_sanctum_bloom")
	EventBus.plot_full_bloom.disconnect(_on_first_bloom)




func reset_to_defaults() -> void:
	tips_seen.clear()


func to_dict() -> Dictionary:
	return {"tips_seen": tips_seen.duplicate()}


func from_dict(data: Dictionary) -> void:
	tips_seen.clear()
	var saved: Array = data.get("tips_seen", [])
	for tip_id in saved:
		tips_seen.append(str(tip_id))
	_disconnect_seen_tips()


func _disconnect_seen_tips() -> void:
	if "first_beat" in tips_seen and EventBus.heartbeat_fired.is_connected(_on_first_beat):
		EventBus.heartbeat_fired.disconnect(_on_first_beat)
	if "first_generator" in tips_seen and EventBus.generator_purchased.is_connected(_on_first_generator):
		EventBus.generator_purchased.disconnect(_on_first_generator)
	if "first_surge" in tips_seen and EventBus.surge_opportunity.is_connected(_on_first_surge):
		EventBus.surge_opportunity.disconnect(_on_first_surge)
	if "first_vitality" in tips_seen and EventBus.vitality_changed.is_connected(_on_first_vitality):
		EventBus.vitality_changed.disconnect(_on_first_vitality)
	if "first_sanctum_bloom" in tips_seen and EventBus.plot_full_bloom.is_connected(_on_first_bloom):
		EventBus.plot_full_bloom.disconnect(_on_first_bloom)
