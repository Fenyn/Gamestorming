class_name MinigameLayer
extends CanvasLayer

signal minigame_resolved(hit: bool)

@onready var _dimmer: ColorRect = %Dimmer
@onready var _wobble: WobbleMinigame = %WobbleMinigame
@onready var _timing: TimingMinigame = %TimingMinigame

var _active_minigame: BaseMinigame = null


func open(minigame_type: WeaponData.MinigameType) -> void:
	_dimmer.visible = true
	match minigame_type:
		WeaponData.MinigameType.WOBBLE:
			_active_minigame = _wobble
		WeaponData.MinigameType.TIMING:
			_active_minigame = _timing
	if _active_minigame:
		_active_minigame.resolved.connect(_on_resolved, CONNECT_ONE_SHOT)
		_active_minigame.start()


func _on_resolved(hit: bool) -> void:
	_dimmer.visible = false
	_active_minigame = null
	minigame_resolved.emit(hit)
