## MetalBlob — a physics-simulated droplet of molten metal.
## Falls with gravity, bounces off closed gates, passes through open gates,
## and lands in molds. Self-removes after a timeout or when it enters a mold.

class_name MetalBlob
extends RigidBody2D

signal entered_mold(mold_id: String, metal_id: String)

# Physics layers:
#   layer 1 = blobs (what we collide WITH via body_entered)
#   layer 2 = gate blockers
const BLOB_LAYER = 0b0001       # we exist on layer 1
const GATE_LAYER = 0b0010       # gate blockers are on layer 2

var _metal_id: String = "iron"
var _mold_id: String = ""
var _lifetime: float = 0.0
var _max_lifetime: float = 8.0
var _has_landed: bool = false

func _init():
	pass  # freeze_mode = disabled (0) is default — physics engine drives the blob

func setup(metal_id: String, spawn_pos: Vector2, mold_id: String = "") -> void:
	_metal_id = metal_id
	_mold_id = mold_id
	global_position = spawn_pos
	contact_monitor = true

	# Collision: detect gate blockers (layer 2) and mold catchers (Area2D)
	collision_layer = BLOB_LAYER          # we appear on layer 1
	collision_mask  = BLOB_LAYER | GATE_LAYER  # we detect layers 1 and 2

	# Appearance based on metal type
	match metal_id:
		"iron":
			modulate = Color(0.85, 0.3, 0.05)
		"steel":
			modulate = Color(0.8, 0.85, 0.95)
		"gold":
			modulate = Color(1.0, 0.9, 0.3)
		_:
			modulate = Color(0.9, 0.6, 0.2)

	# Blob size varies slightly per drop for visual interest
	var r = randf_range(4.0, 7.0)

	# Collision shape
	var shape = CircleShape2D.new()
	shape.radius = r
	var col = CollisionShape2D.new()
	col.shape = shape
	col.name = "BlobCollision"
	add_child(col)

	# Visible blob circle
	var blob = ColorRect.new()
	blob.name = "BlobVisual"
	blob.size = Vector2(r * 2, r * 2)
	blob.position = Vector2(-r, -r)
	blob.color = modulate
	add_child(blob)

	# Blob physics: falls with gravity, bounces slightly
	gravity_scale = 1.0
	linear_damp = 0.3

func get_metal_id() -> String:
	return _metal_id

func _physics_process(delta: float) -> void:
	_lifetime += delta
	if _lifetime > _max_lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	# RigidBody2D uses body_entered, NOT area_entered
	if _has_landed:
		return

	# Check if it's the Mold's BlobCatcher Area2D
	if body is Area2D and body.name == "BlobCatcher":
		_has_landed = true
		entered_mold.emit(_mold_id, _metal_id)
		queue_free()
