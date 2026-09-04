extends Node2D
## Static, code-drawn placeholder room: wall, desk, lamp and props.
## Pure decoration - no gameplay logic lives here.

var _font: Font
var _clock_accum := 0.0

func _ready() -> void:
	_font = ThemeDB.fallback_font

func _process(delta: float) -> void:
	_clock_accum += delta
	if _clock_accum >= 0.5:
		_clock_accum = 0.0
		queue_redraw()

func _draw() -> void:
	# wall with a warm vignette
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.17, 0.12, 0.1))
	draw_rect(Rect2(0, 0, 1280, 260), Color(0.22, 0.15, 0.12))
	draw_rect(Rect2(0, 0, 1280, 60), Color(0.13, 0.09, 0.07))
	draw_rect(Rect2(0, 0, 180, 260), Color(0.13, 0.09, 0.07, 0.6))
	draw_rect(Rect2(1100, 0, 180, 260), Color(0.13, 0.09, 0.07, 0.6))
	# wall shelf / wainscot line
	draw_line(Vector2(0, 245), Vector2(1280, 245), Color(0.3, 0.2, 0.14), 8.0)

	# desk
	var desk := PackedVector2Array([Vector2(30, 258), Vector2(1250, 258), Vector2(1330, 800), Vector2(-50, 800)])
	draw_colored_polygon(desk, Color(0.5, 0.3, 0.17))
	for i in range(1, 9):
		var y := 258 + i * 68
		var spread := (y - 258) / 542.0 * 80.0
		draw_line(Vector2(30 - spread, y), Vector2(1250 + spread, y), Color(0.38, 0.22, 0.12, 0.7), 2.0)
	# grain streaks
	for i in 14:
		var x := 80 + i * 90
		draw_line(Vector2(x, 300), Vector2(x - 40, 800), Color(0.56, 0.35, 0.2, 0.18), 3.0)
	draw_line(Vector2(30, 258), Vector2(1250, 258), Color(0.95, 0.75, 0.45, 0.35), 3.0)
	# warm lamp pool on the desk
	draw_set_transform(Vector2(420, 420), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 360, Color(1.0, 0.8, 0.5, 0.10))
	draw_circle(Vector2.ZERO, 220, Color(1.0, 0.85, 0.55, 0.10))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	_draw_plant()
	_draw_lamp()
	_draw_mug()
	_draw_notebook()
	_draw_frames()
	_draw_clock()
	_draw_pencils()

func _draw_plant() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(75, 175), Vector2(165, 175), Vector2(155, 250), Vector2(85, 250)]), Color(0.65, 0.35, 0.22))
	draw_rect(Rect2(70, 168, 100, 14), Color(0.72, 0.4, 0.25))
	for leaf in [Vector2(100, 130), Vector2(135, 115), Vector2(80, 100), Vector2(150, 150), Vector2(115, 160), Vector2(60, 145)]:
		draw_set_transform(leaf, leaf.x * 0.01, Vector2(1, 0.55))
		draw_circle(Vector2.ZERO, 30, Color(0.22, 0.45, 0.25))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _draw_lamp() -> void:
	var metal := Color(0.18, 0.36, 0.34)
	var metal_light := Color(0.28, 0.5, 0.47)
	draw_set_transform(Vector2(140, 610), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 60, Color(0, 0, 0, 0.3))
	draw_circle(Vector2(0, -6), 58, metal)
	draw_circle(Vector2(0, -10), 50, metal_light)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_line(Vector2(140, 600), Vector2(180, 400), metal, 12.0)
	draw_line(Vector2(180, 400), Vector2(255, 265), metal, 10.0)
	draw_circle(Vector2(180, 400), 12, metal_light)
	var head := PackedVector2Array([Vector2(215, 250), Vector2(300, 250), Vector2(335, 330), Vector2(180, 330)])
	draw_colored_polygon(head, metal)
	draw_colored_polygon(PackedVector2Array([Vector2(225, 258), Vector2(290, 258), Vector2(300, 290), Vector2(215, 290)]), metal_light)
	draw_circle(Vector2(258, 328), 16, Color(1.0, 0.95, 0.72))
	draw_circle(Vector2(258, 328), 26, Color(1.0, 0.9, 0.6, 0.35))

func _draw_mug() -> void:
	draw_set_transform(Vector2(95, 500), 0, Vector2(1, 0.4))
	draw_circle(Vector2(6, 0), 40, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_rect(Rect2(60, 430, 66, 70), Color(0.87, 0.65, 0.22))
	draw_arc(Vector2(130, 465), 18, -PI / 2, PI / 2, 12, Color(0.87, 0.65, 0.22), 8.0)
	draw_set_transform(Vector2(93, 430), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 33, Color(0.95, 0.75, 0.3))
	draw_circle(Vector2.ZERO, 27, Color(0.32, 0.18, 0.1))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_circle(Vector2(85, 470), 10, Color(1, 0.4, 0.4, 0.6))

func _draw_notebook() -> void:
	draw_set_transform(Vector2(40, 620), -0.28, Vector2.ONE)
	draw_rect(Rect2(6, 6, 160, 200), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(0, 0, 160, 200), Color(0.92, 0.88, 0.78))
	draw_rect(Rect2(0, 0, 14, 200), Color(0.6, 0.35, 0.25))
	for i in 9:
		draw_line(Vector2(28, 26 + i * 20), Vector2(145, 26 + i * 20), Color(0.6, 0.6, 0.65, 0.5), 1.0)
	draw_circle(Vector2(80, 80), 28, Color(0.3, 0.3, 0.35, 0.25))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _draw_frames() -> void:
	for f in [Rect2(940, 150, 70, 90), Rect2(1060, 130, 90, 110)]:
		draw_rect(f.grow(6), Color(0.3, 0.18, 0.1))
		draw_rect(f, Color(0.85, 0.8, 0.7))
		draw_circle(f.get_center() + Vector2(0, 8), f.size.x * 0.25, Color(0.35, 0.5, 0.35))
		draw_circle(f.get_center() + Vector2(-10, -12), f.size.x * 0.12, Color(0.9, 0.6, 0.4))

func _draw_clock() -> void:
	var r := Rect2(1040, 272, 110, 58)
	draw_rect(r.grow(3), Color(0, 0, 0, 0.3))
	draw_rect(r, Color(0.12, 0.1, 0.1))
	draw_rect(r.grow(-8), Color(0.05, 0.05, 0.06))
	draw_string(_font, Vector2(r.position.x + 18, r.position.y + 42), GameManager.format_elapsed(), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.72, 0.2))

func _draw_pencils() -> void:
	draw_line(Vector2(760, 610), Vector2(890, 640), Color(0.5, 0.25, 0.45), 7.0)
	draw_line(Vector2(890, 640), Vector2(902, 643), Color(0.9, 0.8, 0.6), 5.0)
	draw_line(Vector2(940, 585), Vector2(1030, 640), Color(0.2, 0.35, 0.6), 7.0)
	draw_line(Vector2(1030, 640), Vector2(1040, 646), Color(0.9, 0.8, 0.6), 5.0)
	# yellow sticky-note
	draw_set_transform(Vector2(1120, 640), 0.15, Vector2.ONE)
	draw_rect(Rect2(0, 0, 70, 60), Color(0.95, 0.8, 0.25))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
