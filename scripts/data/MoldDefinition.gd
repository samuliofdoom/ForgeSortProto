extends Resource
class_name MoldDefinition

var id: String
var part_type: String
var required_metal: String
var fill_amount: float

func _init(p_id: String, p_part_type: String, p_required_metal: String, p_fill_amount: float):
	id = p_id
	part_type = p_part_type
	required_metal = p_required_metal
	fill_amount = p_fill_amount
