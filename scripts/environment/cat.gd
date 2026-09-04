class_name Cat
extends InteractableObject
## The cat. Sleeps on the right side of the desk; the CatEvent walks it
## through LOOK -> WALK -> CROUCH -> JUMP. Clicking it shoos it back to sleep.

enum State { SLEEP, LOOK, WALK, NEAR, CROUCH, JUMP, LANDED }

signal shooed

var state: State = State.SLEEP
var sleep_pos: Vector2
var approach_pos: Vector2
var _t := 0.0
var _jump_from := Vector2.ZERO
var _jump_to := Vector2.ZERO
var _jump_t := 0.0
var _move_tween: Tween
var _on_land: Callable

func _ready() -> void:
	hit_size = Vector2(190, 130)
	hit_offset = Vector2(-10, -35)
	super._ready()
	sleep_pos = position
	approach_pos = position + Vector2(-170, 20)
	hover_label = "Vuốt mèo"

func set_state(s: State) -> void:
	if state == s:
		return
	state = s
	if _move_tween:
		_move_tween.kill()
	match s:
		State.SLEEP:
			hover_label = "Vuốt mèo"
			_move_to(sleep_pos, 1.2)
		State.LOOK:
			hover_label = "Xua mèo!"
		State.WALK:
			hover_label = "Xua mèo!"
			_move_to(approach_pos, 2.6)
		State.NEAR:
			hover_label = "Xua mèo!"
		State.CROUCH:
			hover_label = "Xua mèo!"
		State.JUMP:
			hover_label = ""
	queue_redraw()

func _move_to(target: Vector2, duration: float) -> void:
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func jump_to(target_global: Vector2, on_land := Callable()) -> void:
	set_state(State.JUMP)
	_jump_from = position
	_jump_to = target_global
	_jump_t = 0.0
	_on_land = on_land

func shoo() -> void:
	shooed.emit()
	set_state(State.SLEEP)

# verb API shared with Cat3D (events are duck-typed)
func look() -> void: set_state(State.LOOK)
func walk() -> void: set_state(State.WALK)
func sit_near() -> void: set_state(State.NEAR)
func crouch() -> void: set_state(State.CROUCH)
func sleep() -> void: set_state(State.SLEEP)

func _process(delta: float) -> void:
	_t += delta
	if state == State.JUMP:
		_jump_t = min(_jump_t + delta / 0.55, 1.0)
		position = _jump_from.lerp(_jump_to, _jump_t) + Vector2(0, -150.0 * sin(PI * _jump_t))
		if _jump_t >= 1.0:
			state = State.LANDED
			Sfx.play("thud")
			if _on_land.is_valid():
				_on_land.call()
	queue_redraw()

