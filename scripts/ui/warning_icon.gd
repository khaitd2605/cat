class_name WarningIcon
extends Control
## Small code-drawn icon for the warning banner (no emoji fonts on Web).

var kind := "generic"
var color := Color(0.9, 0.3, 0.25)

func _init() -> void:
	custom_minimum_size = Vector2(48, 48)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() / 120.0)
	draw_circle(c, 22 * pulse, Color(color, 0.25))
	draw_circle(c, 18, Color(0.15, 0.08, 0.06))
	match kind:
		"wind":
			for i in 3:
				var y := c.y - 8 + i * 8
				var pts := PackedVector2Array()
				for k in 9:
					var x := c.x - 12 + k * 3.0
					pts.append(Vector2(x, y + sin(k * 0.8 + i) * 2.0))
				draw_polyline(pts, color, 2.5)
		"cat":
			draw_circle(c + Vector2(0, 2), 10, color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -4), c + Vector2(-11, -14), c + Vector2(-2, -8)]), color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(9, -4), c + Vector2(11, -14), c + Vector2(2, -8)]), color)
			draw_circle(c + Vector2(-4, 1), 2, Color(0.1, 0.05, 0.05))
			draw_circle(c + Vector2(4, 1), 2, Color(0.1, 0.05, 0.05))
		_:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12), c + Vector2(12, 10), c + Vector2(-12, 10)]), color)
			draw_rect(Rect2(c + Vector2(-1.5, -4), Vector2(3, 8)), Color(0.1, 0.05, 0.05))
			draw_circle(c + Vector2(0, 7), 1.6, Color(0.1, 0.05, 0.05))
