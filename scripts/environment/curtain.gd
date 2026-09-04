class_name Curtain
extends Node2D
## Two cloth curtains. The right one flies out with the wind - the very first
## visible signal that a gust is coming. `wind_level` 0..4.

var wind_level := 0.0
var _cur := 0.0
var _t := 0.0
var _gust := 0.0

func gust() -> void:
	_gust = 1.0

func _process(delta: float) -> void:
	_t += delta
	_cur = lerp(_cur, wind_level, delta * 2.5)
	_gust = max(_gust - delta * 0.7, 0.0)
	queue_redraw()

func _draw() -> void:
	var cloth := Color(0.96, 0.93, 0.88, 0.92)
	var fold := Color(0.8, 0.76, 0.72, 0.6)
	# left curtain: hangs, only sways gently
	_draw_curtain(Vector2(-215, -5), -1.0, 0.15 + _cur * 0.1, cloth, fold, 60.0, 250.0)
	# right curtain: catches the wind
	var strength: float = 0.25 + _cur * 0.9 + _gust * 2.2
	_draw_curtain(Vector2(160, -5), 1.0, strength, cloth, fold, 70.0, 240.0)

func _draw_curtain(origin: Vector2, dir: float, strength: float, cloth: Color, fold: Color, width: float, length: float) -> void:
	var segments := 14
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var speed := 2.0 + strength * 2.5
	for i in segments + 1:
		var k := float(i) / segments
		var y := k * length * (1.0 - 0.28 * minf(strength, 1.5) * k)  # lifts as it blows (kept monotonic)
		var blow := pow(k, 1.4) * strength * 60.0 * dir
		var wave := sin(_t * speed + k * 5.0) * (4.0 + strength * 10.0) * k
		var x := blow + wave
		left.append(origin + Vector2(x, y))
		var w := width * (1.0 - 0.25 * k) + sin(_t * speed * 1.3 + k * 7.0) * 6.0 * k
		right.append(origin + Vector2(x + w * dir, y + strength * 12.0 * k))
	# draw as a strip of triangles: a single big polygon self-intersects when
	# the cloth folds and triangulation fails
	for i in segments:
		_tri(left[i], left[i + 1], right[i + 1], cloth)
		_tri(left[i], right[i + 1], right[i], cloth)
	# fold lines
	for f in [0.3, 0.6]:
		var line := PackedVector2Array()
		for i in left.size():
			line.append(left[i].lerp(right[i], f))
		draw_polyline(line, fold, 2.0)
	# rod
	draw_line(origin + Vector2(-10 * dir, -8), origin + Vector2((width + 20) * dir, -8), Color(0.3, 0.2, 0.12), 6.0)

## Triangles never fail triangulation unless degenerate, so skip those.
func _tri(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	if absf((b - a).cross(c - a)) < 0.5:
		return
	draw_colored_polygon(PackedVector2Array([a, b, c]), color)
