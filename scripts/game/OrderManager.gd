extends Node

signal order_completed(order: OrderDefinition, score: int)
signal order_started(order: OrderDefinition)
signal completed_parts_changed(parts: Array[String])
signal game_completed(results: Dictionary)

var current_order_index: int = 0
var completed_parts: Array[String] = []
var current_order: OrderDefinition = null
var game_data: Node
var score_manager: Node

func _ready():
	game_data = get_node("/root/GameData")
	score_manager = get_node("/root/ScoreManager")

func start_game():
	current_order_index = 0
	completed_parts.clear()
	if score_manager:
		score_manager.reset()
	start_next_order()

func start_next_order():
	if current_order_index >= game_data.orders.size():
		var final_score = score_manager.get_total_score() if score_manager else 0
		game_completed.emit({"total_score": final_score, "orders_completed": game_data.orders.size()})
		return

	current_order = game_data.get_order(current_order_index)
	completed_parts.clear()
	completed_parts_changed.emit(completed_parts.duplicate())
	order_started.emit(current_order)

func complete_part(part_id: String):
	if current_order == null:
		return

	if completed_parts.has(part_id):
		return

	completed_parts.append(part_id)
	completed_parts_changed.emit(completed_parts.duplicate())

	var all_complete = true
	for part in current_order.parts:
		if not completed_parts.has(part):
			all_complete = false
			break

	if all_complete:
		var order_score = score_manager.calculate_order_score(current_order) if score_manager else current_order.base_value
		current_order_index += 1
		order_completed.emit(current_order, order_score)
		if current_order_index < game_data.orders.size():
			start_next_order()

func get_current_order() -> OrderDefinition:
	return current_order

func get_completed_parts() -> Array[String]:
	return completed_parts.duplicate()

func get_current_order_index() -> int:
	return current_order_index
