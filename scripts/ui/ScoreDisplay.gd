extends Control

@onready var total_score_label: Label = $ScoreLabel

var score_manager: Node

func _ready():
	score_manager = get_node("/root/ScoreManager")
	score_manager.score_updated.connect(_on_score_updated)
	_update_display()

func _on_score_updated(new_score: int):
	_update_display(new_score)

func _update_display(score: int = 0):
	if score_manager:
		score = score_manager.get_total_score()
	if total_score_label:
		total_score_label.text = "Score: %d" % score
