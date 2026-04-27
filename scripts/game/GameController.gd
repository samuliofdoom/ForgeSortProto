extends Node

@onready var start_button: Button = $UI/StartButton

var order_manager: Node
var metal_flow: Node
var score_manager: Node
var flow_controller: Node

func _ready():
	order_manager = get_node("/root/OrderManager")
	metal_flow = get_node("/root/MetalFlow")
	score_manager = get_node("/root/ScoreManager")
	flow_controller = get_node("/root/FlowController")

	start_button.pressed.connect(_on_start_pressed)
	order_manager.game_completed.connect(_on_game_completed)
	order_manager.order_started.connect(_on_order_started)
	order_manager.order_completed.connect(_on_order_completed)

	_setup_molds()

func _on_start_pressed():
	start_button.hide()
	_reset_game()
	flow_controller.reset_all_gates()
	order_manager.start_game()

func _on_game_completed(results: Dictionary):
	start_button.show()

func _on_order_started(order: OrderDefinition):
	_update_mold_requirements_for_order(order)

func _on_order_completed(order: OrderDefinition, score: int):
	pass

func _reset_game():
	score_manager.reset() if score_manager else null
	flow_controller.reset_all_gates() if flow_controller else null

func _setup_molds():
	var mold_area = get_node_or_null("MoldArea")
	if not mold_area:
		return

	for mold_name in ["BladeMold", "GuardMold", "GripMold"]:
		var mold = mold_area.get_node_or_null(mold_name)
		if mold and metal_flow:
			metal_flow.register_mold(mold.mold_id, mold)

func _update_mold_requirements_for_order(order: OrderDefinition):
	var mold_area = get_node_or_null("MoldArea")
	if not mold_area:
		return

	var mold_req: Dictionary = {
		"blade": "iron",
		"guard": "iron",
		"grip": "iron"
	}

	for part_id in order.parts:
		var parts = part_id.split("_")
		if parts.size() >= 2:
			var metal = parts[0]
			var part_type = parts[1]
			mold_req[part_type] = metal

	var blade = mold_area.get_node_or_null("BladeMold")
	var guard = mold_area.get_node_or_null("GuardMold")
	var grip = mold_area.get_node_or_null("GripMold")

	_reset_mold(blade, "blade", mold_req["blade"])
	_reset_mold(guard, "guard", mold_req["guard"])
	_reset_mold(grip, "grip", mold_req["grip"])

func _reset_mold(mold, mold_id: String, required_metal: String):
	if not mold:
		return

	mold.required_metal = required_metal
	mold.current_fill = 0.0
	mold.is_contaminated = false
	mold.is_complete = false
	mold.current_metal = ""
	mold.is_filling = false

	var mold_sprite = mold.get_node_or_null("MoldSprite")
	if mold_sprite:
		mold_sprite.modulate = Color.WHITE

	if mold._update_display:
		mold._update_display()

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			get_tree().quit()
		if event.pressed and event.keycode == KEY_SPACE and start_button.visible:
			_on_start_pressed()
