extends Node2D

signal part_produced(part_id: String, mold_id: String)
signal mold_filled(mold_id: String, fill_percent: float)
signal mold_contaminated(mold_id: String)
signal mold_completed(mold_id: String)
signal mold_cleared(mold_id: String)
signal mold_tapped(mold_id: String)

enum MoldState { IDLE, FILLING, COMPLETE, HARDENING, CONTAMINATED, LOCKED }

@export var mold_id: String = "blade"
@export var part_type: String = "blade"
@export var required_metal: String = "iron"
@export var fill_amount: float = 100.0

var current_fill: float = 0.0
var is_contaminated: bool = false
var is_complete: bool = false
var current_metal: String = ""
var is_filling: bool = false
var is_locked: bool = false  # true between order complete and next order starting
var mold_state: MoldState = MoldState.IDLE

var _hardening_timer: Timer = null

@onready var fill_bar: ProgressBar = $FillBar
@onready var state_label: Label = $StateLabel
@onready var mold_sprite: ColorRect = $MoldSprite
var mold_glow: ColorRect  # nullable - created programmatically if not in scene
var padlock: Node = null  # programmatic padlock icon for locked state
var _padlock_pulse_tween: Tween = null

var order_manager: Node
var score_manager: Node
var game_data: Node
var metal_flow: Node
var part_pop_effect: Node
var _glow_active: bool = false

func _ready():
	order_manager = get_node("/root/OrderManager")
	score_manager = get_node("/root/ScoreManager")
	game_data = get_node("/root/GameData")
	metal_flow = get_node("/root/MetalFlow")
	part_pop_effect = get_node_or_null("/root/Main/PartPopEffect")

	if metal_flow and metal_flow.has_method("register_mold"):
		metal_flow.register_mold(mold_id, self)
	if order_manager:
		order_manager.order_completed.connect(_on_order_completed)
		order_manager.order_started.connect(_on_order_started)

	# Create programmatic padlock icon (hidden by default)
	_create_padlock_icon()
	_update_display()

func _input(event):
	if event is InputEventMouseButton:
		# Use get_global_mouse_position() — event.position is screen-space but
		# _is_click_on_mold() uses world-space (global_position). Using screen-space
		# coords would give wrong results when the viewport is scrolled or the
		# MoldArea is not at origin.
		if event.pressed and _is_click_on_mold(get_global_mouse_position()):
			_on_mold_tapped()

func _is_click_on_mold(click_pos: Vector2) -> bool:
	var rect = Rect2(global_position - Vector2(40, 30), Vector2(80, 60))
	return rect.has_point(click_pos)

func _on_mold_tapped():
	mold_tapped.emit(mold_id)
	if is_contaminated:
		clear_mold()

func receive_metal(metal_id: String, amount: float):
	if is_locked:
		score_manager.add_waste(amount)
		return

	if mold_state == MoldState.HARDENING:
		score_manager.add_waste(amount)
		return

	if is_complete:
		if metal_id != required_metal and not is_contaminated:
			_trigger_wrong_metal_flash(metal_id)
			_trigger_contamination(metal_id, amount)
		else:
			score_manager.add_waste(amount)
		return

	if not is_contaminated and current_fill >= fill_amount:
		score_manager.add_waste(amount)
		return

	if current_metal == "":
		current_metal = metal_id

	if metal_id != required_metal and not is_contaminated:
		_trigger_wrong_metal_flash(metal_id)
		_trigger_contamination(metal_id, amount)
		return

	if metal_id != current_metal:
		return

	is_filling = true
	mold_state = MoldState.FILLING
	current_fill += amount
	_create_receiving_glow(metal_id)
	_update_display()
	mold_filled.emit(mold_id, get_fill_percent())

	if current_fill >= fill_amount and not is_complete:
		_trigger_complete()

func _trigger_contamination(wrong_metal: String, amount: float):
	is_contaminated = true
	current_metal = wrong_metal
	mold_state = MoldState.CONTAMINATED
	score_manager.add_contamination()
	score_manager.add_waste(amount)
	_update_display()
	mold_contaminated.emit(mold_id)
	_create_contamination_effect()

