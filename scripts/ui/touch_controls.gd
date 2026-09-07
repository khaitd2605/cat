class_name TouchControls
extends CanvasLayer
## On-screen buttons for the verbs that only exist on the keyboard.
##
## The game was built for a mouse and a keyboard. On a phone a tap already reads
## as a click (`emulate_mouse_from_touch` is on), so carrying a domino - press,
## drag, release - works untouched. What has no touch equivalent is SHIFT (lean
## in), SPACE (shield) and ENTER (push), and without those three the run cannot
## be finished at all: the player gets stuck on the first piece.
##
## ENTER is the only one that is strictly redundant - tapping the START peg
## already triggers the run - but the peg is a small target on a phone and the
## hint line names the key, so it gets a button of its own.
##
## The panel builds itself ONLY on a touch device, so a desktop player never
## sees it and the room stays uncluttered. F2 (cheat) is deliberately left out.

## Kept generous: a finger is not a cursor, and these sit over a live desk where
## a mis-tap costs the run.
const BUTTON_SIZE := Vector2(132, 74)
const EDGE := 22

@export var task_path: NodePath
@export var focus_path: NodePath
@export var controls_path: NodePath

var _task: Node
var _focus: FocusSystem3D
var _controls: PlayerControls
var _root: Control
var _lean: Button
var _shield: Button

func _ready() -> void:
	# Not `visible = false`: on desktop this node has no reason to keep ticking a
	# _process that polls three buttons which will never exist.
	if not DisplayServer.is_touchscreen_available():
		queue_free()
		return
	_task = get_node(task_path)
	_focus = get_node(focus_path) as FocusSystem3D
	_controls = get_node(controls_path) as PlayerControls
	_build()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Left and right corners, never the middle: the desk the player is placing on
	# runs across the bottom of the frame, and a button parked there would eat the
	# taps meant for it.
	_lean = _pad("NHÌN GẦN")
	_root.add_child(_lean)
	_lean.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, EDGE)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	_root.add_child(right)
	right.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, EDGE)

	var push := _pad("ĐẨY DÂY")
	# Self-guarding: it refuses politely (and says why) if the chain is not ready,
	# so the button needs no conditions of its own.
	push.pressed.connect(_task._trigger_run)
	right.add_child(push)

	_shield = _pad("CHE CHẮN")
	right.add_child(_shield)

## The two hold buttons are polled rather than wired to button_down/button_up:
## a finger that slides off the button mid-hold would otherwise leave the shield
## stuck on, which silently blocks every further placement.
func _process(_delta: float) -> void:
	var playing := GameManager.is_playing()
	# The HUD's win/fail card sits on a lower layer than this one, so without this
	# the buttons would float on top of the result screen.
	_root.visible = playing
	_focus.zoom_held = playing and _lean.button_pressed
	_controls.set_touch_shield(playing and _shield.button_pressed)

func _pad(text: String) -> Button:
	var b := UiTheme.button(text, 16, BUTTON_SIZE)
	# Held buttons, not tapped ones: without this the shield would drop the moment
	# the finger drifted a pixel off the edge.
	b.keep_pressed_outside = true
	b.modulate.a = 0.88
	return b
