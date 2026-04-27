extends Node

var metals: Dictionary = {}
var molds: Dictionary = {}
var orders: Array[OrderDefinition] = []

func _ready():
	_setup_metals()
	_setup_molds()
	_setup_orders()

func _setup_metals():
	metals["iron"] = MetalDefinition.new("iron", "Iron", 1.0, 1.0, 1)
	metals["steel"] = MetalDefinition.new("steel", "Steel", 0.7, 1.5, 2)
	metals["gold"] = MetalDefinition.new("gold", "Gold", 0.5, 2.0, 5)

func _setup_molds():
	molds["blade"] = MoldDefinition.new("blade", "Blade", "iron", 100.0)
	molds["guard"] = MoldDefinition.new("guard", "Guard", "iron", 80.0)
	molds["grip"] = MoldDefinition.new("grip", "Grip", "iron", 60.0)

func _setup_orders():
	var iron_parts: Array[String] = ["iron_blade", "iron_guard", "iron_grip"]
	var steel_parts: Array[String] = ["steel_blade", "iron_guard", "iron_grip"]
	var noble_parts: Array[String] = ["steel_blade", "gold_guard", "iron_grip"]

	orders.append(OrderDefinition.new("order_1", "Iron Sword", iron_parts, 100))
	orders.append(OrderDefinition.new("order_2", "Steel Sword", steel_parts, 160))
	orders.append(OrderDefinition.new("order_3", "Noble Sword", noble_parts, 250))

func get_metal(metal_id: String) -> MetalDefinition:
	return metals.get(metal_id)

func get_mold(mold_id: String) -> MoldDefinition:
	return molds.get(mold_id)

func get_order(index: int) -> OrderDefinition:
	if index >= 0 and index < orders.size():
		return orders[index]
	return null
