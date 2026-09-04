class_name DominoTask
extends Node2D
## BUILD system: the meticulous work.
##
## The player picks a domino from the tray and carries it BY ITS TOP: the bottom
## swings like a pendulum, fed by hand movement and calmed by holding still.
## Release when the bottom hangs straight under the hand and it stands; release
## mid-swing and it lands tilted and topples (into its neighbours...).
## The angle always matches the spiral GUIDE - precision is about position and
## timing, not rotation. Dominoes collide: any knock topples neighbours by real
## proximity (chain reaction). Fallen dominoes fade away and must be rebuilt.
## This node knows nothing about WHY things get knocked over.

signal drag_started
signal drag_ended

enum GuideShape { SERPENTINE, SPIRAL }

## Shape of the run. SERPENTINE: wavy rows joined by U-turns, start -> finish.
@export var shape: GuideShape = GuideShape.SERPENTINE
## Upper bound; the path decides the real count (see slots.size()).
@export var total_dominoes := 60
@export var spacing := 26.0
@export var squash := 0.62          # y-scale for the oblique camera
@export_group("Serpentine")
@export var rows := 3
@export var row_length := 440.0
@export var row_gap := 150.0        # table-space distance between rows
@export var wave_amp := 26.0
@export var wave_len := 160.0
@export_group("Spiral")
@export var start_radius := 58.0
@export var radius_growth := 46.0   # extra radius per full turn
@export_group("")
## The bottom must land within this distance of the guide slot to count.
@export var slot_tolerance := 24.0
## Beyond this distance from the guide the domino goes back to the tray.
@export var max_off_path := 70.0
## Pendulum: spring stiffness, damping, how much hand motion feeds the swing.
@export var swing_stiffness := 38.0
@export var swing_damping := 2.2
@export var swing_from_hand := 0.14
## |swing| at release: below = stands straight, above = topples. Between: leans.
@export var straight_swing := 4.5
@export var topple_swing := 10.0
## Where the tray of spare dominoes sits (local).
@export var tray_pos := Vector2(-300, 210)

var slots: Array[Dictionary] = []   # { "pos": Vector2, "angle": float }
var dominoes: Array[Domino] = []
var shaking := false
var shield_active := false

# drag state
var dragging := false
var drag_pos := Vector2.ZERO     # the HAND (top of the domino)
var drag_angle := 0.0            # always the guide angle of the target slot
var swing := 0.0                 # bottom offset along the normal (px)
var swing_vel := 0.0
var _drag_prev := Vector2.ZERO
## Debug/bot: when true the hand is not read from the mouse each frame.
var debug_lock_hand := false

# collapse bookkeeping (for the FailureSystem)
var _collapse_active := false
var _collapse_knocked := 0
var _collapse_standing_before := 0
var _last_fall_time := 0.0

var _time := 0.0
var _pulse := 0.0
var _jitter := Vector2.ZERO
var _feedback_text := ""
var _feedback_col := Color.WHITE
var _feedback_t := 0.0
var _feedback_pos := Vector2.ZERO
var _hover_tray := false
var _font: Font

@onready var _puff: CPUParticles2D = get_node_or_null("PlacePuff")

func _ready() -> void:
	_font = ThemeDB.fallback_font
	_build_spiral()
	(func(): EventBus.task_progress.emit(placed_count(), total_dominoes)).call_deferred()

func _build_spiral() -> void:
	slots.clear()
	match shape:
		GuideShape.SPIRAL:
			_sample_path(_spiral_points())
		_:
			_sample_path(_serpentine_points())
	total_dominoes = slots.size()

## Dense polyline in TABLE space (before perspective). Serpentine: rows of a
## sine wave, alternating direction, joined by half-circle U-turns.
func _serpentine_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var half := row_length * 0.5
	var top := -row_gap * (rows - 1) * 0.5
	for r in rows:
		var y := top + r * row_gap
		var dir := 1.0 if r % 2 == 0 else -1.0
		var steps := int(row_length / 4.0)
		for i in steps + 1:
			var x := -half * dir + (float(i) / steps) * row_length * dir
			pts.append(Vector2(x, y + sin(x / wave_len * TAU) * wave_amp))
		if r < rows - 1:
			# U-turn at the row's end, bending down to the next row
			var cx := half * dir
			var cy := y + row_gap * 0.5
			var rad := row_gap * 0.5
			var arc_steps := 24
			for i in range(1, arc_steps):
				var a := -PI / 2 + (float(i) / arc_steps) * PI
				pts.append(Vector2(cx + cos(a) * rad * dir, cy + sin(a) * rad))
	return pts

