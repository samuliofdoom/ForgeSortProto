extends StaticBody2D

signal gate_toggled(gate_id: String, is_open: bool)
signal gate_interacted(gate_id: String)

@export var gate_id: String = "gate_01"
@export var is_open: bool = false

@onready var visual: ColorRect = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D

var flow_controller: Node
var _tooltip_label: Label = null
var _tooltip_panel: Panel = null
var _is_hovered: bool = false

func _ready():
	input_pickable = true
	flow_controller = get_node_or_null("/root/FlowController")
	# Gate state is synced via FlowController.toggle_gate() + gate_toggled signal

	_setup_tooltip()
	# Use built-in mouse signals from Area2D/StaticBody2D for hover detection
	mouse_entered.connect(_on_gate_mouse_entered)
	mouse_exited.connect(_on_gate_mouse_exited)

func _setup_tooltip():
	# Build a small floating panel + label showing which molds the gate feeds
	_tooltip_panel = Panel.new()
	_tooltip_panel.name = "TooltipPanel"
	_tooltip_panel.z_index = 200
	# Stylebox for dark background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.92)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	_tooltip_panel.add_theme_stylebox_override("panel", style)
	add_child(_tooltip_panel)

	_tooltip_label = Label.new()
	_tooltip_label.name = "TooltipLabel"
	_tooltip_label.text = _get_tooltip_text()
	_tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tooltip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tooltip_panel.add_child(_tooltip_label)

	_tooltip_panel.hide()

func _get_tooltip_text() -> String:
	# Show which mold(s) this gate feeds based on GATE_ROUTING
	var flow_ctrl = get_node_or_null("/root/FlowController")
	if not flow_ctrl:
		return gate_id
	var intakes = flow_ctrl.GATE_ROUTING.get(gate_id, [])
	if intakes.is_empty():
		return gate_id
	var parts: Array[String] = []
	for intake in intakes:
		var mold = flow_ctrl.INTAKE_TO_MOLD.get(intake, intake)
		if not parts.has(mold):
			parts.append(mold)
	return "→ " + " + ".join(parts)

func toggle():
	is_open = not is_open
	_update_visual()
	# Use toggle_gate to centralize state + signal in FlowController
	# FlowController.toggle_gate() emits gate_toggled on FlowController
	# (Gate's own gate_toggled signal is for internal use only, e.g. self-updates)
	if flow_controller:
		flow_controller.toggle_gate(gate_id)

func _on_gate_toggled(p_gate_id: String, p_is_open: bool):
	if p_gate_id == self.gate_id:
		is_open = p_is_open
		_update_visual()

func _update_visual():
	if visual:
		# Kill any running previous tween before creating a new one to prevent conflicts on rapid toggles
		if visual.has_meta("_tween"):
			visual.get_meta("_tween").kill()
			visual.remove_meta("_tween")

	# Animated tween: elastic ease rotation + color fade white<->green
	var tween = visual.create_tween()
	tween.set_parallel(true)

	var target_rotation = PI / 4 if is_open else 0
	var target_color = Color.GREEN * 0.8 if is_open else Color.WHITE * 0.8

	tween.tween_property(visual, "rotation", target_rotation, 0.25)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)

	tween.tween_property(visual, "modulate", target_color, 0.25)

	visual.set_meta("_tween", tween)

	# Add/remove/tween glow light based on open state
	# FEATURE-009: keep the PointLight2D node, tween energy 0→0.6 / 0.6→0
	# instead of instant add/remove (which caused a visible pop)
	if not visual.has_node("GateLight"):
		var light = PointLight2D.new()
		light.name = "GateLight"
		light.color = Color.GREEN
		light.energy = 0.0  # start invisible
		light.texture_scale = 2.0
		light.height = 1.0
		visual.add_child(light)

	var light: PointLight2D = visual.get_node("GateLight")
	# Kill any prior energy tween to prevent accumulation on rapid toggles
	if light.has_meta("_energy_tween"):
		light.get_meta("_energy_tween").kill()
		light.remove_meta("_energy_tween")

	var target_energy = 0.6 if is_open else 0.0
	var et = light.create_tween()
	et.tween_property(light, "energy", target_energy, 0.3)
	et.set_ease(Tween.EASE_OUT)
	et.set_trans(Tween.TRANS_SINE)
	light.set_meta("_energy_tween", et)

	# Physics: disable collision when open so blobs pass through.
	# Closed gate = physical barrier (blob bounces off).
	# Layer 2 = gate blocker — set on the shape so blobs can detect it.
	if collision:
		collision.disabled = not is_open
		# Set collision layer: layer index 2 (0-indexed = bit 1 = 0b0010)
		# This MUST be set for blobs (layer 1, mask includes layer 2) to detect it.
		self.set_collision_layer_value(2, true)

func get_gate_id() -> String:
	return gate_id

func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed:
			var world_pos = get_global_mouse_position()
			var gate_rect = Rect2(global_position - Vector2(15, 35), Vector2(30, 70))
			if gate_rect.has_point(world_pos):
				toggle()
				gate_interacted.emit(gate_id)

func _on_gate_mouse_entered():
	_show_tooltip()

func _on_gate_mouse_exited():
	_hide_tooltip()

func _show_tooltip():
	if not _tooltip_panel or _tooltip_panel.visible:
		return
	# Refresh text in case gate routing changed
	_tooltip_label.text = _get_tooltip_text()
	# Size panel to fit text (Godot 4: Label sizes itself based on container)
	_tooltip_label.size = Vector2(80, 20)
	_tooltip_panel.size = Vector2(88, 26)
	# Position above the gate
	_tooltip_panel.position = Vector2(-44, -70)
	_tooltip_panel.show()

func _hide_tooltip():
	if _tooltip_panel:
		_tooltip_panel.hide()
