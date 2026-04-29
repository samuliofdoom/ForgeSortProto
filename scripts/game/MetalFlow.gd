extends Node

signal metal_poured(metal_id: String, world_position: Vector2, amount: float)
signal waste_routed(metal_id: String, world_position: Vector2, amount: float)
signal pour_routing_decided(world_position: Vector2, mold_id: String)  # emitted when routing target is resolved

var active_pour_zone: Node = null
var metal_source: Node
var flow_controller: Node
var score_manager: Node
var molds: Dictionary = {}

var pour_accumulator: float = 0.0
var _last_pour_metal: String = ""
const BASE_POUR_AMOUNT_PER_SECOND: float = 50.0

func _ready():
	metal_source = get_node("/root/MetalSource")
	flow_controller = get_node("/root/FlowController")
	score_manager = get_node("/root/ScoreManager")

func _process(delta):
	if active_pour_zone and active_pour_zone.is_pouring:
		var metal_def = metal_source.get_selected_metal_data() if metal_source else null
		var speed_mult = metal_def.speed if metal_def else 1.0
		var pour_rate = BASE_POUR_AMOUNT_PER_SECOND * speed_mult
		pour_accumulator += pour_rate * delta

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

# No-op placeholder — remove when a real metal_poured handler is added.

# Called by PourZone when a gate toggles mid-pour — flush any accumulated metal
# via fallback routing before the pour is stopped, so no metal is silently lost.
func flush_accumulator(metal_id: String, pour_origin: Vector2):
	if pour_accumulator >= 1.0:
		var amount = floor(pour_accumulator)
		pour_accumulator = 0.0
		_route_fallback(metal_id, pour_origin, amount, false)

func _route_pour(metal_id: String, pour_pos: Vector2, amount: float):
	_last_pour_metal = metal_id
	# ── Routing Design Note ──────────────────────────────────────────────────
	# pour_pos is the HOLD position (mouse release point), NOT the live drag
	# position. The player releases at the X-coordinate of the mold they want
	# to fill; that X is converted to an intake via _intake_for_x_offset().
	# Gate state is checked by FlowController.get_mold_for_pour_position() —
	# if no open gate covers the targeted intake the pour is marked waste.
	# This is intentional: HOLD = commit to a mold, drag = sweep region.
	# ─────────────────────────────────────────────────────────────────────────
	# Ask FlowController which mold to route to, given pour position and gate state.
	# Uses get_mold_for_pour_position() exclusively — no has_method fallback.
	if flow_controller and flow_controller.has_method("get_mold_for_pour_position"):
		var result = flow_controller.get_mold_for_pour_position(pour_pos)
		if result.mold_id != "":
			pour_routing_decided.emit(pour_pos, result.mold_id)
			flow_controller.route_metal_to_mold(result.intake_id, result.mold_id, metal_id, amount)
			metal_poured.emit(metal_id, pour_pos, amount)
		elif result.intake_id != "":
			# Intake exists but is blocked by gates — route to fallback
			pour_routing_decided.emit(pour_pos, "")
			_route_fallback(metal_id, pour_pos, amount)
		else:
			# No intake reachable — full waste
			pour_routing_decided.emit(pour_pos, "")
			if score_manager:
				score_manager.add_waste(amount)
			waste_routed.emit(metal_id, pour_pos, amount)
	else:
		# No get_mold_for_pour_position — fallback to nearest mold
		_route_fallback(metal_id, pour_pos, amount)



func _route_fallback(metal_id: String, pour_pos: Vector2, amount: float, penalize: bool = true):
	var nearest_mold_id = ""
	var nearest_dist = INF

	for mold_id in molds.keys():
		if molds[mold_id]:
			var dist = pour_pos.distance_to(molds[mold_id].global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_mold_id = mold_id

	if nearest_mold_id and molds[nearest_mold_id]:
		# Fallback routing delivers metal to nearest mold (correct behavior.)
		# waste_routed.emit() fires for visual feedback only — no score penalty.
		# receive_metal applies waste penalty internally via its penalize param
		# (false from flush_accumulator, true from normal _route_pour intake-blocked path).
		waste_routed.emit(metal_id, pour_pos, amount)
		molds[nearest_mold_id].receive_metal(metal_id, amount, penalize)