func _spiral_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var theta := 0.0
	while theta < TAU * 3.2:
		var r := start_radius + radius_growth * theta / TAU
		pts.append(Vector2(cos(theta) * r, sin(theta) * r))
		theta += 0.02
	return pts

## Walk the polyline at `spacing` (measured in screen space, after squash) and
## drop a slot each step, facing the direction of travel.
func _sample_path(table_pts: PackedVector2Array) -> void:
	var screen := PackedVector2Array()
	for p in table_pts:
		screen.append(Vector2(p.x, p.y * squash))
	var carry := 0.0
	for i in range(1, screen.size()):
		var a := screen[i - 1]
		var b := screen[i]
		var seg := a.distance_to(b)
		if seg <= 0.0001:
			continue
		var t := carry
		while t <= seg:
			var pos := a.lerp(b, t / seg)
			slots.append({ "pos": pos, "angle": (b - a).angle() })
			t += spacing
		carry = t - seg

# --------------------------------------------------------------- queries

func can_work() -> bool:
	return GameManager.is_playing()

func is_focusing() -> bool:
	return dragging

## Progress = guide slots currently satisfied by a standing domino.
func placed_count() -> int:
	var n := 0
	for d in dominoes:
		if d.state == Domino.State.STANDING and d.slot >= 0:
			n += 1
	return n

func standing_count() -> int:
	var n := 0
	for d in dominoes:
		if d.state == Domino.State.STANDING:
			n += 1
	return n

func get_progress() -> float:
	return float(placed_count()) / max(total_dominoes, 1)

## First guide slot without a standing domino, -1 when the path is complete.
func next_slot_index() -> int:
	var filled := {}
	for d in dominoes:
		if d.state == Domino.State.STANDING and d.slot >= 0:
			filled[d.slot] = true
	for i in slots.size():
		if not filled.has(i):
			return i
	return -1

## Where the player is working right now (world) - the FocusSystem looks here.
## The next guide slot, not the cursor, so the camera stays steady while dragging.
func focus_point_global() -> Vector2:
	var i := next_slot_index()
	if i >= 0:
		return to_global(slots[i]["pos"])
	return to_global(drag_pos if dragging else Vector2.ZERO)

## Where the cat lands when it jumps (global).
func landing_spot() -> Vector2:
	return global_position + Vector2(120, 0)

## Where the bottom of the carried domino is over the desk. It swings along
## the run - the axis a domino can topple on.
func carried_base() -> Vector2:
	return drag_pos + Vector2(0, Domino.HEIGHT) + Vector2.from_angle(drag_angle) * swing

func nearest_slot_index(global_pos: Vector2) -> int:
	var local := to_local(global_pos)
	var best := 0
	var best_d := INF
	for i in slots.size():
		var d: float = slots[i]["pos"].distance_to(local)
		if d < best_d:
			best_d = d
			best = i
	return best

# --------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not can_work():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local := to_local(get_global_mouse_position())
		if event.pressed and not dragging:
			if _pick_from_tray(local):
				get_viewport().set_input_as_handled()
		elif not event.pressed and dragging:
			_drop()
			get_viewport().set_input_as_handled()

func _pick_from_tray(local: Vector2) -> bool:
	var next := next_slot_index()
	if next < 0:
		return false
	var on_tray := local.distance_to(tray_pos) <= 48.0
	var on_ghost: bool = local.distance_to(slots[next]["pos"]) <= slot_tolerance * 1.5
	if not (on_tray or on_ghost):
		return false
	if shield_active:
		EventBus.notify.emit("Đang che chắn - bỏ tay ra mới xếp tiếp được!", Color(1.0, 0.8, 0.4))
		return true
	dragging = true
	drag_pos = local
	_drag_prev = local
	drag_angle = slots[next]["angle"]
	# lifted off the tray with a bit of wobble already
	swing = 0.0
	swing_vel = randf_range(-90.0, 90.0)
	Sfx.play("place", -12.0)
	drag_started.emit()
	return true

