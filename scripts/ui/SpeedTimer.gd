extends Label

var order_start_time: int = 0
var order_manager: Node

func _ready():
	order_manager = get_node("/root/OrderManager")
	order_manager.order_started.connect(_on_order_started)
	order_manager.order_completed.connect(_on_order_completed)
	# Initialize timer display
	text = "0.0s"

func _process(_delta):
	if order_start_time == 0:
		return
	var elapsed = (Time.get_ticks_msec() - order_start_time) / 1000.0
	text = "%.1fs" % elapsed
	_update_color(elapsed)

func _on_order_started(_order):
	order_start_time = Time.get_ticks_msec()
	text = "0.0s"
	modulate = Color.WHITE

func _on_order_completed(_order, _score):
	order_start_time = 0

func _update_color(elapsed: float):
	if elapsed < 25.0:
		modulate = Color.WHITE
	elif elapsed < 30.0:
		modulate = Color.ORANGE
	else:
		modulate = Color.RED
