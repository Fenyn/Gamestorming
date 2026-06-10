extends Node

# Ship damage
signal player_hull_face_changed(face: int, current: int, max_val: int)
signal player_shield_changed(current: float, max_val: float)
signal enemy_hull_changed(current: int, max_val: int)
signal enemy_shield_changed(current: float, max_val: float)
signal hull_breached(face: int, room_id: String)

# Power
signal power_changed(weapons: int, shields: int, engines: int)

# Stations
signal station_occupied(station_id: String, peer_id: int)
signal station_vacated(station_id: String)

# Combat events
signal weapon_fired(position: Vector3, direction: Vector3, is_player: bool)
signal ship_damaged(position: Vector3, amount: int)

# Atmosphere
signal room_o2_changed(room_id: String, level: float)

# Player
signal player_health_changed(peer_id: int, current: int, max_val: int)
signal player_downed(peer_id: int)
signal player_room_changed(peer_id: int, room_id: String)

# Connection
signal player_connected(peer_id: int, info: Dictionary)
signal player_disconnected(peer_id: int)
signal all_players_ready()

# Game flow
signal game_started()
signal game_over(won: bool)
