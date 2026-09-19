extends "res://scripts/duel/duel_view.gd"
## Loaded after autoload initialization; no table rendering is required.

class QuietHud extends DuelHud:
	var sending: int = 0
	func clear_prompt() -> void:
		pass
	func refresh_state(_view: SeatView, _viewer: int, _live: Dictionary = {}) -> void:
		pass
	func show_sending() -> void:
		sending += 1

signal release_animation
var played: Array[int] = []
var presented: int = 0

func _init() -> void:
	hud = QuietHud.new()

func _clear_highlights() -> void:
	pass

func _present_prompt() -> void:
	presented += 1
	_drain_inbox()

func _play_update(update: SeatUpdate) -> void:
	played.append(int(update.lines[0]["id"]))
	await release_animation
	view = update.view
	prompt = update.prompt

func _apply(_seat: int, wire: Dictionary) -> void:
	busy = true
	played.append(int(wire["id"]))
	await release_animation
	busy = false
	_present_prompt()