func _draw() -> void:
	var fur := Color(0.24, 0.24, 0.29)
	var fur_light := Color(0.34, 0.34, 0.4)
	var white := Color(0.94, 0.93, 0.9)
	var walking := state == State.WALK
	var bob := sin(_t * 9.0) * 3.0 if walking else 0.0
	var breathe := sin(_t * 1.5) * 1.5 if state == State.SLEEP else 0.0
	var wiggle := sin(_t * 18.0) * 3.0 if state == State.CROUCH else 0.0
	var body_scale := Vector2(1, 1)
	match state:
		State.CROUCH: body_scale = Vector2(1.1, 0.78)
		State.JUMP: body_scale = Vector2(0.9, 1.15)
		State.LOOK: body_scale = Vector2(1.0, 1.05)
		State.WALK: body_scale = Vector2(0.95, 1.08)
		State.NEAR: body_scale = Vector2(0.9, 1.2)   # sitting up, staring

	# shadow (stays on the table while jumping)
	var shadow_off := Vector2(0, 150.0 * sin(PI * _jump_t)) if state == State.JUMP else Vector2.ZERO
	draw_set_transform(Vector2(0, 8) + shadow_off, 0, Vector2(1, 0.32))
	draw_circle(Vector2.ZERO, 62, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# tail
	var tail := PackedVector2Array()
	for i in 9:
		var k := i / 8.0
		var wag := sin(_t * (3.0 if state != State.CROUCH else 14.0) + k * 3.0) * 12.0 * k
		tail.append(Vector2(48 + k * 55, -22 - k * 30 * (0.4 if state == State.SLEEP else 1.0) + wag))
	draw_polyline(tail, fur, 9.0)
	draw_polyline(tail, fur_light, 4.0)

	# body
	draw_set_transform(Vector2(wiggle, -20 + breathe + bob), 0, body_scale * Vector2(1, 0.6))
	draw_circle(Vector2.ZERO, 55, fur)
	draw_set_transform(Vector2(wiggle - 4, -14 + breathe + bob), 0, body_scale * Vector2(0.65, 0.42))
	draw_circle(Vector2.ZERO, 40, white)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# paws
	var paw_y := 2 + bob * 0.5
	draw_set_transform(Vector2(-40 + wiggle, paw_y), 0, Vector2(1, 0.55))
	draw_circle(Vector2.ZERO, 11, white)
	draw_set_transform(Vector2(-18 + wiggle, paw_y - bob), 0, Vector2(1, 0.55))
	draw_circle(Vector2.ZERO, 11, white)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# head
	var head := Vector2(-50 + wiggle, -42 + breathe + bob)
	if state == State.LOOK or state == State.CROUCH or state == State.WALK:
		head.y -= 12
	if state == State.NEAR:
		head.y -= 22
	if state == State.SLEEP:
		head.y += 8
	draw_colored_polygon(PackedVector2Array([head + Vector2(-22, -14), head + Vector2(-26, -40), head + Vector2(-6, -22)]), fur)
	draw_colored_polygon(PackedVector2Array([head + Vector2(22, -14), head + Vector2(26, -40), head + Vector2(6, -22)]), fur)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-20, -16), head + Vector2(-23, -34), head + Vector2(-9, -21)]), Color(0.85, 0.6, 0.6))
	draw_colored_polygon(PackedVector2Array([head + Vector2(20, -16), head + Vector2(23, -34), head + Vector2(9, -21)]), Color(0.85, 0.6, 0.6))
	draw_circle(head, 26, fur)
	draw_circle(head + Vector2(-4, 6), 15, white)
	# eyes
	if state == State.SLEEP:
		draw_arc(head + Vector2(-11, -2), 5, 0.2, PI - 0.2, 8, Color(0.1, 0.1, 0.1), 2.0)
		draw_arc(head + Vector2(9, -2), 5, 0.2, PI - 0.2, 8, Color(0.1, 0.1, 0.1), 2.0)
		draw_string(_font, head + Vector2(20, -40 + sin(_t * 2.0) * 4.0), "z z", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))
	else:
		var look := Vector2(-2, 0) if state != State.LOOK else Vector2(-3, 1)
		var wide := state == State.CROUCH or state == State.NEAR
		for ex in [-11.0, 9.0]:
			draw_set_transform(head + Vector2(ex, -3), 0, Vector2(1, 1.25))
			draw_circle(Vector2.ZERO, 5.5 if not wide else 6.5, Color(0.85, 0.9, 0.3))
			draw_circle(look, 2.6 if not wide else 4.2, Color(0.05, 0.05, 0.05))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# nose + whiskers
	draw_colored_polygon(PackedVector2Array([head + Vector2(-5, 6), head + Vector2(1, 6), head + Vector2(-2, 10)]), Color(0.9, 0.55, 0.6))
	for wy in [4.0, 9.0]:
		draw_line(head + Vector2(-8, wy), head + Vector2(-34, wy - 4 + wy * 0.6), Color(1, 1, 1, 0.5), 1.0)
		draw_line(head + Vector2(4, wy), head + Vector2(30, wy - 4 + wy * 0.6), Color(1, 1, 1, 0.5), 1.0)

	if state != State.JUMP and state != State.LANDED:
		draw_hover(Vector2(-5, -30), 78)
