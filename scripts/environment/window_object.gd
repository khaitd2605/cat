class_name WindowObject
extends InteractableObject
## The window. Closed by default; the WindEvent pops it open, the player
## clicks it (or uses the action button) to shut it.

signal opened
signal closed

var is_open := false
var _open_t := 0.0   # animated 0..1

const W := 320.0
const H := 230.0

func _ready() -> void:
	hit_size = Vector2(W + 40, H + 40)
	super._ready()
	hover_label = "Cửa sổ"

func set_open(open: bool) -> void:
	if is_open == open:
		return
	is_open = open
	hover_label = "Đóng cửa sổ" if open else "Cửa sổ"
	if open:
		opened.emit()
	else:
		closed.emit()
	queue_redraw()

func _process(delta: float) -> void:
	var target := 1.0 if is_open else 0.0
	if abs(_open_t - target) > 0.001:
		_open_t = move_toward(_open_t, target, delta * 3.0)
		queue_redraw()
	elif hovered:
		queue_redraw()

func _draw() -> void:
	var half := Vector2(W, H) * 0.5
	var frame := Color(0.36, 0.22, 0.13)
	var frame_light := Color(0.5, 0.33, 0.2)
	# outer frame + sill
	draw_rect(Rect2(-half - Vector2(16, 16), Vector2(W + 32, H + 32)), frame)
	draw_rect(Rect2(Vector2(-half.x - 30, half.y + 8), Vector2(W + 60, 22)), frame_light)
	draw_rect(Rect2(Vector2(-half.x - 30, half.y + 26), Vector2(W + 60, 6)), Color(0.25, 0.15, 0.09))
	# night sky with a soft glow at the top
	draw_rect(Rect2(-half, Vector2(W, H)), Color(0.22, 0.42, 0.5))
	draw_rect(Rect2(-half, Vector2(W, H * 0.45)), Color(0.42, 0.62, 0.68, 0.8))
	# tree blobs
	var leaf := Color(0.15, 0.32, 0.22, 0.9)
	for blob in [Vector2(-110, -30), Vector2(-70, 10), Vector2(-135, 40), Vector2(120, -60), Vector2(140, -10), Vector2(95, 30)]:
		draw_circle(blob, 34, leaf)
		draw_circle(blob + Vector2(-8, -10), 20, Color(0.25, 0.45, 0.28, 0.8))
	# mullions
	draw_rect(Rect2(Vector2(-6, -half.y), Vector2(12, H)), frame)
	draw_rect(Rect2(Vector2(-half.x, -6), Vector2(W, 12)), frame)
	# glass panes: closed = flat reflection, open = right sash swung outward
	var glass := Color(0.85, 0.95, 1.0, 0.16)
	draw_rect(Rect2(-half, Vector2(W * 0.5 - 6, H)), glass)
	if _open_t < 0.999:
		draw_rect(Rect2(Vector2(6, -half.y), Vector2(W * 0.5 - 6, H)), Color(glass, glass.a * (1.0 - _open_t)))
		draw_line(Vector2(20, -half.y + 10), Vector2(half.x - 20, half.y - 40), Color(1, 1, 1, 0.12 * (1.0 - _open_t)), 6.0)
	if _open_t > 0.001:
		var sw := lerpf(0.0, 90.0, _open_t)
		var sash := PackedVector2Array([
			Vector2(6, -half.y), Vector2(6 + sw, -half.y - sw * 0.35),
			Vector2(6 + sw, half.y + sw * 0.35), Vector2(6, half.y)])
		draw_colored_polygon(sash, Color(0.75, 0.9, 1.0, 0.28))
		draw_polyline(sash, frame_light, 6.0)
		draw_line(sash[0], sash[3], frame_light, 6.0)
	draw_hover(Vector2.ZERO, half.length() * 0.85)
