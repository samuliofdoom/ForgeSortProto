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

	# Listen for mold state changes to keep display fresh.
	# Mold nodes register themselves via MetalFlow / direct reference.
	var mold_area = get_node_or_null("/root/Main/MoldArea")
	if mold_area:
		for mold_name in ["BladeMold", "GuardMold", "GripMold"]:
			var mold = mold_area.get_node_or_null(mold_name)
			if mold and mold.has_signal("mold_contaminated"):
				mold.mold_contaminated.connect(_on_mold_contaminated.bind(mold_name))

	_update_display()

func _on_order_started(order: OrderDefinition):
	current_order = order
	_update_display()

func _on_order_completed(_order: OrderDefinition, _score: int):
	_update_display()
	_show_order_complete_fanfare()

func _show_order_complete_fanfare():
	# Brief flash of the order panel to celebrate completion
	var tween = create_tween()
	modulate = Color.GREEN * 1.5
	tween.tween_interval(0.3)
	tween.tween_callback(func(): modulate = Color.WHITE)

func _on_completed_parts_changed(_parts: Array[String]):
	_update_display()

func _on_mold_contaminated(_mold_name: String, _mold_id: String):
	# Flash the order panel red to warn the player a mold is contaminated.
	modulate = Color.RED * 0.6
	var tween = create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(func(): modulate = Color.WHITE)

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
	if total_parts > 0:
		order_progress.value = (done_parts / float(total_parts)) * 100.0
	else:
		order_progress.value = 0.0
