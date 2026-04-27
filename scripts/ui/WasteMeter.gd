extends Control

@onready var waste_bar: ProgressBar = $WasteBar
@onready var waste_label: Label = $WasteLabel

var score_manager: Node

func _ready():
	score_manager = get_node("/root/ScoreManager")
	score_manager.waste_updated.connect(_on_waste_updated)
	score_manager.score_updated.connect(_on_score_updated)
	_update_display()

func _on_waste_updated(_waste_amount: float):
	_update_display()

func _on_score_updated(total_score: int):
	_update_display()

func _update_display(waste_amount: float = 0.0):
	if score_manager:
		waste_amount = score_manager.waste_units

	if waste_bar:
		var waste_percent = min(waste_amount / 100.0, 1.0) * 100.0
		waste_bar.value = waste_percent
		if waste_percent > 70:
			waste_bar.modulate = Color.RED
		elif waste_percent > 40:
			waste_bar.modulate = Color.YELLOW
		else:
			waste_bar.modulate = Color.GREEN
	if waste_label:
		waste_label.text = "Waste: %.0f" % waste_amount
