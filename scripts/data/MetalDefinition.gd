extends Resource
class_name MetalDefinition

var id: String
var name: String
var spread: float
var speed: float
var waste_penalty: int

func _init(p_id: String, p_name: String, p_spread: float, p_speed: float, p_waste_penalty: int):
	id = p_id
	name = p_name
	spread = p_spread
	speed = p_speed
	waste_penalty = p_waste_penalty
