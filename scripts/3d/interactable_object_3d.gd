class_name InteractableObject3D
extends Area3D
## Base for clickable room objects in the 3D scene. Builds its own box
## collider, tracks hover (camera ray picking) and shows a floating label with
## the object's current status - the AWARENESS payoff.

signal interacted

@export var hit_size := Vector3(1, 1, 1)
@export var hit_offset := Vector3.ZERO

var hover_label := ""
var status_text := ""
var hovered := false
var _label: Label3D

func _ready() -> void:
	input_ray_pickable = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = hit_size
	shape.shape = box
	shape.position = hit_offset
	add_child(shape)
	_label = Label3D.new()
	_label.pixel_size = 0.004
	_label.font_size = 30
	_label.outline_size = 8
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.visible = false
	_label.position = hit_offset + Vector3(0, hit_size.y * 0.5 + 0.6, 0)
	add_child(_label)
	mouse_entered.connect(func(): hovered = true)
	mouse_exited.connect(func(): hovered = false)
	input_event.connect(_on_input_event)

func _process(_delta: float) -> void:
	_label.visible = hovered and hover_label != ""
	if _label.visible:
		_label.text = hover_label if status_text == "" else "%s\n%s" % [hover_label, status_text]
		_label.modulate = Color(1, 0.92, 0.7) if status_text == "" else Color(1, 0.8, 0.55)

func _on_input_event(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if GameManager.is_playing():
			interacted.emit()
			get_viewport().set_input_as_handled()

# helpers for subclasses
static func box(size: Vector3, col: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	m.material_override = mat
	m.position = pos
	return m

static func sphere(r: float, col: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	m.material_override = mat
	m.position = pos
	return m
