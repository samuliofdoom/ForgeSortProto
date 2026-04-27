extends Control

@onready var result_label: Label = $ResultLabel
@onready var restart_button: Button = $RestartButton

var order_manager: Node

func _ready():
	order_manager = get_node("/root/OrderManager")
	order_manager.game_completed.connect(_on_game_completed)
	restart_button.pressed.connect(_on_restart_pressed)
	hide()

func _on_game_completed(results: Dictionary):
	result_label.text = "Final Score: %d\nOrders Completed: %d" % [results.total_score, results.orders_completed]
	show()

func _on_restart_pressed():
	hide()
	order_manager.start_game()
