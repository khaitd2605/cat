class_name Paper
extends Node2D
## A loose sheet of paper on the desk. Lies still; flutters when the wind picks
## up (the ESCALATING signal of the wind event); blows away on a gust.

var flutter := 0.0        # 0 still .. 2 wild
var _cur := 0.0
var _t := 0.0
var _blown := 0.0         # 0..1 flying off the desk
var _rest := Vector2.ZERO

func _ready() -> void:
	_rest = position

func blow_away() -> void:
	_blown = 0.001

func reset() -> void:
	_blown = 0.0
	position = _rest
	modulate.a = 1.0

func _process(delta: float) -> void:
	_t += delta
	_cur = lerp(_cur, flutter, delta * 3.0)
	if _blown > 0.0 and _blown < 1.0:
		_blown = min(_blown + delta / 1.4, 1.0)
		position = _rest + Vector2(260.0 * _blown, -40.0 * sin(_blown * PI) + 120.0 * _blown * _blown)
		rotation = _blown * 2.5
		modulate.a = 1.0 - _blown
		if _blown >= 1.0:
			# comes back after a while so the signal can play again
			get_tree().create_timer(4.0).timeout.connect(func(): if is_instance_valid(self): reset())
	queue_redraw()

func _draw() -> void:
	var lift := _cur * 6.0 * (0.5 + 0.5 * sin(_t * 9.0))
	var corner := Vector2(0, -lift - _cur * 4.0 * sin(_t * 13.0))
	var sheet := PackedVector2Array([
		Vector2(-38, -26), Vector2(38, -26) + corner, Vector2(38, 26) + corner * 1.6, Vector2(-38, 26)])
	draw_colored_polygon(_shifted(sheet, Vector2(3, 4)), Color(0, 0, 0, 0.22))
	draw_colored_polygon(sheet, Color(0.93, 0.9, 0.82))
	for i in 4:
		var y := -14 + i * 10
		draw_line(Vector2(-28, y), Vector2(26, y) + corner * (0.3 + i * 0.2), Color(0.55, 0.55, 0.6, 0.5), 1.0)
	if _cur > 0.3:
		draw_line(Vector2(38, -26) + corner, Vector2(38, 26) + corner * 1.6, Color(0.8, 0.78, 0.7), 1.5)

static func _shifted(p: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in p:
		out.append(v + off)
	return out
