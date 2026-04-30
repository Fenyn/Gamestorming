extends Node

signal order_submitted(order_data: Dictionary)
signal ticket_printed(order_data: Dictionary)
signal drink_completed(order_data: Dictionary, quality: float)
signal drink_handed_off(order_data: Dictionary, earned: float)
signal customer_arrived(customer: Node3D)
signal customer_left(customer: Node3D, reason: String)
signal day_started()
signal day_ended()
signal mini_game_started(station_name: String)
signal mini_game_ended(station_name: String, quality: float)
