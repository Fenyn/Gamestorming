extends Node
class_name GameManager

var spark_manager: SparkManager

func _ready() -> void:
	spark_manager = SparkManager.new()
	add_child(spark_manager)

func on_orb_spawned(orb: Orb) -> void:
	orb.orb_consumed.connect(_on_orb_consumed)

func _on_orb_consumed(orb: Orb, _total_distance: float) -> void:
	spark_manager.earn(orb.get_sparks())