## Let go: the bottom lands where it hangs; the swing decides whether it stands.
func _drop() -> void:
	dragging = false
	drag_ended.emit()
	var next := next_slot_index()
	if next < 0:
		return
	var local := carried_base()
	var target: Vector2 = slots[next]["pos"]
	var dist := local.distance_to(target)
	if dist > max_off_path:
		_show_feedback("Ngoài đường dẫn", Color(1, 0.85, 0.5), local)
		Sfx.play("miss", -8.0)
		return
	var counts := dist <= slot_tolerance
	var hue := fmod(float(next) / total_dominoes * 1.6, 1.0)
	var d := Domino.new(local, drag_angle, Color.from_hsv(hue, 0.62, 0.88))
	d.slot = next if counts else -1
	var tilt := absf(swing)
	dominoes.append(d)
	if _puff:
		_puff.position = local
		_puff.restart()
	# dropping onto a neighbour knocks it
	var bumped := false
	for other in dominoes:
		if other == d or other.state != Domino.State.STANDING:
			continue
		if other.pos.distance_to(local) < Domino.LENGTH * 0.9:
			var dir := signf((other.pos - local).dot(other.normal()))
			_start_fall(other, dir if dir != 0.0 else 1.0, 0.0)
			bumped = true
	if tilt > topple_swing:
		# landed on its edge: it goes over right away, the way it was swinging
		_start_fall(d, signf(swing), 0.05)
		Sfx.play("miss", -2.0)
		_show_feedback("Thả lúc đang lắc - đổ!", Color(1, 0.45, 0.4), local)
	elif bumped:
		Sfx.play("thud", -8.0)
		_show_feedback("Va vào quân bên cạnh!", Color(1, 0.45, 0.4), local)
	elif not counts:
		Sfx.play("place", -4.0)
		_show_feedback("Lệch chỗ - không tính", Color(1, 0.8, 0.45), local)
	elif tilt > straight_swing:
		d.lean = clamp(swing / topple_swing, -1.0, 1.0) * 0.6
		Sfx.play("place", -3.0)
		_show_feedback("Hơi nghiêng", Color(1, 0.9, 0.6), local)
	else:
		Sfx.play("place")
		_show_feedback("Chuẩn!" if dist < slot_tolerance * 0.5 else "Ổn", Color(0.7, 1, 0.7), local)
	EventBus.task_progress.emit(placed_count(), total_dominoes)
	if next_slot_index() < 0:
		EventBus.task_completed.emit()

## Debug/bot helper: instant perfect placement of the next slot.
func debug_place_next() -> bool:
	var next := next_slot_index()
	if next < 0 or not can_work():
		return false
	var d := Domino.new(slots[next]["pos"], slots[next]["angle"], Color.from_hsv(fmod(float(next) / total_dominoes * 1.6, 1.0), 0.62, 0.88))
	d.slot = next
	dominoes.append(d)
	EventBus.task_progress.emit(placed_count(), total_dominoes)
	if next_slot_index() < 0:
		EventBus.task_completed.emit()
	return true

func _show_feedback(text: String, col: Color, at: Vector2) -> void:
	_feedback_text = text
	_feedback_col = col
	_feedback_t = 1.0
	_feedback_pos = at

# --------------------------------------------------------------- environment hooks

func set_shaking(on: bool) -> void:
	shaking = on
	if not on:
		_jitter = Vector2.ZERO

func set_shield(on: bool) -> void:
	shield_active = on
	if on and dragging:
		dragging = false
		drag_ended.emit()
		_show_feedback("Buông quân ra để che", Color(1, 0.85, 0.5), drag_pos)

## A gust from the window: every standing domino on the window side topples
## down-screen; the chain reaction does the rest. Shield absorbs it.
func gust() -> void:
	if shield_active:
		return
	var i := 0
	for d in dominoes:
		if d.state == Domino.State.STANDING and d.pos.y < 10.0:
			var n := d.normal()
			_start_fall(d, 1.0 if n.y >= 0.0 else -1.0, randf_range(0.0, 0.25))
			i += 1

