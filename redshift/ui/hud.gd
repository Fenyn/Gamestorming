extends CanvasLayer

@onready var _countdown_label: Label = %CountdownLabel
@onready var _pip_rect: TextureRect = %PIPRect


func _ready() -> void:
	EventBus.race_countdown_tick.connect(_on_countdown_tick)
	EventBus.race_started.connect(_on_race_started)
	_countdown_label.visible = false


func _on_countdown_tick(seconds_left: int) -> void:
	_countdown_label.visible = true
	_countdown_label.modulate.a = 1.0
	_countdown_label.text = str(seconds_left)


func _on_race_started() -> void:
	_countdown_label.text = "GO"
	var tween: Tween = create_tween()
	tween.tween_property(_countdown_label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(_countdown_label.set_visible.bind(false))


func set_pip_texture(texture: ViewportTexture) -> void:
	_pip_rect.texture = texture


func set_best_time(time: float) -> void:
	var panel: RaceEndPanel = $RaceEndPanel as RaceEndPanel
	if panel:
		panel.set_best_time(time)
