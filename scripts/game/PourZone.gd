extends Area2D

signal pour_started(world_pos: Vector2)
signal pour_position_changed(world_pos: Vector2)
signal pour_ended()

@export var zone_width: float = 380.0

var is_pouring: bool = false
var pour_origin: Vector2 = Vector2.ZERO
var metal_source: Node
var metal_flow: Node

func _ready():
	metal_source = get_node_or_null("/root/MetalSource")
	metal_flow = get_node_or_null("/root/MetalFlow")

func _input(event):
	if event is InputEventMouseButton:
		var is_in_zone = _is_position_in_zone(event.position)
		if event.pressed and is_in_zone:
			_start_pour(event.position)
		elif not event.pressed and is_pouring:
			_end_pour()
	elif event is InputEventMouseMotion:
		if is_pouring and _is_position_in_zone(event.position):
			_update_pour_position(event.position)

func _is_position_in_zone(pos: Vector2) -> bool:
	var zone_rect = Rect2(
		global_position.x - zone_width / 2,
		global_position.y - 50,
		zone_width,
		100
	)
	return zone_rect.has_point(pos)

func _start_pour(pos: Vector2):
	is_pouring = true
	pour_origin = pos
	metal_source.start_pour()
	if metal_flow:
		metal_flow.set_active_stream(self)
	pour_started.emit(global_position)

func _update_pour_position(pos: Vector2):
	pour_origin = pos
	pour_position_changed.emit(pos)

func _end_pour():
	is_pouring = false
	metal_source.stop_pour()
	pour_ended.emit()
