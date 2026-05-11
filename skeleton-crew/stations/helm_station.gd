class_name HelmStation
extends Station

func _ready() -> void:
	super._ready()
	station_id = "helm"
	station_type = InputContext.Mode.HELM
