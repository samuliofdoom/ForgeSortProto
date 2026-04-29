extends Node2D

signal part_popped(part_id: String, world_pos: Vector2)

func _ready():
	var order_manager = get_node("/root/OrderManager")
	order_manager.order_completed.connect(_on_order_completed)
	# Suppress unused_signal warning — declared for potential future use
	part_popped.connect(_noop)

func _noop(_part_id: String = "", _world_pos: Vector2 = Vector2.ZERO):
	pass

func _on_order_completed(_order: OrderDefinition, _score: int):
	var mold_area = get_node_or_null("/root/Main/MoldArea")
	if not mold_area:
		return

	var center_pos = mold_area.global_position + Vector2(0, -50)
	_spawn_pop_text("Order Complete!", center_pos, Color.GREEN)
	_spawn_pop_text("+%d" % _score, center_pos + Vector2(0, 30), Color.YELLOW)

func spawn_part_pop(part_id: String, world_pos: Vector2):
	# part_id format: "iron_blade", "steel_guard", "gold_grip"
	var parts = part_id.split("_")
	var metal = parts[0] if parts.size() >= 1 else "iron"
	var shape = parts[1] if parts.size() >= 2 else "blade"

	var polygon = Polygon2D.new()
	polygon.name = "PartPop_" + part_id
	polygon.polygon = _get_shape_polygon(shape)
	polygon.color = _get_metal_pop_color(metal)
	# Center polygon on world_pos in local space of this Node2D
	polygon.position = world_pos - global_position
	polygon.z_index = 150
	add_child(polygon)

	# Phase 1: scale pulse 1.0 → 1.3 over 0.2s
	var tween = create_tween()
	tween.tween_property(polygon, "scale", Vector2(1.3, 1.3), 0.2) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# Phase 2: scale 1.3 → 1.0 over 0.2s (total pulse = 0.4s)
	tween.tween_property(polygon, "scale", Vector2(1.0, 1.0), 0.2) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# Phase 3: fade out in final 0.2s
	tween.tween_property(polygon, "modulate:a", 0.0, 0.2)
	tween.tween_callback(polygon.queue_free)


func _get_shape_polygon(shape: String) -> PackedVector2Array:
	# All shapes centered near origin; PartPopEffect is a Node2D so these
	# are placed in its local coordinate space, then offset by world_pos.
	match shape:
		"blade":
			# Tall/thin blade silhouette — elongated vertically, narrow
			return PackedVector2Array([
				Vector2(-6, -30),   # tip top-left
				Vector2(6, -30),    # tip top-right
				Vector2(8, 30),     # base top-right
				Vector2(-8, 30),    # base top-left
			])
		"guard":
			# Wide/flat guard silhouette — broad horizontally
			return PackedVector2Array([
				Vector2(-35, -10),  # outer left-top
				Vector2(35, -10),   # outer right-top
				Vector2(30, 10),     # inner right-top
				Vector2(-30, 10),    # inner left-top
			])
		"grip":
			# Narrow/tall grip silhouette — cylindrical handle shape
			return PackedVector2Array([
				Vector2(-10, -28),  # top-left
				Vector2(10, -28),   # top-right
				Vector2(10, 28),    # bottom-right
				Vector2(-10, 28),   # bottom-left
			])
		_:
			# Default: small diamond
			return PackedVector2Array([
				Vector2(0, -20),
				Vector2(12, 0),
				Vector2(0, 20),
				Vector2(-12, 0),
			])


func _get_metal_pop_color(metal: String) -> Color:
	# Colour of the part sprite when it pops — cooled/solid metal colour.
	match metal:
		"iron":
			return Color(0.55, 0.52, 0.5)
		"steel":
			return Color(0.75, 0.78, 0.82)
		"gold":
			return Color(1.0, 0.82, 0.22)
		_:
			return Color(0.7, 0.7, 0.7)

func _spawn_pop_text(text: String, world_pos: Vector2, color: Color):
	var label = Label.new()
	label.text = text
	label.modulate = color
	# world_pos is in world-space; label.position is in Node2D's local space
	label.position = world_pos - global_position
	label.z_index = 200
	add_child(label)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)
