class_name ShipDiagram
extends Control

@onready var _cockpit_rect: ColorRect = $CockpitRect
@onready var _weapons_rect: ColorRect = $WeaponsRect
@onready var _reactor_rect: ColorRect = $ReactorRect

const COLOR_OK: Color = Color(0.2, 0.7, 0.2)
const COLOR_DAMAGED: Color = Color(0.9, 0.7, 0.1)
const COLOR_CRITICAL: Color = Color(0.9, 0.15, 0.1)
const COLOR_NO_POWER: Color = Color(0.3, 0.3, 0.3)
const COLOR_LOW_O2: Color = Color(0.3, 0.5, 0.8)


func set_room_status(room_id: String, color: Color) -> void:
	match room_id:
		"Cockpit":
			_cockpit_rect.color = color
		"WeaponsBay":
			_weapons_rect.color = color
		"ReactorRoom":
			_reactor_rect.color = color