## Something lands on the desk at a global point and flattens what is nearby.
func smash_at(global_pos: Vector2, radius: float) -> void:
	var local := to_local(global_pos)
	for d in dominoes:
		if d.state == Domino.State.STANDING and d.pos.distance_to(local) <= radius:
			var dir := signf((d.pos - local).dot(d.normal()))
			_start_fall(d, dir if dir != 0.0 else 1.0, d.pos.distance_to(local) * 0.004)

func _start_fall(d: Domino, dir: float, delay: float) -> void:
	if d.state != Domino.State.STANDING:
		return
	d.state = Domino.State.FALLING
	d.fall_dir = dir
	d.fall_at = _time + delay
	if not _collapse_active:
		_collapse_active = true
		_collapse_knocked = 0
		_collapse_standing_before = standing_count()
		Sfx.play("fall", -6.0)
	_collapse_knocked += 1
	_last_fall_time = _time + delay

## Proximity chain reaction: a toppling domino hits whatever stands in its arc.
func _propagate(d: Domino) -> void:
	var tip := d.landing_tip()
	for other in dominoes:
		if other == d or other.state != Domino.State.STANDING:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(other.pos, d.pos, tip)
		if closest.distance_to(other.pos) <= Domino.THICK * 1.6:
			var dir := signf((other.pos - d.pos).dot(other.normal()))
			_start_fall(other, dir if dir != 0.0 else d.fall_dir, 0.04)

# --------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	_time += delta
	_pulse += delta * 4.0
	_feedback_t = max(_feedback_t - delta, 0.0)
	if shaking:
		_jitter = Vector2(randf_range(-1.3, 1.3), randf_range(-0.8, 0.8))
	if dragging:
		if not can_work():
			dragging = false
			drag_ended.emit()
		else:
			if not debug_lock_hand:
				drag_pos = to_local(get_global_mouse_position())
			var next := next_slot_index()
			if next >= 0:
				drag_angle = slots[next]["angle"]
			# pendulum: hand motion across the face kicks the bottom the other way
			var hand_vel: Vector2 = (drag_pos - _drag_prev) / maxf(delta, 0.0001)
			_drag_prev = drag_pos
			var n := Vector2.from_angle(drag_angle)
			swing_vel -= hand_vel.dot(n) * swing_from_hand
			if shaking:
				swing_vel += randf_range(-40.0, 40.0)
			var acc := -swing_stiffness * swing - swing_damping * swing_vel
			swing_vel += acc * delta
			swing += swing_vel * delta
			swing = clamp(swing, -22.0, 22.0)

	var any_falling := false
	for d in dominoes:
		match d.state:
			Domino.State.FALLING:
				any_falling = true
				if _time >= d.fall_at:
					d.fall_t = min(d.fall_t + delta / 0.3, 1.0)
					if d.fall_t >= 0.45 and not d.hit_done:
						d.hit_done = true
						_propagate(d)
					if d.fall_t >= 1.0:
						d.state = Domino.State.FALLEN
			Domino.State.FALLEN:
				d.fade = max(d.fade - delta / 1.6, 0.0)
	# remove faded debris
	var before := dominoes.size()
	dominoes = dominoes.filter(func(d: Domino): return not (d.state == Domino.State.FALLEN and d.fade <= 0.0))
	if dominoes.size() != before:
		EventBus.task_progress.emit(placed_count(), total_dominoes)
	# collapse settled?
	if _collapse_active and not any_falling and _time > _last_fall_time + 0.4:
		_collapse_active = false
		EventBus.collapse_finished.emit(_collapse_knocked, _collapse_standing_before)
		EventBus.task_progress.emit(placed_count(), total_dominoes)

	_update_cursor()
	queue_redraw()

func _update_cursor() -> void:
	var local := to_local(get_global_mouse_position())
	var next := next_slot_index()
	var hot := can_work() and not dragging and next >= 0 and (local.distance_to(tray_pos) <= 48.0 or local.distance_to(slots[next]["pos"]) <= slot_tolerance * 1.5)
	if hot != _hover_tray:
		_hover_tray = hot
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hot else Input.CURSOR_ARROW)

