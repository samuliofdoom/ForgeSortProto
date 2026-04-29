## GateDebugHUD — ForgeSortProto Debug Overlay
## Shows live gate/open intake state for playtesting.
## Toggle visibility: F3 key (editor/debug) or set `visible = true/false` programmatically.

extends CanvasLayer

const GATE_LABELS := {
	"gate_01": "G1",
	"gate_02": "G2",
	"gate_03": "G3",
	"gate_04": "G4",
}

const INTAKE_LABELS := {
	"intake_a": "A",
	"intake_b": "B",
	"intake_c": "C",
}

const GATE_INTAKE_MAP := {
	"gate_01": ["A", "B"],
	"gate_02": ["B", "C"],
	"gate_03": ["A", "C"],
	"gate_04": ["C"],
}

const OPEN_COLOR  := Color("#22cc66")
const CLOSED_COLOR := Color("#cccccc")
const ROUTED_COLOR := Color("cyan")
const WARN_COLOR  := Color("orange")

var flow_controller: Node

var _panel: Panel
var _gate_rows: Dictionary  # gate_id -> {label: Label, intake_label: Label}
var _routing_label: Label
var _visible: bool = true

func _ready() -> void:
	visible = false  # Off by default; toggle with F1
	flow_controller = get_node_or_null("/root/FlowController")
	if flow_controller:
		flow_controller.gate_toggled.connect(_on_gate_toggled)
		# Also sync when mold orders change (routing may shift)
		var order_manager = get_node_or_null("/root/OrderManager")
		if order_manager and order_manager.has_signal("order_started"):
			order_manager.order_started.connect(_on_order_started)

	_build_ui()
	call_deferred("_refresh")  # defer so all nodes are fully registered first

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F3:
				visible = not visible
				if visible:
					_refresh()

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.z_index = 1000
	add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.85)
	style.set_border_width_all(1)
	style.border_color = Color(0.4, 0.4, 0.4, 0.6)
	style.set_corner_radius_all(4)
	style.content_margin_left   = 8
	style.content_margin_right  = 8
	style.content_margin_top    = 6
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)

	# Title row
	var title := Label.new()
	title.text = "GATE DEBUG  [F3]"
	title.add_theme_font_size_override("font_size", 10)
	title.modulate = Color(0.7, 0.7, 0.7)
	_panel.add_child(title)

	# Gate rows
	_gate_rows = {}
	for gate_id in ["gate_01", "gate_02", "gate_03", "gate_04"]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		_panel.add_child(row)

		var gate_lbl := Label.new()
		gate_lbl.text = GATE_LABELS[gate_id]
		gate_lbl.custom_minimum_size = Vector2(16, 0)
		gate_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(gate_lbl)

		var state_lbl := Label.new()
		state_lbl.text = "CLOSED"
		state_lbl.add_theme_font_size_override("font_size", 10)
		row.add_child(state_lbl)

		var spacer := Label.new()
		spacer.text = " "
		spacer.custom_minimum_size = Vector2(6, 0)
		row.add_child(spacer)

		var intake_lbl := Label.new()
		intake_lbl.text = ""
		intake_lbl.add_theme_font_size_override("font_size", 9)
		intake_lbl.modulate = Color(0.55, 0.55, 0.55)
		row.add_child(intake_lbl)

		_gate_rows[gate_id] = {
			"gate_label":  gate_lbl,
			"state_label": state_lbl,
			"intake_lbl":  intake_lbl,
		}

	# Separator
	var sep := Label.new()
	sep.text = ""
	sep.custom_minimum_size = Vector2(0, 4)
	_panel.add_child(sep)

	# Routing hint row
	var hint_title := Label.new()
	hint_title.text = "ROUTE:"
	hint_title.add_theme_font_size_override("font_size", 9)
	hint_title.modulate = Color(0.5, 0.5, 0.5)
	_panel.add_child(hint_title)

	_routing_label = Label.new()
	_routing_label.text = ""
	_routing_label.add_theme_font_size_override("font_size", 9)
	_routing_label.modulate = ROUTED_COLOR
	_routing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_routing_label)

	# Layout: anchor to top-right
	_update_layout()

func _update_layout() -> void:
	var vp: Viewport = get_viewport()
	var ui_size: Vector2 = vp.get_visible_rect().size
	var panel_w := 110.0
	var panel_h := 120.0
	_panel.position = Vector2(ui_size.x - panel_w - 10.0, 10.0)
	_panel.custom_minimum_size = Vector2(panel_w, panel_h)

func _process(_delta: float) -> void:
	if visible and _panel:
		_update_layout()

func _on_gate_toggled(_gate_id: String, _state: bool) -> void:
	if not visible:
		return
	_refresh()

func _on_order_started(_order: Object) -> void:
	if not visible:
		return
	_refresh()

func _refresh() -> void:
	if not flow_controller or not _gate_rows:
		return

	# Update each gate row
	for gate_id in ["gate_01", "gate_02", "gate_03", "gate_04"]:
		var is_open: bool = flow_controller.get_gate_state(gate_id)
		var row: Dictionary = _gate_rows[gate_id]
		var state_lbl: Label = row["state_label"]
		var intake_lbl: Label = row["intake_lbl"]

		if is_open:
			state_lbl.text = "OPEN "
			state_lbl.modulate = OPEN_COLOR
			intake_lbl.text = "(" + ",".join(GATE_INTAKE_MAP[gate_id]) + ")"
			intake_lbl.modulate = OPEN_COLOR
		else:
			state_lbl.text = "CLOSED"
			state_lbl.modulate = CLOSED_COLOR
			intake_lbl.text = "(" + ",".join(GATE_INTAKE_MAP[gate_id]) + ")"
			intake_lbl.modulate = Color(0.4, 0.4, 0.4)

	# Routing hint: which molds are currently reachable.
	# Compute directly from gate state to avoid spamming get_mold_for_intake's
	# warning on every _refresh cycle (gates are often all-closed during play).
	var routed_parts := []
	var open_intakes: Array[String] = []
	for gate_id in ["gate_01", "gate_02", "gate_03", "gate_04"]:
		if flow_controller.get_gate_state(gate_id):
			for intake_id in FlowController.GATE_ROUTING[gate_id]:
				if not open_intakes.has(intake_id):
					open_intakes.append(intake_id)

	for mold_id in ["blade", "guard", "grip"]:
		var mold_intakes: Array[String] = []
		for intake_id in open_intakes:
			if FlowController.INTAKE_TO_MOLD.get(intake_id, "") == mold_id:
				var intake_name: String = INTAKE_LABELS.get(intake_id, intake_id)
				if not mold_intakes.has(intake_name):
					mold_intakes.append(intake_name)
		if mold_intakes.size() > 0:
			routed_parts.append("%s[A%s]" % [mold_id.capitalize(), ",".join(mold_intakes)])

	if routed_parts.size() > 0:
		_routing_label.text = ", ".join(routed_parts)
		_routing_label.modulate = ROUTED_COLOR
	else:
		_routing_label.text = "(no route)"
		_routing_label.modulate = WARN_COLOR
