class_name SocketRequirement
extends Resource

enum Type { ANY, SPECIFIC, RANGE, PARITY, MATCH, SEQUENCE, SUM }

@export var type: Type = Type.ANY

@export_group("Specific")
@export var specific_value: int = 0

@export_group("Range")
@export var range_min: int = 1
@export var range_max: int = 6

@export_group("Parity")
@export var parity_even: bool = true

@export_group("Match")
@export var match_socket_index: int = 0

@export_group("Sequence")
@export var sequence_ref_index: int = 0
@export var sequence_offset: int = 1

@export_group("Sum")
@export var sum_target: int = 0