# --------------------------------------------------------------- drawing

func _draw() -> void:
	var next := next_slot_index()
	# guide dots
	for i in slots.size():
		if i == next:
			continue
		var a := 0.20 if (next >= 0 and i > next and i < next + 8) else 0.07
		draw_circle(slots[i]["pos"], 1.6, Color(1, 0.95, 0.85, a))

	_draw_tray(next >= 0)
	_draw_markers(next)

	var order := dominoes.duplicate()
	order.sort_custom(func(a: Domino, b: Domino): return a.pos.y < b.pos.y)
	for d in order:
		d.draw(self, _jitter if d.state == Domino.State.STANDING else Vector2.ZERO, d.fade)

	if can_work() and next >= 0:
		_draw_ghost(next)
	if dragging:
		_draw_dragged(next)
	if _feedback_t > 0.0:
		var p := _feedback_pos + Vector2(0, -50 - (1.0 - _feedback_t) * 25)
		draw_string(_font, p + Vector2(-80, 0), _feedback_text, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(_feedback_col, min(_feedback_t * 2.0, 1.0)))
	if shield_active:
		_draw_hands()

func _draw_markers(next: int) -> void:
	if slots.is_empty():
		return
	var start: Vector2 = slots[0]["pos"]
	var finish: Vector2 = slots[slots.size() - 1]["pos"]
	var t_end := Vector2.from_angle(slots[slots.size() - 1]["angle"])
	# start: small chalk circle
	draw_set_transform(start - Vector2.from_angle(slots[0]["angle"]) * 24, 0, Vector2(1, squash))
	draw_arc(Vector2.ZERO, 12, 0, TAU, 20, Color(1, 0.95, 0.8, 0.5), 2.0)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_string(_font, start - Vector2.from_angle(slots[0]["angle"]) * 24 + Vector2(-40, -14), "BẮT ĐẦU", HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color(1, 0.95, 0.8, 0.6))
	# finish: a little flag past the last slot
	var f := finish + t_end * 30
	var done := next < 0
	var col := Color(0.6, 1.0, 0.6) if done else Color(1.0, 0.85, 0.45)
	draw_line(f, f + Vector2(0, -34), Color(0.9, 0.85, 0.75), 2.0)
	draw_colored_polygon(PackedVector2Array([f + Vector2(0, -34), f + Vector2(18, -28), f + Vector2(0, -22)]), col)
	draw_string(_font, f + Vector2(-30, 14), "ĐÍCH", HORIZONTAL_ALIGNMENT_CENTER, 60, 11, Color(col, 0.75))

