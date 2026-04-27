extends Node

signal metal_poured(metal_id: String, world_position: Vector2, amount: float)

var active_pour_zone: Node = null
var metal_source: Node
var game_data: Node
var flow_controller: Node
var molds: Dictionary = {}

var pour_accumulator: float = 0.0
const POUR_AMOUNT_PER_SECOND: float = 50.0

func _ready():
	metal_source = get_node("/root/MetalSource")
	game_data = get_node("/root/GameData")
	flow_controller = get_node("/root/FlowController")

func _process(delta):
	if active_pour_zone and active_pour_zone.is_pouring:
		pour_accumulator += POUR_AMOUNT_PER_SECOND * delta

		while pour_accumulator >= 1.0:
			var amount = floor(pour_accumulator)
			pour_accumulator -= amount
			_route_pour(metal_source.get_selected_metal(), active_pour_zone.pour_origin, amount)

func set_active_stream(stream: Node):
	active_pour_zone = stream

func register_mold(mold_id: String, mold: Node):
	molds[mold_id] = mold
	if flow_controller:
		flow_controller.register_mold(mold_id, mold)

func _route_pour(metal_id: String, pour_pos: Vector2, amount: float):
	var intake_id = _get_intake_for_position(pour_pos)
	if intake_id != "":
		var target_mold = flow_controller.get_mold_for_intake(intake_id) if flow_controller else ""
		if target_mold != "":
			flow_controller.route_metal_to_mold(target_mold, metal_id, amount)
		else:
			_route_fallback(metal_id, pour_pos, amount)
	else:
		_route_fallback(metal_id, pour_pos, amount)

func _get_intake_for_position(pour_pos: Vector2) -> String:
	var mold_area = get_node_or_null("/root/Main/MoldArea")
	if not mold_area:
		return ""

	var mold_center_x = mold_area.global_position.x
	var offset_x = pour_pos.x - mold_center_x

	if offset_x < -60:
		return "intake_a"
	elif offset_x < 60:
		return "intake_b"
	else:
		return "intake_c"

func _route_fallback(metal_id: String, pour_pos: Vector2, amount: float):
	var nearest_mold_id = ""
	var nearest_dist = INF

	for mold_id in molds.keys():
		if molds[mold_id]:
			var dist = pour_pos.distance_to(molds[mold_id].global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_mold_id = mold_id

	if nearest_mold_id and molds[nearest_mold_id]:
		molds[nearest_mold_id].receive_metal(metal_id, amount)
