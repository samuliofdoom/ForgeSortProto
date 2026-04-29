extends Node

signal score_updated(total: int)
signal waste_updated(waste_percent: float)
signal contamination_penalty(penalty: int)
signal game_over(final_score: int, waste_percent: float)

var total_score: int = 0
var waste_units: float = 0.0
var contamination_count: int = 0
var start_time: int = 0
var order_start_time: int = 0
var game_started: bool = false

const WASTE_PENALTY_PER_UNIT: float = 1.0
const CONTAMINATION_PENALTY: int = 25
const SPEED_BONUS: int = 50
const SPEED_THRESHOLD_SECONDS: float = 30.0
const WASTE_METER_MAX: float = 100.0

func _ready():
	# start_time is set in reset() which is called by start_game(), not here.
	# This avoids counting the time between _ready() and actual game start.
	pass

func reset():
	total_score = 0
	waste_units = 0.0
	contamination_count = 0
	start_time = Time.get_ticks_msec()
	order_start_time = start_time
	score_updated.emit(total_score)
	waste_updated.emit(0.0)

func start_order_timer():
	order_start_time = Time.get_ticks_msec()

func reset_order():
	contamination_count = 0

func add_waste(amount: float):
	waste_units += amount
	var waste_penalty = waste_units * WASTE_PENALTY_PER_UNIT
	total_score = max(0, total_score - int(waste_penalty))
	var waste_percent = clamp(waste_units / WASTE_METER_MAX * 100.0, 0.0, 100.0)
	waste_updated.emit(waste_percent)
	score_updated.emit(total_score)

	# Hard fail at 100% waste meter
	if waste_units >= WASTE_METER_MAX:
		game_over.emit(total_score, waste_percent)

func add_contamination():
	contamination_count += 1
	total_score = max(0, total_score - CONTAMINATION_PENALTY)
	contamination_penalty.emit(CONTAMINATION_PENALTY)
	score_updated.emit(total_score)

func calculate_order_score(order: OrderDefinition) -> int:
	var base = order.base_value
	var elapsed = (Time.get_ticks_msec() - order_start_time) / 1000.0

	if elapsed < SPEED_THRESHOLD_SECONDS:
		base += SPEED_BONUS

	total_score += base
	score_updated.emit(total_score)
	return base

func get_total_score() -> int:
	return total_score
