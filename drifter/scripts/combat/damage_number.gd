class_name DamageNumber
extends Label

enum Type { DAMAGE, HEAL, SHIELD }

const RISE_DISTANCE: float = 40.0
const DURATION: float = 0.9


func setup(value: int, type: Type) -> void:
	match type:
		Type.DAMAGE:
			text = str(value)
			add_theme_color_override("font_color", ThemeBuilder.TEXT_DAMAGE)
		Type.HEAL:
			text = "+" + str(value)
			add_theme_color_override("font_color", ThemeBuilder.TEXT_HEAL)
		Type.SHIELD:
			text = "+" + str(value)
			add_theme_color_override("font_color", ThemeBuilder.TEXT_SHIELD)

	var font_size: int = 22 if value >= 10 else 18
	add_theme_font_size_override("font_size", font_size)
	modulate.a = 1.0


func _ready() -> void:
	var start_y: float = position.y
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", start_y - RISE_DISTANCE, DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, DURATION * 0.4).set_delay(DURATION * 0.6)
	tween.chain().tween_callback(queue_free)
