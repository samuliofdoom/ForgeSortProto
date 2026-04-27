extends Label

var float_speed: float = -50.0
var lifetime: float = 1.0
var time_alive: float = 0.0

func _ready():
	modulate.a = 1.0

func _process(delta):
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()
		return

	position.y += float_speed * delta
	modulate.a = 1.0 - (time_alive / lifetime)
