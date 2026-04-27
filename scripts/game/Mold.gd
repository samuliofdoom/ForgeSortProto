extends Node2D

signal part_produced(part_id: String, mold_id: String)
signal mold_filled(mold_id: String, fill_percent: float)
signal mold_contaminated(mold_id: String)
signal mold_completed(mold_id: String)
signal mold_cleared(mold_id: String)
signal mold_tapped(mold_id: String)

@export var mold_id: String = "blade"
@export var part_type: String = "blade"
@export var required_metal: String = "iron"
@export var fill_amount: float = 100.0

var current_fill: float = 0.0
var is_contaminated: bool = false
var is_complete: bool = false
var current_metal: String = ""
var is_filling: bool = false

@onready var fill_bar: ProgressBar = $FillBar
@onready var state_label: Label = $StateLabel
@onready var mold_sprite: ColorRect = $MoldSprite

var order_manager: Node
var score_manager: Node
var game_data: Node
var metal_flow: Node
var part_pop_effect: Node

func _ready():
	order_manager = get_node("/root/OrderManager")
	score_manager = get_node("/root/ScoreManager")
	game_data = get_node("/root/GameData")
	metal_flow = get_node("/root/MetalFlow")
	part_pop_effect = get_node_or_null("/root/Main/PartPopEffect")

	if metal_flow and metal_flow.has_method("register_mold"):
		metal_flow.register_mold(mold_id, self)

	_update_display()

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed and _is_click_on_mold(event.position):
			_on_mold_tapped()

func _is_click_on_mold(click_pos: Vector2) -> bool:
	var rect = Rect2(global_position - Vector2(40, 30), Vector2(80, 60))
	return rect.has_point(click_pos)

func _on_mold_tapped():
	mold_tapped.emit(mold_id)
	if is_contaminated:
		clear_mold()

func receive_metal(metal_id: String, amount: float):
	if is_complete:
		score_manager.add_waste(amount)
		return

	if not is_contaminated and current_fill >= fill_amount:
		score_manager.add_waste(amount)
		return

	if current_metal == "":
		current_metal = metal_id

	if metal_id != required_metal and not is_contaminated:
		_trigger_contamination(metal_id, amount)
		return

	if metal_id != current_metal:
		return

	is_filling = true
	current_fill += amount
	_update_display()
	mold_filled.emit(mold_id, get_fill_percent())

	if current_fill >= fill_amount and not is_complete:
		_trigger_complete()

func _trigger_contamination(wrong_metal: String, amount: float):
	is_contaminated = true
	current_metal = wrong_metal
	score_manager.add_contamination()
	score_manager.add_waste(amount)
	_update_display()
	mold_contaminated.emit(mold_id)
	_create_contamination_effect()

func _trigger_complete():
	is_complete = true
	is_filling = false
	_update_display()
	mold_completed.emit(mold_id)
	_produce_part()
	_create_complete_effect()

func _produce_part():
	var metal_prefix = current_metal
	var part_id = metal_prefix + "_" + part_type
	part_produced.emit(part_id, mold_id)
	order_manager.complete_part(part_id)

	if part_pop_effect and part_pop_effect.has_method("spawn_part_pop"):
		part_pop_effect.spawn_part_pop(part_id, global_position)

func clear_mold():
	current_fill = 0.0
	is_contaminated = false
	is_complete = false
	current_metal = ""
	is_filling = false
	_update_display()
	mold_cleared.emit(mold_id)
	_create_clear_effect()

func get_fill_percent() -> float:
	return clamp(current_fill / fill_amount, 0.0, 1.0)

func get_mold_id() -> String:
	return mold_id

func get_part_type() -> String:
	return part_type

func _update_display():
	if fill_bar:
		fill_bar.value = get_fill_percent() * 100
		if is_contaminated:
			fill_bar.modulate = Color.RED
		elif is_complete:
			fill_bar.modulate = Color.GREEN
		elif current_fill > 0:
			fill_bar.modulate = Color.YELLOW
		else:
			fill_bar.modulate = Color.WHITE

	if state_label:
		if is_complete:
			state_label.text = "Done!"
			state_label.modulate = Color.GREEN
		elif is_contaminated:
			state_label.text = "Tap to Clear"
			state_label.modulate = Color.RED
		elif current_fill > 0:
			state_label.text = "%.0f%%" % (get_fill_percent() * 100)
			state_label.modulate = Color.YELLOW
		else:
			state_label.text = required_metal.capitalize()
			state_label.modulate = Color.WHITE

	if mold_sprite:
		if is_contaminated:
			mold_sprite.modulate = Color.RED * 0.5
		elif is_complete:
			mold_sprite.modulate = Color.GREEN * 0.5
		elif current_fill > 0:
			mold_sprite.modulate = _get_metal_color(current_metal) * 0.7
		else:
			mold_sprite.modulate = Color.WHITE

func _get_metal_color(metal_id: String) -> Color:
	match metal_id:
		"iron":
			return Color(0.6, 0.4, 0.3)
		"steel":
			return Color(0.7, 0.75, 0.8)
		"gold":
			return Color(1.0, 0.85, 0.2)
		_:
			return Color(0.8, 0.6, 0.3)

func _create_contamination_effect():
	if mold_sprite:
		var tween = create_tween()
		tween.tween_property(mold_sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(mold_sprite, "modulate", Color.WHITE, 0.3)

func _create_complete_effect():
	if mold_sprite:
		var tween = create_tween()
		tween.tween_property(mold_sprite, "scale", Vector2(1.2, 1.2), 0.15)
		tween.tween_property(mold_sprite, "scale", Vector2(1.0, 1.0), 0.15)

func _create_clear_effect():
	if mold_sprite:
		var tween = create_tween()
		tween.tween_property(mold_sprite, "modulate", Color.BLUE * 0.3, 0.2)
		tween.tween_property(mold_sprite, "modulate", Color.WHITE, 0.2)
