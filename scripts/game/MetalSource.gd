extends Node

signal metal_selected(metal_id: String)
signal pour_state_changed(is_pouring: bool)

var selected_metal: String = "iron"
var is_pouring: bool = false
var game_data: GameData

func _ready():
	game_data = get_node("/root/GameData")
	_select_metal("iron")

func _select_metal(metal_id: String):
	selected_metal = metal_id
	metal_selected.emit(selected_metal)

func get_selected_metal() -> String:
	return selected_metal

func get_selected_metal_data() -> MetalDefinition:
	return game_data.get_metal(selected_metal)

func start_pour():
	if not is_pouring:
		is_pouring = true
		pour_state_changed.emit(true)

func stop_pour():
	if is_pouring:
		is_pouring = false
		pour_state_changed.emit(false)

func select_next_metal():
	var metal_order = ["iron", "steel", "gold"]
	var current_index = metal_order.find(selected_metal)
	var next_index = (current_index + 1) % metal_order.size()
	_select_metal(metal_order[next_index])

func select_metal_by_id(metal_id: String):
	if game_data.metals.has(metal_id):
		_select_metal(metal_id)

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				select_metal_by_id("iron")
			KEY_2:
				select_metal_by_id("steel")
			KEY_3:
				select_metal_by_id("gold")
