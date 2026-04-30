extends Resource
class_name OrderDefinition

var id: String
var name: String
var parts: Array  # Array[String] — untyped in .tscn so runtime must accept plain Array
var part_requests: Dictionary  # part_type (blade/guard/grip) -> required_metal (iron/steel/gold)
var base_value: int

func _init(p_id: String, p_name: String, p_parts: Array, p_part_requests: Dictionary, p_base_value: int):
	id = p_id
	name = p_name
	parts = p_parts
	part_requests = p_part_requests
	base_value = p_base_value
