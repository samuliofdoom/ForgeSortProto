extends Control

@onready var result_label: Label = $ResultLabel
@onready var restart_button: Button = $RestartButton
@onready var panel_bg: ColorRect = $PanelBG
@onready var overlay: ColorRect = $Overlay

var order_manager: Node
var score_manager: Node
var _tween: Tween

func _ready():
	# Use externally-set references if available (allows unit-test injection),
	# otherwise fall back to autoload nodes from the scene tree.
	if not order_manager:
		order_manager = get_node("/root/OrderManager")
	if not score_manager:
		score_manager = get_node("/root/ScoreManager")
	order_manager.game_completed.connect(_on_game_completed)
	score_manager.game_over.connect(_on_game_over)
	restart_button.pressed.connect(_on_restart_pressed)
	if overlay:
		overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	hide()

func _on_game_completed(results: Dictionary):
	result_label.text = "Final Score: %d\nOrders Completed: %d" % [results.get("total_score", 0), results.get("orders_completed", 0)]
	_show_panel()

func _on_game_over(final_score: int, waste_percent: float):
	result_label.text = "GAME OVER\nFinal Score: %d\nWaste: %.0f%%" % [final_score, waste_percent]
	_show_panel()
	_shake_overlay()

func _show_panel():
	restart_button.show()
	show()

func _shake_overlay():
	if not overlay:
		return
	_tween = create_tween()
	var duration: float = 0.4
	var offsets: Array[Vector2] = [
		Vector2(8, 4), Vector2(-8, -4), Vector2(6, -6), Vector2(-6, 6),
		Vector2(4, 8), Vector2(-4, -8), Vector2(2, 2), Vector2(0, 0)
	]
	for offset in offsets:
		_tween.tween_property(overlay, "offset_left", offset.x, duration / offsets.size())
		_tween.tween_property(overlay, "offset_top", offset.y, duration / offsets.size())
	overlay.offset_left = 0
	overlay.offset_top = 0

func _on_restart_pressed():
	hide()
	if overlay:
		overlay.offset_left = 0
		overlay.offset_top = 0
	order_manager.start_game()
