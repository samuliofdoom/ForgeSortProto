extends Resource
class_name OrderDefinition

var id: String
var name: String
var parts: Array[String]
var base_value: int

func _init(p_id: String, p_name: String, p_parts: Array[String], p_base_value: int):
	id = p_id
	name = p_name
	parts = p_parts
	base_value = p_base_value
