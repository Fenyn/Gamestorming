extends Node3D
class_name PortalManager

signal orb_spawned(orb: Orb)

@export var orb_scene: PackedScene

var portals: Array[DreamerPortal] = []
var _prestige_manager: PrestigeManager
var _build_radius: float = 8.0

func bind_prestige(pm: PrestigeManager) -> void:
	_prestige_manager = pm
	_build_radius = pm.get_build_radius()
	pm.build_space_changed.connect(func(r: float) -> void: _build_radius = r)

func spawn_portals_for_cycle() -> void:
	clear_portals()

	var available_types: Array[DreamerPortal.PortalType] = _get_available_types()
	var count: int = _get_portal_count()

	for i: int in count:
		var type: DreamerPortal.PortalType = available_types[i % available_types.size()]
		var portal: DreamerPortal = DreamerPortal.new()
		portal.portal_type = type
		portal.orb_scene = orb_scene
		add_child(portal)
		portal.global_position = _random_portal_position(i, count)
		portal.orb_spawned.connect(func(orb: Orb) -> void: orb_spawned.emit(orb))
		portals.append(portal)

func clear_portals() -> void:
	for portal: DreamerPortal in portals:
		portal.queue_free()
	portals.clear()

func connect_portal(portal: DreamerPortal) -> void:
	portal.connect_to_track()

func get_unconnected_portals() -> Array[DreamerPortal]:
	return portals.filter(
		func(p: DreamerPortal) -> bool: return not p.connected
	)

func _get_available_types() -> Array[DreamerPortal.PortalType]:
	var types: Array[DreamerPortal.PortalType] = [DreamerPortal.PortalType.SHALLOW]

	if _prestige_manager == null:
		return types

	var type_unlocks: Dictionary = {
		"portal_deep": DreamerPortal.PortalType.DEEP,
		"portal_nightmare": DreamerPortal.PortalType.NIGHTMARE,
		"portal_gilt": DreamerPortal.PortalType.GILT,
		"portal_void": DreamerPortal.PortalType.VOID,
	}

	for unlock_id: String in type_unlocks:
		if _prestige_manager.is_category_unlocked(unlock_id):
			types.append(type_unlocks[unlock_id] as DreamerPortal.PortalType)

	return types

func _get_portal_count() -> int:
	if _prestige_manager == null:
		return 2
	return mini(2 + _prestige_manager.cycle / 3, 6)

func _random_portal_position(index: int, total: int) -> Vector3:
	var angle: float = (TAU / total) * index + randf() * 0.5
	var dist: float = _build_radius * 0.4 + randf() * _build_radius * 0.3
	var height: float = 2.0 + randf() * 3.0
	return Vector3(cos(angle) * dist, height, sin(angle) * dist)
