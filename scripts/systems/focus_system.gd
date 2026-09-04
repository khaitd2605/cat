class_name FocusSystem
extends Node
## FOCUS vs AWARENESS.
##
## FOCUS  (dragging a domino): the camera pushes in on the work spot and the
##        edges of the room fall into shadow. Precise work, poor overview.
## AWARENESS (hands free): the camera pulls back to the whole desk and room.
##        Signals are easy to see and objects show their status on hover.
## Time never stops in either mode.

@export var task_path: NodePath
@export var camera_path: NodePath
@export var focus_zoom := 1.7
@export var awareness_zoom := 1.0
@export var room_center := Vector2(640, 400)
@export var vignette_strength := 0.85
@export var vignette_center_uv := Vector2(0.5, 0.5)

var is_focus := false
var focus_amount := 0.0

var _task: Node
var _camera: Camera2D
var _rect: ColorRect
var _mat: ShaderMaterial

func _ready() -> void:
	_task = get_node(task_path)
	_camera = get_node(camera_path)
	_camera.position = room_center
	# vignette lives on its own canvas layer between the world and the HUD
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://scripts/systems/focus_vignette.gdshader")
	_mat.set_shader_parameter("center", vignette_center_uv)
	_mat.set_shader_parameter("strength", 0.0)
	_rect.material = _mat
	_rect.visible = false
	layer.add_child(_rect)

func _process(delta: float) -> void:
	var want := _task.is_focusing() and GameManager.is_playing()
	if want != is_focus:
		is_focus = want
		EventBus.focus_changed.emit(is_focus)
	focus_amount = move_toward(focus_amount, 1.0 if is_focus else 0.0, delta * (2.2 if is_focus else 1.8))
	var eased := ease(focus_amount, -1.6)
	# camera: room centre <-> work spot (keep the work spot on the desk area)
	var target := room_center.lerp(_task.focus_point_global(), eased * 0.85)
	_camera.position = _camera.position.lerp(target, min(delta * 6.0, 1.0))
	var zoom := lerpf(awareness_zoom, focus_zoom, eased)
	_camera.zoom = Vector2(zoom, zoom)
	var strength := eased * vignette_strength
	_mat.set_shader_parameter("strength", strength)
	_rect.visible = strength > 0.001
