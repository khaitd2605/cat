class_name InteractableObject
extends Area2D
## Base for anything the player can click in the room. Builds its own
## collision box from `hit_size`, tracks hover and emits `interacted`.

signal interacted

@export var hit_size := Vector2(100, 100)
@export var hit_offset := Vector2.ZERO
## Text drawn under the cursor when hovered (subclasses may change it at runtime).
var hover_label := ""
## What this object is doing right now (set by events). Shown under the label
## when the player looks at it - the AWARENESS payoff.
var status_text := ""
var hovered := false

var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	input_pickable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = hit_size
	shape.shape = rect
	shape.position = hit_offset
	add_child(shape)
	mouse_entered.connect(func(): hovered = true; queue_redraw())
	mouse_exited.connect(func(): hovered = false; queue_redraw())
	input_event.connect(_on_input_event)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if GameManager.is_playing():
			if OS.is_debug_build():
				print("[interact] %s clicked at %s" % [name, event.position])
			interacted.emit()
			get_viewport().set_input_as_handled()

## Helper for subclasses: draw the hover ring + label.
func draw_hover(center: Vector2, radius: float) -> void:
	if not hovered or hover_label == "":
		return
	var pulse := 0.6 + 0.3 * sin(Time.get_ticks_msec() / 150.0)
	draw_arc(center, radius, 0, TAU, 40, Color(1.0, 0.85, 0.4, pulse), 3.0)
	var w := 260.0
	var pos := center + Vector2(-w / 2, radius + 26)
	var lines := 2 if status_text != "" else 1
	draw_rect(Rect2(pos + Vector2(0, -20), Vector2(w, 10 + 20 * lines)), Color(0.1, 0.07, 0.05, 0.85))
	draw_string(_font, pos, hover_label, HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color(1, 0.92, 0.7))
	if status_text != "":
		draw_string(_font, pos + Vector2(0, 20), status_text, HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(1, 0.75, 0.5))
