extends Resource
class_name MetalDefinition

const METAL_COLORS: Dictionary = {
	"iron": Color(0.6, 0.4, 0.3),
	"steel": Color(0.7, 0.75, 0.8),
	"gold": Color(1.0, 0.85, 0.2),
}

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

static func get_color(metal_id: String) -> Color:
	return METAL_COLORS.get(metal_id, Color(0.8, 0.6, 0.3))
