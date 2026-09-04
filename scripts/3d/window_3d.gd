class_name Window3D
extends InteractableObject3D
## Window on the back wall. The right sash swings open when the wind event
## starts; click to close. Same API as the 2D WindowObject: set_open(), is_open.

signal opened
signal closed

var is_open := false
var _sash: Node3D
var _open_t := 0.0

func _ready() -> void:
	hit_size = Vector3(3.6, 3.0, 0.6)
	hit_offset = Vector3(0, 1.5, 0)
	super._ready()
	hover_label = "Cửa sổ"
	_build()

func _build() -> void:
	var frame := Color(0.36, 0.22, 0.13)
	# glass (fixed left pane) and frame pieces
	add_child(box(Vector3(3.6, 0.15, 0.3), frame, Vector3(0, 0, 0)))
	add_child(box(Vector3(3.6, 0.15, 0.3), frame, Vector3(0, 3.0, 0)))
	add_child(box(Vector3(0.15, 3.0, 0.3), frame, Vector3(-1.8, 1.5, 0)))
	add_child(box(Vector3(0.15, 3.0, 0.3), frame, Vector3(1.8, 1.5, 0)))
	add_child(box(Vector3(0.12, 3.0, 0.2), frame, Vector3(0, 1.5, 0)))
	add_child(box(Vector3(4.2, 0.12, 0.7), Color(0.5, 0.33, 0.2), Vector3(0, -0.06, 0.2)))  # sill
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.3, 0.5, 0.6, 0.45)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.emission_enabled = true
	glass_mat.emission = Color(0.2, 0.4, 0.5)
	glass_mat.emission_energy_multiplier = 0.35
	var left := box(Vector3(1.7, 2.8, 0.04), Color.WHITE, Vector3(-0.9, 1.5, 0))
	left.material_override = glass_mat
	add_child(left)
	add_child(box(Vector3(0.08, 2.8, 0.1), frame, Vector3(-0.9, 1.5, 0)))
	add_child(box(Vector3(1.7, 0.08, 0.1), frame, Vector3(-0.9, 1.5, 0)))
	# the sash: pivot at x = 0 (the mullion), swings outward (-z)
	_sash = Node3D.new()
	_sash.position = Vector3(0.06, 0, 0)
	add_child(_sash)
	var right := box(Vector3(1.7, 2.8, 0.04), Color.WHITE, Vector3(0.87, 1.5, 0))
	right.material_override = glass_mat
	_sash.add_child(right)
	_sash.add_child(box(Vector3(1.75, 0.12, 0.14), frame, Vector3(0.87, 0.1, 0)))
	_sash.add_child(box(Vector3(1.75, 0.12, 0.14), frame, Vector3(0.87, 2.9, 0)))
	_sash.add_child(box(Vector3(0.12, 2.9, 0.14), frame, Vector3(1.72, 1.5, 0)))
	_sash.add_child(box(Vector3(0.08, 2.8, 0.1), frame, Vector3(0.87, 1.5, 0)))
	_sash.add_child(box(Vector3(1.7, 0.08, 0.1), frame, Vector3(0.87, 1.5, 0)))
	# night outside: dark blue plane behind
	var night := box(Vector3(3.4, 2.8, 0.02), Color(0.1, 0.2, 0.28), Vector3(0, 1.5, -0.6))
	add_child(night)
	for p in [Vector3(-1.2, 0.9, -0.5), Vector3(1.2, 0.8, -0.5), Vector3(0.0, 0.6, -0.5)]:
		add_child(sphere(0.4, Color(0.12, 0.26, 0.18), p))

func set_open(open: bool) -> void:
	if is_open == open:
		return
	is_open = open
	hover_label = "Đóng cửa sổ" if open else "Cửa sổ"
	if open:
		opened.emit()
	else:
		closed.emit()

func _process(delta: float) -> void:
	super._process(delta)
	_open_t = move_toward(_open_t, 1.0 if is_open else 0.0, delta * 2.5)
	_sash.rotation.y = -_open_t * 1.1
