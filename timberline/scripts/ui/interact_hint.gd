extends Label
## HUD hint line above the hotbar area. Anything may publish via
## EventBus.interact_hint_changed; empty text hides it.


func _ready() -> void:
	text = ""
	EventBus.interact_hint_changed.connect(_on_hint_changed)


func _on_hint_changed(new_text: String) -> void:
	text = new_text