func _trigger_complete():
	is_complete = true
	is_filling = false
	mold_state = MoldState.HARDENING
	_update_display()
	# Emit mold_completed at START of hardening so order knows part is coming
	mold_completed.emit(mold_id)
	_animate_hardening()
	_start_hardening_timer()
	# Do NOT call _produce_part() here — that happens after hardening

func _start_hardening_timer():
	_hardening_timer = Timer.new()
	_hardening_timer.wait_time = 2.0
	_hardening_timer.one_shot = true
	_hardening_timer.timeout.connect(_on_hardening_complete)
	add_child(_hardening_timer)
	_hardening_timer.start()

func _on_hardening_complete():
	mold_state = MoldState.COMPLETE
	_produce_part()
	_animate_complete_settle()

func _produce_part():
	var metal_prefix = current_metal
	var part_id = metal_prefix + "_" + part_type
	part_produced.emit(part_id, mold_id)
	order_manager.complete_part(part_id)

	if part_pop_effect and part_pop_effect.has_method("spawn_part_pop"):
		part_pop_effect.spawn_part_pop(part_id, global_position)

func clear_mold():
	# Cancel any active hardening timer
	if _hardening_timer:
		_hardening_timer.stop()
		_hardening_timer.queue_free()
		_hardening_timer = null

	current_fill = 0.0
	is_contaminated = false
	is_complete = false
	current_metal = ""
	is_filling = false
	mold_state = MoldState.IDLE
	_update_display()
	mold_cleared.emit(mold_id)
	_create_clear_effect()

func get_fill_percent() -> float:
	return clamp(current_fill / fill_amount, 0.0, 1.0)

func get_mold_id() -> String:
	return mold_id

func get_part_type() -> String:
	return part_type

func _on_order_completed(_completed_order: OrderDefinition, _score: int):
	is_locked = true

func _on_order_started(new_order: OrderDefinition):
	# Cancel any active hardening timer if order changes mid-hardening
	if _hardening_timer:
		_hardening_timer.stop()
		_hardening_timer.queue_free()
		_hardening_timer = null

	if score_manager and score_manager.has_method("reset_order"):
		score_manager.reset_order()
	is_locked = false
	mold_state = MoldState.IDLE
	# Always clear mold at order start — fixes BUG-003: partial fills
	# that were neither complete nor contaminated would leak into next order
	if is_complete or is_contaminated:
		clear_mold()
	else:
		# Partial fill: reset state without signal/effects (avoids triggering
		# mold_cleared → OrderManager recursion during order transition)
		current_fill = 0.0
		current_metal = ""
		is_contaminated = false
		is_complete = false
		_update_display()
	if new_order.part_requests.has(part_type):
		required_metal = new_order.part_requests[part_type]
	_update_display()

func _update_display():
	if fill_bar:
		var target_val = get_fill_percent() * 100
		var tween = create_tween()
		tween.tween_property(fill_bar, "value", target_val, 0.25)
		if mold_state == MoldState.HARDENING:
			fill_bar.modulate = Color.ORANGE
		elif is_contaminated:
			fill_bar.modulate = Color.RED
		elif is_complete:
			fill_bar.modulate = Color.GREEN
		elif current_fill > 0:
			fill_bar.modulate = Color.YELLOW
		else:
			fill_bar.modulate = Color.WHITE

	if mold_sprite:
		if mold_state == MoldState.HARDENING:
			mold_sprite.modulate = Color(0.5, 0.55, 0.6)
		elif is_contaminated:
			mold_sprite.modulate = Color.RED * 0.5
		elif is_complete:
			mold_sprite.modulate = Color.GREEN * 0.5
		elif current_fill > 0:
			mold_sprite.modulate = MetalDefinition.get_color(current_metal) * 0.7
		elif is_locked:
			mold_sprite.modulate = Color.DIM_GRAY * 0.5
		else:
			mold_sprite.modulate = Color.WHITE
		# Apply ambient glow when filling - brighter glow based on fill amount
		_update_fill_glow()

	if state_label:
		if mold_state == MoldState.HARDENING:
			state_label.text = "Cooling..."
			state_label.modulate = Color.ORANGE
		elif is_complete:
			state_label.text = "Done!"
			state_label.modulate = Color.GREEN
		elif is_contaminated:
			state_label.text = "Tap to Clear"
			state_label.modulate = Color.RED
		elif is_locked:
			state_label.text = "Locked"
			state_label.modulate = Color.DIM_GRAY
		elif current_fill > 0:
			state_label.text = "%.0f%%" % (get_fill_percent() * 100)
			state_label.modulate = Color.YELLOW
		else:
			state_label.text = required_metal.capitalize()
			state_label.modulate = Color.WHITE

	_update_padlock_visibility()

