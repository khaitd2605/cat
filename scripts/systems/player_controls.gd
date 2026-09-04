class_name PlayerControls
extends Node
## Non-click player verbs. Right now: the hand shield (hold Space or the right
## mouse button) that protects the dominoes from a gust but blocks placing.

@export var task_path: NodePath

var _task: Node
var _key_held := false
var _mouse_held := false

func _ready() -> void:
	_task = get_node(task_path)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SPACE and not event.echo:
		_key_held = event.pressed
		_apply()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_mouse_held = event.pressed
		_apply()

func _apply() -> void:
	var want := (_key_held or _mouse_held) and GameManager.is_playing()
	if want != _task.shield_active:
		_task.set_shield(want)
		if want:
			Sfx.play("thud", -18.0)

func _process(_delta: float) -> void:
	if _task.shield_active and not GameManager.is_playing():
		_task.set_shield(false)
