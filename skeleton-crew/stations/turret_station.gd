class_name TurretStation
extends Station

func _ready() -> void:
	super._ready()
	station_id = "turret"
	station_type = InputContext.Mode.TURRET