func _draw_tray(active: bool) -> void:
	# a small wooden box with a few spare dominoes
	draw_set_transform(tray_pos + Vector2(0, 14), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 58, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_rect(Rect2(tray_pos + Vector2(-46, -14), Vector2(92, 34)), Color(0.36, 0.22, 0.13))
	draw_rect(Rect2(tray_pos + Vector2(-42, -10), Vector2(84, 26)), Color(0.25, 0.15, 0.09))
	for i in 5:
		var spare := Domino.new(tray_pos + Vector2(-30 + i * 15, 4), 0.0, Color.from_hsv(0.08 + i * 0.13, 0.5, 0.8))
		spare.draw(self, Vector2.ZERO)
	if active and (_hover_tray or not dragging):
		var glow := 0.4 + 0.25 * sin(_pulse) if _hover_tray else 0.15
		draw_rect(Rect2(tray_pos + Vector2(-50, -46), Vector2(100, 70)), Color(1.0, 0.9, 0.55, glow), false, 2.0)
	draw_string(_font, tray_pos + Vector2(-50, 40), "khay domino", HORIZONTAL_ALIGNMENT_CENTER, 100, 12, Color(1, 0.95, 0.85, 0.55))

func _draw_ghost(next: int) -> void:
	var s := slots[next]
	var p: Vector2 = s["pos"]
	var aligned := false
	if dragging:
		aligned = carried_base().distance_to(p) <= slot_tolerance and absf(swing) <= straight_swing
	var glow := 0.5 + 0.3 * sin(_pulse)
	var col := Color(0.6, 1.0, 0.6, 0.9) if aligned else Color(1.0, 0.9, 0.55, glow)
	if shield_active:
		col = Color(0.7, 0.7, 0.7, 0.4)
	draw_set_transform(p, 0.0, Vector2(1, squash))
	draw_arc(Vector2.ZERO, slot_tolerance, 0, TAU, 32, col, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var t := Vector2.from_angle(s["angle"])
	var n := t.orthogonal()
	var foot := PackedVector2Array([
		p - n * 7.5 - t * 3, p + n * 7.5 - t * 3, p + n * 7.5 + t * 3, p - n * 7.5 + t * 3, p - n * 7.5 - t * 3])
	draw_polyline(foot, Color(col, glow), 1.5)
	draw_line(p, p + Vector2(0, -Domino.HEIGHT), Color(col, glow * 0.6), 1.0)

func _draw_dragged(next: int) -> void:
	var travel := Vector2.from_angle(drag_angle)
	var nrm := travel   # thickness / topple axis
	var base := carried_base()
	var top := drag_pos
	var half_l := travel.orthogonal() * Domino.LENGTH * 0.5
	var col := Color(0.95, 0.9, 0.8)
	if next >= 0:
		col = Color.from_hsv(fmod(float(next) / total_dominoes * 1.6, 1.0), 0.62, 0.95)
	# shadow on the desk under the bottom
	draw_set_transform(base + Vector2(2, 3), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 11, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# the hanging plank: top edge at the hand, bottom edge swung sideways
	var plank := PackedVector2Array([base - half_l, base + half_l, top + half_l, top - half_l])
	draw_colored_polygon(plank, col)
	var side := PackedVector2Array([base - half_l, base + half_l, base + half_l + nrm * 4, base - half_l + nrm * 4])
	draw_colored_polygon(side, col.darkened(0.35))
	draw_polyline(Domino._closed(plank), Color(0, 0, 0, 0.3), 1.0)
	draw_circle((plank[2] + plank[3]) * 0.5 + Vector2(0, 6), 1.6, Color(1, 1, 1, 0.6))
	# fingers pinching the top
	draw_circle(top + Vector2(-5, -3), 5, Color(0.93, 0.76, 0.6))
	draw_circle(top + Vector2(5, -3), 5, Color(0.93, 0.76, 0.6))
	# plumb line + landing marker: green when hanging straight
	var straight := absf(swing) <= straight_swing
	var mcol := Color(0.6, 1.0, 0.6, 0.9) if straight else (Color(1, 0.8, 0.4, 0.9) if absf(swing) <= topple_swing else Color(1, 0.4, 0.35, 0.9))
	draw_line(top, top + Vector2(0, Domino.HEIGHT), Color(1, 1, 1, 0.25), 1.0)
	draw_set_transform(base, 0, Vector2(1, squash))
	draw_arc(Vector2.ZERO, 7, 0, TAU, 16, mcol, 2.0)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if next >= 0:
		var g: Vector2 = slots[next]["pos"]
		if base.distance_to(g) > slot_tolerance * 1.5:
			draw_line(base, g, Color(1, 1, 1, 0.25), 1.0)

func _draw_hands() -> void:
	var skin := Color(0.93, 0.76, 0.6, 0.78)
	var shade := Color(0.75, 0.55, 0.42, 0.78)
	for side in [-1.0, 1.0]:
		var c := Vector2(side * 125, 30)
		draw_set_transform(c, side * -0.25, Vector2(1, 1))
		draw_circle(Vector2(0, 0), 46, shade)
		draw_set_transform(c, side * -0.25, Vector2(0.8, 1.35))
		draw_circle(Vector2(0, -10), 46, skin)
		draw_set_transform(c, side * -0.25, Vector2.ONE)
		for f in 4:
			var fx := -30 + f * 20
			draw_set_transform(c + Vector2(fx, -70), side * -0.25 + (f - 1.5) * 0.12, Vector2(0.45, 1.0))
			draw_circle(Vector2.ZERO, 22, skin)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(_font, Vector2(-70, 120), "ĐANG CHE CHẮN", HORIZONTAL_ALIGNMENT_CENTER, 140, 16, Color(1, 0.9, 0.6))
