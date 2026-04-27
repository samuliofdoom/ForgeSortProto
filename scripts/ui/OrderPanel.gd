extends Control

@onready var order_name_label: Label = $OrderName
@onready var part_list: VBoxContainer = $PartList
@onready var order_progress: ProgressBar = $OrderProgress

var current_order: OrderDefinition = null
var order_manager: Node
var score_manager: Node

func _ready():
	order_manager = get_node("/root/OrderManager")
	score_manager = get_node("/root/ScoreManager")
	order_manager.order_started.connect(_on_order_started)
	order_manager.order_completed.connect(_on_order_completed)
	order_manager.completed_parts_changed.connect(_on_completed_parts_changed)
	_update_display()

func _on_order_started(order: OrderDefinition):
	current_order = order
	_update_display()

func _on_order_completed(_order: OrderDefinition, _score: int):
	_update_display()

func _on_completed_parts_changed(_parts: Array[String]):
	_update_display()

func _update_display():
	if current_order == null:
		order_name_label.text = "No Order"
		return

	order_name_label.text = current_order.name + " - " + str(current_order.base_value) + " pts"

	for child in part_list.get_children():
		child.queue_free()

	var completed = order_manager.get_completed_parts()

	for part_id in current_order.parts:
		var hbox = HBoxContainer.new()
		var check_label = Label.new()
		var name_label = Label.new()

		var part_name = part_id.replace("_", " ").capitalize()
		if completed.has(part_id):
			check_label.text = "✓"
			check_label.modulate = Color.GREEN
			name_label.modulate = Color.GREEN
		else:
			check_label.text = "○"
			check_label.modulate = Color.WHITE
			name_label.modulate = Color.WHITE

		name_label.text = " " + part_name
		hbox.add_child(check_label)
		hbox.add_child(name_label)
		part_list.add_child(hbox)

	var total_parts = current_order.parts.size()
	var done_parts = completed.size()
	order_progress.value = (done_parts / float(total_parts)) * 100.0 if total_parts > 0 else 0.0
