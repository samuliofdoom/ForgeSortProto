extends Control

## Dedicated checklist panel showing the current order's required parts
## with live checkmarks as each part is completed.
## Wires to order_manager signals: order_started, completed_parts_changed.

@onready var checklist_container: VBoxContainer = $ChecklistContainer
@onready var title_label: Label = $TitleLabel
var timer_label: Label = null
var timer_container: HBoxContainer = null
var speed_bonus_label: Label = null
var contamination_label: Label = null

var order_manager: Node
var score_manager: Node
var _current_parts: Array[String] = []
var _check_rows: Dictionary = {}  # part_id -> {row: HBoxContainer, check: Label}

func _ready():
	order_manager = get_node_or_null("/root/OrderManager")
	if order_manager:
		order_manager.order_started.connect(_on_order_started)
		order_manager.completed_parts_changed.connect(_on_completed_parts_changed)

	score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		score_manager.contamination_this_order_updated.connect(_on_contamination_updated)

	# Also listen to mold part_produced for real-time checklist updates
	var mold_area = get_node_or_null("/root/Main/MoldArea")
	if mold_area:
		for mold in mold_area.get_children():
			if mold.has_signal("part_produced"):
				mold.part_produced.connect(_on_part_produced)

	# Get optional timer/contamination nodes (may not exist in all scene configurations)
	timer_container = get_node_or_null("TimerContainer")
	timer_label = get_node_or_null("TimerContainer/TimerLabel")
	speed_bonus_label = get_node_or_null("TimerContainer/SpeedBonusLabel")
	contamination_label = get_node_or_null("ContaminationContainer/ContaminationLabel")

	_update_visibility()

func _on_order_started(order: OrderDefinition):
	_current_parts = order.parts.duplicate()
	_build_checklist()
	_reset_timer_display()

func _on_completed_parts_changed(completed: Array[String]):
	_refresh_checks(completed)

func _on_part_produced(_part_id: String, _mold_id: String):
	# Refresh checks when a part is produced (handles any ordering edge cases)
	if order_manager:
		_refresh_checks(order_manager.get_completed_parts())

func _process(_delta):
	if timer_container == null or not timer_container.visible:
		return
	if not score_manager or score_manager.order_start_time == 0:
		return
	var elapsed = (Time.get_ticks_msec() - score_manager.order_start_time) / 1000.0
	var remaining = max(0.0, 30.0 - elapsed)
	if timer_label:
		timer_label.text = "%.1f s" % elapsed
	if speed_bonus_label:
		speed_bonus_label.text = "(+%.0f speed)" % remaining if remaining > 0 else "(no speed)"
	_update_timer_color(elapsed)

func _update_timer_color(elapsed: float):
	if elapsed < 25.0:
		if timer_label:
			timer_label.modulate = Color.WHITE
		if speed_bonus_label:
			speed_bonus_label.modulate = Color.GREEN
	elif elapsed < 30.0:
		if timer_label:
			timer_label.modulate = Color.ORANGE
		if speed_bonus_label:
			speed_bonus_label.modulate = Color.YELLOW
	else:
		if timer_label:
			timer_label.modulate = Color.RED
		if speed_bonus_label:
			speed_bonus_label.modulate = Color.RED

func _reset_timer_display():
	if timer_label:
		timer_label.text = "0.0s"
	if speed_bonus_label:
		speed_bonus_label.text = "(+30 speed)"
		timer_label.modulate = Color.WHITE
		speed_bonus_label.modulate = Color.GREEN
	if contamination_label:
		contamination_label.text = "Contamination: 0"
		contamination_label.modulate = Color.GREEN

func _on_contamination_updated(count: int):
	if contamination_label:
		contamination_label.text = "Contamination: %d" % count
		if count == 0:
			contamination_label.modulate = Color.GREEN
		elif count < 3:
			contamination_label.modulate = Color.YELLOW
		else:
			contamination_label.modulate = Color.RED

func _refresh_checks(completed: Array[String]):
	for part_id in _check_rows:
		var row_data = _check_rows[part_id]
		var check_label: Label = row_data["check"]
		if completed.has(part_id):
			check_label.text = "✓"
			check_label.modulate = Color.GREEN
			row_data["row"].modulate = Color.GREEN * 0.8
		else:
			check_label.text = "○"
			check_label.modulate = Color.WHITE * 0.5
			row_data["row"].modulate = Color.WHITE

func _build_checklist():
	# Clear existing rows
	for child in checklist_container.get_children():
		child.queue_free()
	_check_rows.clear()

	if not _current_parts:
		title_label.text = ""
		return

	title_label.text = "Parts Needed:"

	var completed = order_manager.get_completed_parts() if order_manager else []

	for part_id in _current_parts:
		var row = HBoxContainer.new()
		var check = Label.new()
		var name = Label.new()

		var is_done = completed.has(part_id)
		check.text = "✓" if is_done else "○"
		check.modulate = Color.GREEN if is_done else Color.WHITE * 0.5
		name.text = " " + part_id.replace("_", " ").capitalize()
		name.modulate = Color.GREEN * 0.8 if is_done else Color.WHITE * 0.7

		row.add_child(check)
		row.add_child(name)
		checklist_container.add_child(row)
		_check_rows[part_id] = {"row": row, "check": check}

	# Apply initial modulate to title based on completion
	_refresh_checks(completed)
	_reset_timer_display()

func _update_visibility():
	visible = (_current_parts.size() > 0)
