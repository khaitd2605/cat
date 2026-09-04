class_name Domino
extends RefCounted
## Pure data + drawing for one domino. Not a Node: the DominoTask draws all
## dominoes itself so they can be depth-sorted cheaply and simulated together.

enum State { STANDING, FALLING, FALLEN }

const LENGTH := 15.0   # width of the face: ACROSS the path
const THICK := 6.0     # thickness: ALONG the path (the way it falls)
const HEIGHT := 26.0

var pos: Vector2          # footprint center (local to the task)
var angle: float          # direction of travel of the run; the face is perpendicular
var color: Color
var slot := -1            # guide slot it satisfies, -1 = off the path
var lean := 0.0           # -1..1 tilt along the run from a sloppy release (0 = straight)
var state: State = State.STANDING
var fall_t := 0.0         # 0 standing .. 1 lying flat
var fall_dir := 1.0       # +1 / -1: which side it topples to (along normal)
var fall_at := -1.0       # task-time at which it starts toppling (<0 = not falling)
var hit_done := false     # already knocked its neighbours
var fade := 1.0           # fallen dominoes fade out before being removed

func _init(p: Vector2, a: float, c: Color) -> void:
	pos = p
	angle = a
	color = c

## The axis it can topple along: forward/backward along the run.
func normal() -> Vector2:
	return Vector2.from_angle(angle)

## Where the top edge lands when it has fallen fully.
func landing_tip() -> Vector2:
	return pos + normal() * fall_dir * HEIGHT * 0.92

func draw(ci: CanvasItem, jitter: Vector2, alpha := 1.0) -> void:
	var travel := Vector2.from_angle(angle)
	var across := travel.orthogonal()
	var center := pos + jitter
	var half_l := across * LENGTH * 0.5   # wide face across the run
	var half_t := travel * THICK * 0.5    # thin along the run
	var col := Color(color, color.a * alpha)
	if fall_t > 0.0:
		_draw_toppling(ci, center, half_l, half_t, travel, col)
		return
	var base := PackedVector2Array([
		center - half_l - half_t,
		center + half_l - half_t,
		center + half_l + half_t,
		center - half_l + half_t,
	])
	var up := Vector2(0, -HEIGHT) + travel * lean * 7.0
	var top := PackedVector2Array()
	for b in base:
		top.append(b + up)

	ci.draw_colored_polygon(_shift(base, Vector2(3, 3)), Color(0, 0, 0, 0.25 * alpha))

	var light_dir := Vector2(-0.6, 1.0).normalized()
	var faces: Array = []
	for i in 4:
		var a := base[i]
		var b := base[(i + 1) % 4]
		var edge := b - a
		if edge.length_squared() < 0.01:
			continue
		var n := edge.orthogonal().normalized() * -1.0
		if n.y > -0.05:
			var shade: float = 0.5 + 0.5 * max(0.0, n.dot(light_dir))
			faces.append({ "poly": PackedVector2Array([a, b, top[(i + 1) % 4], top[i]]), "shade": shade, "depth": (a.y + b.y) })
	faces.sort_custom(func(x, y): return x["depth"] < y["depth"])
	for f in faces:
		ci.draw_colored_polygon(f["poly"], col.darkened(1.0 - f["shade"]))
	ci.draw_colored_polygon(top, col.lightened(0.25))
	ci.draw_polyline(_closed(top), Color(0, 0, 0, 0.25 * alpha), 1.0)
	# pips on the face that looks at the viewer
	var face_mid := (base[2] + base[3]) * 0.5 if abs(across.x) > 0.3 else (base[1] + base[2]) * 0.5
	for k in 2:
		ci.draw_circle(face_mid + Vector2(0, -HEIGHT * (0.3 + 0.4 * k)), 1.5, Color(1, 1, 1, 0.55 * alpha))

## The domino rotates around its base edge on the side it falls to, ending flat.
func _draw_toppling(ci: CanvasItem, center: Vector2, half_l: Vector2, half_t: Vector2, nrm: Vector2, col: Color) -> void:
	var eased := ease(fall_t, 0.6)
	var pivot0 := center - half_l + half_t * fall_dir
	var pivot1 := center + half_l + half_t * fall_dir
	var reach := Vector2(0, -HEIGHT * (1.0 - eased)) + nrm * fall_dir * HEIGHT * eased
	var plank := PackedVector2Array([pivot0, pivot1, pivot1 + reach, pivot0 + reach])
	if eased < 0.98:
		ci.draw_colored_polygon(_shift(plank, Vector2(3, 3) * (1.0 - eased)), Color(0, 0, 0, 0.2 * col.a))
	ci.draw_colored_polygon(plank, col.lightened(0.15 * eased))
	var back0 := pivot0 - half_t * fall_dir * 2.0
	var back1 := pivot1 - half_t * fall_dir * 2.0
	ci.draw_colored_polygon(PackedVector2Array([back0, back1, pivot1, pivot0]), col.darkened(0.35))
	ci.draw_polyline(_closed(plank), Color(0, 0, 0, 0.25 * col.a), 1.0)
	ci.draw_circle((plank[0] + plank[2]) * 0.5, 1.6, Color(1, 1, 1, 0.55 * col.a))

static func _shift(p: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in p:
		out.append(v + off)
	return out

static func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(p)
	out.append(p[0])
	return out