func _update_fill_glow():
	# Add ambient glow to mold sprite based on fill state
	# When filling: increase brightness proportional to fill amount
	# When complete/hardening: dim glow
	if mold_state == MoldState.FILLING:
		var fill_pct = get_fill_percent()
		# Subtle glow pulse animation
		var pulse = (sin(Time.get_ticks_msec() * 0.005) + 1.0) * 0.15 + 0.85
		mold_sprite.modulate.v = pulse  # brighten based on fill
	elif mold_state == MoldState.HARDENING:
		mold_sprite.modulate.v = 0.6  # dimmer during cooling
	elif is_complete:
		mold_sprite.modulate.v = 0.7  # finished glow
	elif is_contaminated:
		mold_sprite.modulate.v = 0.4  # dim contamination

func _get_metal_color(metal_id: String) -> Color:
	return MetalDefinition.get_color(metal_id)

func _create_padlock_icon():
	# Build a simple padlock from ColorRects: body + shackle arch
	padlock = Node2D.new()
	padlock.name = "Padlock"
	padlock.z_index = 10
	padlock.visible = false
	add_child(padlock)

	# Padlock body (rectangle)
	var body = ColorRect.new()
	body.name = "Body"
	body.size = Vector2(16, 12)
	body.position = Vector2(-8, -2)
	body.color = Color(0.6, 0.6, 0.65)
	body.anchor_left = 0.5
	body.anchor_right = 0.5
	body.anchor_top = 0.5
	body.anchor_bottom = 0.5
	padlock.add_child(body)

	# Shackle (arch made of two vertical rects and a top bar)
	var shackle_left = ColorRect.new()
	shackle_left.name = "ShackleLeft"
	shackle_left.size = Vector2(3, 10)
	shackle_left.position = Vector2(-6, -12)
	shackle_left.color = Color(0.6, 0.6, 0.65)
	shackle_left.anchor_left = 0.5
	shackle_left.anchor_right = 0.5
	shackle_left.anchor_top = 0.5
	shackle_left.anchor_bottom = 0.5
	padlock.add_child(shackle_left)

	var shackle_right = ColorRect.new()
	shackle_right.name = "ShackleRight"
	shackle_right.size = Vector2(3, 10)
	shackle_right.position = Vector2(3, -12)
	shackle_right.color = Color(0.6, 0.6, 0.65)
	shackle_right.anchor_left = 0.5
	shackle_right.anchor_right = 0.5
	shackle_right.anchor_top = 0.5
	shackle_right.anchor_bottom = 0.5
	padlock.add_child(shackle_right)

	var shackle_top = ColorRect.new()
	shackle_top.name = "ShackleTop"
	shackle_top.size = Vector2(12, 3)
	shackle_top.position = Vector2(-6, -14)
	shackle_top.color = Color(0.6, 0.6, 0.65)
	shackle_top.anchor_left = 0.5
	shackle_top.anchor_right = 0.5
	shackle_top.anchor_top = 0.5
	shackle_top.anchor_bottom = 0.5
	padlock.add_child(shackle_top)

