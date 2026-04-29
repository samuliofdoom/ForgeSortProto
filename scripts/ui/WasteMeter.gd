extends Control

@onready var waste_bar: ProgressBar = $WasteBar
@onready var waste_label: Label = $WasteLabel

var score_manager: Node

func _ready():
	score_manager = get_node("/root/ScoreManager")
	score_manager.waste_updated.connect(_on_waste_updated)
	score_manager.score_updated.connect(_on_score_updated)
	score_manager.contamination_penalty.connect(_on_contamination_penalty)
	_update_display()

var _last_waste_value: float = 0.0

func _on_waste_updated(_waste_amount: float):
	_update_display()
	# Show floating waste label only when waste actually increases (ignore 0-delta and initial 0.0)
	var prev = _last_waste_value
	_last_waste_value = _waste_amount
	var delta = _waste_amount - prev
	if delta > 0.0:
		_show_waste_floating_label(delta)

func _show_waste_floating_label(amount: float):
	var label = Label.new()
	label.name = "WasteFloat"
	label.text = "+%.0f Waste" % amount
	label.modulate = Color.ORANGE
	label.z_index = 200
	# Position near waste bar
	var bar = get_node_or_null("WasteBar")
	if bar:
		label.position = bar.global_position + Vector2(160, -20)
	else:
		label.position = Vector2(160, -20)
	add_child(label)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)

func _on_score_updated(_total_score: int):
	_update_display()

func _on_contamination_penalty(_penalty: int):
	# Flash red on contamination event so the player knows waste just increased.
	_update_display()
	if waste_bar:
		var tween = create_tween()
		waste_bar.modulate = Color.RED
		tween.tween_interval(0.3)
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
