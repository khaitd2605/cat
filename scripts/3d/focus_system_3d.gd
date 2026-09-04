class_name FocusSystem3D
extends Node
## FOCUS vs AWARENESS for the 3D scene.
##
## The camera does NOT move on its own: chasing every pick-up made the view
## lurch in and out constantly. Instead:
##   - carrying a domino dims the edges of the screen (vignette), so the cat and
##     the window at the rim are easy to miss - that is the cost of focus;
##   - the player zooms voluntarily: hold SHIFT (or scroll the wheel) to lean in.
## Time never stops in either mode.

@export var task_path: NodePath
@export var camera_path: NodePath
@export var home_pos := Vector3(0.0, 7.4, 8.6)
@export var look_at_point := Vector3(0.0, 0.6, -0.6)
@export var base_fov := 48.0
## Voluntary zoom: how far SHIFT / the wheel can narrow the field of view.
@export var min_fov := 32.0
@export var zoom_speed := 3.0
## Vignette while carrying (kept gentle - it must not feel like a blindfold).
@export var vignette_strength := 0.55

var is_focus := false
var focus_amount := 0.0
var zoom := 0.0            # 0 = wide, 1 = leaned in
var _task: Node
var _camera: Camera3D
var _rect: ColorRect
var _mat: ShaderMaterial
var _wheel_zoom := 0.0

func _ready() -> void:
	_task = get_node(task_path)
	_camera = get_node(camera_path)
	_camera.position = home_pos
	_camera.look_at(look_at_point)
	_camera.fov = base_fov
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://scripts/systems/focus_vignette.gdshader")
	_mat.set_shader_parameter("center", Vector2(0.5, 0.5))
	_mat.set_shader_parameter("strength", 0.0)
	_rect.material = _mat
	_rect.visible = false
	layer.add_child(_rect)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_wheel_zoom = clamp(_wheel_zoom + 0.15, 0.0, 1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_wheel_zoom = clamp(_wheel_zoom - 0.15, 0.0, 1.0)

func _process(delta: float) -> void:
	var want: bool = _task.is_focusing() and GameManager.is_playing()
	if want != is_focus:
		is_focus = want
		EventBus.focus_changed.emit(is_focus)
	focus_amount = move_toward(focus_amount, 1.0 if is_focus else 0.0, delta * 2.5)

	# voluntary zoom only: SHIFT held, or wheel notches
	var target_zoom: float = maxf(_wheel_zoom, 1.0 if Input.is_key_pressed(KEY_SHIFT) else 0.0)
	zoom = move_toward(zoom, target_zoom, delta * zoom_speed)
	_camera.position = home_pos
	_camera.look_at(look_at_point)
	_camera.fov = lerpf(base_fov, min_fov, ease(zoom, -1.4))

	var strength := ease(focus_amount, -1.6) * vignette_strength
	_mat.set_shader_parameter("strength", strength)
	_rect.visible = strength > 0.001