func _update_padlock_visibility():
	if not padlock:
		return
	var should_show = is_locked
	if should_show and not padlock.visible:
		padlock.visible = true
		_start_padlock_pulse()
	elif not should_show and padlock.visible:
		_stop_padlock_pulse()
		padlock.visible = false

func _start_padlock_pulse():
	if _padlock_pulse_tween:
		_padlock_pulse_tween.kill()
	_padlock_pulse_tween = create_tween()
	_padlock_pulse_tween.set_parallel(true)
	_padlock_pulse_tween.tween_property(padlock, "scale", Vector2(1.15, 1.15), 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_padlock_pulse_tween.tween_property(padlock, "scale", Vector2(0.9, 0.9), 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).from_current()
	_padlock_pulse_tween.set_loops(-1)

func _stop_padlock_pulse():
	if _padlock_pulse_tween:
		_padlock_pulse_tween.kill()
		_padlock_pulse_tween = null

func _create_contamination_effect():
	if mold_sprite:
		var tween = create_tween()
		tween.tween_property(mold_sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(mold_sprite, "modulate", Color.WHITE, 0.3)

func _trigger_wrong_metal_flash(_wrong_metal: String):
	# Distinct pre-contamination flash: orange warning before red contamination
	if mold_sprite:
		var tween = create_tween()
		tween.tween_property(mold_sprite, "modulate", Color.ORANGE, 0.08)
		tween.tween_property(mold_sprite, "modulate", Color.RED, 0.08)

func _create_receiving_glow(metal_id: String):
	# Brief bright flash when metal enters the mold
	if mold_sprite:
		var color = MetalDefinition.get_color(metal_id)
		var tween = create_tween()
		tween.tween_property(mold_sprite, "modulate", color * 1.5, 0.1)
		tween.tween_property(mold_sprite, "modulate", color * 0.7, 0.2)

func _animate_hardening():
	# Flash WHITE (0.1s) -> desaturate to gray-blue (0.3s) -> darken to cool steel (0.4s)
	# Scale: slight shrink to 0.95 (0.2s, ease_in)
	if mold_sprite:
		var tween = create_tween()
		tween.set_parallel(false)
		# Flash white
		tween.tween_property(mold_sprite, "modulate", Color.WHITE, 0.1)
		# Desaturate to gray-blue
		tween.tween_property(mold_sprite, "modulate", Color(0.7, 0.72, 0.75), 0.3)
		# Darken to final cooled color
		tween.tween_property(mold_sprite, "modulate", Color(0.5, 0.55, 0.6), 0.4)
		# Scale shrink with ease_in
		var scale_tween = create_tween()
		scale_tween.tween_property(mold_sprite, "scale", Vector2(0.95, 0.95), 0.2).set_ease(Tween.EASE_IN)

func _animate_complete_settle():
	# Scale back to 1.0 (0.2s, elastic ease)
	# Label already set to "Done!" in green by _update_display
	if mold_sprite:
		var tween = create_tween()
		tween.tween_property(mold_sprite, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

func _create_complete_effect():
	if mold_sprite:
		var tween = create_tween()
		tween.set_parallel(false)
		# Chain: flash (0.1s) -> desaturate (0.2s) -> darken (0.3s) = 0.6s, then scale bounce
		# Flash white
		tween.tween_property(mold_sprite, "modulate", Color.WHITE, 0.1)
		# Desaturate to gray-blue
		tween.tween_property(mold_sprite, "modulate", Color(0.7, 0.72, 0.75), 0.2)
		# Darken to cool steel
		tween.tween_property(mold_sprite, "modulate", Color(0.5, 0.55, 0.6), 0.3)
		# Scale bounce (0.2s) with elastic ease
		tween.tween_property(mold_sprite, "scale", Vector2(1.2, 1.2), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		tween.tween_property(mold_sprite, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func _create_clear_effect():
	if mold_sprite:
		var tween = create_tween()
		tween.tween_property(mold_sprite, "modulate", Color.BLUE * 0.3, 0.2)
		tween.tween_property(mold_sprite, "modulate", Color.WHITE, 0.2)
