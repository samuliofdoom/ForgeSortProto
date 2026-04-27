extends Control

signal metal_selected(metal_id: String)

@onready var iron_button: Button = $IronButton
@onready var steel_button: Button = $SteelButton
@onready var gold_button: Button = $GoldButton
@onready var metal_label: Label = $MetalLabel

var selected_metal: String = "iron"
var metal_source: Node
var game_data: Node

var metal_colors: Dictionary = {
	"iron": Color(0.6, 0.4, 0.3),
	"steel": Color(0.7, 0.75, 0.8),
	"gold": Color(1.0, 0.85, 0.2)
}

func _ready():
	metal_source = get_node("/root/MetalSource")
	game_data = get_node("/root/GameData")
	metal_source.metal_selected.connect(_on_metal_selected)

	iron_button.pressed.connect(_on_iron_pressed)
	steel_button.pressed.connect(_on_steel_pressed)
	gold_button.pressed.connect(_on_gold_pressed)

	_update_selection()

func _on_iron_pressed():
	metal_source.select_metal_by_id("iron")

func _on_steel_pressed():
	metal_source.select_metal_by_id("steel")

func _on_gold_pressed():
	metal_source.select_metal_by_id("gold")

func _on_metal_selected(metal_id: String):
	selected_metal = metal_id
	_update_selection()

func _update_selection():
	iron_button.button_pressed = selected_metal == "iron"
	steel_button.button_pressed = selected_metal == "steel"
	gold_button.button_pressed = selected_metal == "gold"

	var metal_data = game_data.get_metal(selected_metal)
	if metal_label and metal_data:
		metal_label.text = metal_data.name
		metal_label.modulate = metal_colors.get(selected_metal, Color.WHITE)
