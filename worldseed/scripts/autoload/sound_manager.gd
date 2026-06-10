extends Node

const SFX_PATHS := {
	"item_pickup": "res://audio/sfx/item_pickup.ogg",
	"item_place": "res://audio/sfx/item_place.ogg",
	"plant_seed": "res://audio/sfx/plant_seed.ogg",
	"water_pour": "res://audio/sfx/water_pour.ogg",
	"pollinate": "res://audio/sfx/pollinate.ogg",
	"harvest": "res://audio/sfx/harvest.ogg",
	"deliver": "res://audio/sfx/deliver.ogg",
	"bloom": "res://audio/sfx/bloom.ogg",
	"bee_buzz": "res://audio/sfx/bee_buzz.ogg",
	"bee_assign": "res://audio/sfx/bee_assign.ogg",
	"milestone": "res://audio/sfx/milestone.ogg",
	"o2_warning": "res://audio/sfx/o2_warning.ogg",
	"o2_refill": "res://audio/sfx/o2_refill.ogg",
	"death": "res://audio/sfx/death.ogg",
	"build_place": "res://audio/sfx/build_place.ogg",
	"build_complete": "res://audio/sfx/build_complete.ogg",
	"power_on": "res://audio/sfx/power_on.ogg",
	"brownout": "res://audio/sfx/brownout.ogg",
	"win": "res://audio/sfx/win.ogg",
	"ambient_hum": "res://audio/sfx/ambient_hum.ogg",
}

var _sfx: SfxPool


func _ready() -> void:
	_sfx = SfxPool.new()
	add_child(_sfx)


func play(sound_name: String, volume_db: float = 0.0) -> void:
	var path: String = _resolve_path(sound_name)
	if not path.is_empty():
		_sfx.play(path, volume_db)


func play_loop(sound_name: String, volume_db: float = 0.0) -> void:
	var path: String = _resolve_path(sound_name)
	if not path.is_empty():
		_sfx.play_loop(sound_name, path, volume_db)


func stop_loop(sound_name: String) -> void:
	_sfx.stop_loop(sound_name)


func stop_all_loops() -> void:
	_sfx.stop_all_loops()


# Missing/unknown sounds resolve to "" and are skipped silently
# (SfxPool itself warns on missing paths).
func _resolve_path(sound_name: String) -> String:
	var path: String = SFX_PATHS.get(sound_name, "") as String
	if path.is_empty() or not ResourceLoader.exists(path):
		return ""
	return path
