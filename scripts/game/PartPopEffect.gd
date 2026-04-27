extends Node2D

signal part_popped(part_id: String, world_pos: Vector2)

var part_pop_scene = preload("res://scripts/ui/PartPopLabel.gd")

func _ready():
	var order_manager = get_node("/root/OrderManager")
	order_manager.order_completed.connect(_on_order_completed)

func _on_order_completed(order: OrderDefinition, score: int):
	var mold_area = get_node_or_null("/root/Main/MoldArea")
	if not mold_area:
		return

	var center_pos = mold_area.global_position + Vector2(0, -50)
	_spawn_pop_text("Order Complete!", center_pos, Color.GREEN)
	_spawn_pop_text("+%d" % score, center_pos + Vector2(0, 30), Color.YELLOW)

func spawn_part_pop(part_id: String, world_pos: Vector2):
	var label = Label.new()
	var parts = part_id.split("_")
	if parts.size() >= 2:
		label.text = parts[1].capitalize() + "!"
	else:
		label.text = part_id

	label.modulate = Color.CYAN
	label.position = world_pos
	add_child(label)

	var tween = create_tween()
	tween.tween_property(label, "position", world_pos + Vector2(0, -30), 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func _spawn_pop_text(text: String, world_pos: Vector2, color: Color):
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.position = world_pos
	add_child(label)

	var tween = create_tween()
	tween.tween_property(label, "position", world_pos + Vector2(0, -60), 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)
