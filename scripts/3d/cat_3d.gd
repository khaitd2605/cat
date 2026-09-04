class_name Cat3D
extends InteractableObject3D
## Box-and-sphere cat. Same verb API as the 2D Cat:
## look() walk() sit_near() crouch() jump_to(target, on_land) shoo() sleep()
## plus set_interest(global_pos) - the spot it currently has its eye on.
##
## It does not walk at that spot in a straight line. It prowls a lazy loop
## around the player's side of the desk first, then closes in on the desk edge
## in line with the target and crouches there. A cat that beelines is trivial to
## read; one that wanders makes the player keep glancing away from the dominoes.

enum State { SLEEP, LOOK, WALK, NEAR, CROUCH, JUMP, LANDED }

signal shooed

## How far out the wandering waypoints sit from the spot the cat is eyeing.
@export var prowl_radius := 3.4
## The cat stays on the player's side of the desk: no waypoint ever sits closer
## than this in z, so it never strolls straight through the domino run.
@export var keep_out_z := 2.6
## Metres per second on the prowl. Every leg's length sets its own duration, so
## short hops stay short instead of being stretched to a fixed time.
@export var walk_speed := 3.2
## The desk runs to z = 4.3 and x = +-7.5; keep the prowl inside it so the cat
## never walks out over the edge into thin air.
## Anh Khai's eye again, and the same note as the robot: the model was built at
## a size that made sense on its own and read as an enormous cat once it stood
## next to a domino. Everything visual hangs off `_rig`, so the scale lives in
## one place and never fights the squash-and-stretch that `_body` is rewriting
## every frame. The click box is scaled with it, by hand, because the hover
## label is positioned from the box and must not shrink with the drawing.
const SCALE := 0.75

const EDGE_Z := 4.0
const EDGE_X := 6.4

var state: State = State.SLEEP
var sleep_pos: Vector3
var _interest := Vector3.ZERO      # parent-local; what the cat is aiming at
var _t := 0.0
var _rig: Node3D
var _body: Node3D
var _head: Node3D
var _eyes: Array[MeshInstance3D] = []
var _tail: MeshInstance3D
var _move_tween: Tween
var _jump_from := Vector3.ZERO
var _jump_to := Vector3.ZERO
var _jump_t := -1.0
var _on_land: Callable
var _prev_pos := Vector3.ZERO
var _face := 0.0

func _ready() -> void:
	hit_size = Vector3(2.2, 1.6, 1.6) * SCALE
	hit_offset = Vector3(0, 0.7, 0) * SCALE
	super._ready()
	sleep_pos = position
	_prev_pos = position
	_interest = position
	hover_label = "Vuốt mèo"
	_build()

func _build() -> void:
	var fur := Color(0.24, 0.24, 0.29)
	var white := Color(0.94, 0.93, 0.9)
	_rig = Node3D.new()
	_rig.scale = Vector3.ONE * SCALE
	add_child(_rig)
	_body = Node3D.new()
	_rig.add_child(_body)
	var torso := box(Vector3(1.5, 0.7, 0.8), fur, Vector3(0.1, 0.4, 0))
	_body.add_child(torso)
	_body.add_child(box(Vector3(0.9, 0.3, 0.6), white, Vector3(-0.1, 0.16, 0)))
	_body.add_child(box(Vector3(0.25, 0.25, 0.25), white, Vector3(-0.6, 0.12, 0.25)))
	_body.add_child(box(Vector3(0.25, 0.25, 0.25), white, Vector3(-0.6, 0.12, -0.25)))
	_head = Node3D.new()
	_head.position = Vector3(-0.85, 0.75, 0)
	_body.add_child(_head)
	_head.add_child(sphere(0.38, fur))
	_head.add_child(sphere(0.2, white, Vector3(-0.25, -0.08, 0)))
	for side in [-1.0, 1.0]:
		var ear := box(Vector3(0.18, 0.28, 0.1), fur, Vector3(0.05, 0.4, side * 0.22))
		ear.rotation.x = side * 0.3
		_head.add_child(ear)
		var eye := sphere(0.06, Color(0.85, 0.9, 0.3), Vector3(-0.32, 0.06, side * 0.14))
		eye.visible = false
		_head.add_child(eye)
		_eyes.append(eye)
	_head.add_child(sphere(0.04, Color(0.9, 0.55, 0.6), Vector3(-0.4, -0.06, 0)))
	_tail = box(Vector3(1.0, 0.12, 0.12), fur, Vector3(1.2, 0.5, 0.2))
	_body.add_child(_tail)

func _set_state(s: State) -> void:
	if state == s:
		return
	state = s
	if _move_tween:
		_move_tween.kill()
	for e in _eyes:
		e.visible = s != State.SLEEP
	match s:
		State.SLEEP:
			hover_label = "Vuốt mèo"
			_walk_route([sleep_pos], walk_speed * 1.3)
		State.WALK:
			hover_label = "Xua mèo!"
			_walk_route(_prowl_route(), walk_speed)
		State.NEAR:
			hover_label = "Xua mèo!"
			_walk_route([_edge_spot()], walk_speed * 0.8)
		State.LOOK, State.CROUCH:
			hover_label = "Xua mèo!"
		State.JUMP:
			hover_label = ""

# --------------------------------------------------------------- prowling

## What the cat is after, in the parent's space. Kept at the cat's own height so
## a target on the desk never drags it up or down.
func set_interest(global_pos: Vector3) -> void:
	var p: Vector3 = get_parent().to_local(global_pos) if get_parent() is Node3D else global_pos
	_interest = Vector3(p.x, position.y, p.z)

## One or two waypoints on the way over - the wander, not the destination.
func _prowl_route() -> Array[Vector3]:
	var route: Array[Vector3] = []
	for i in randi_range(1, 2):
		route.append(_wander_point())
	return route

## Somewhere roughly a prowl_radius out from the target, always on the player's
## side of the desk (+z half only) and never inside the run.
func _wander_point() -> Vector3:
	var a := randf_range(0.2, PI - 0.2)
	var r := randf_range(prowl_radius * 0.5, prowl_radius)
	return Vector3(
		clampf(_interest.x + cos(a) * r, -EDGE_X, EDGE_X),
		position.y,
		clampf(_interest.z + sin(a) * r, keep_out_z, EDGE_Z))

## The desk edge right in front of the target: close enough to pounce from, far
## enough out that the cat is not already standing among the dominoes.
func _edge_spot() -> Vector3:
	return Vector3(
		clampf(_interest.x, -EDGE_X, EDGE_X),
		position.y,
		clampf(_interest.z + 1.9, keep_out_z, EDGE_Z))

## Chain waypoints into a single tween, each leg timed by its own length so the
## cat keeps one steady pace whether the hop is short or across the whole desk.
func _walk_route(route: Array[Vector3], speed: float) -> void:
	if route.is_empty():
		return
	_move_tween = create_tween()
	var from := position
	for p in route:
		_move_tween.tween_property(self, "position", p, maxf(from.distance_to(p) / speed, 0.3)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		from = p

# --------------------------------------------------------------- verb API

func look() -> void: _set_state(State.LOOK)
func walk() -> void: _set_state(State.WALK)
func sit_near() -> void: _set_state(State.NEAR)
func crouch() -> void: _set_state(State.CROUCH)
func sleep() -> void: _set_state(State.SLEEP)

func jump_to(target_global: Vector3, on_land := Callable()) -> void:
	_set_state(State.JUMP)
	_jump_from = position
	_jump_to = get_parent().to_local(target_global) if get_parent() is Node3D else target_global
	_jump_t = 0.0
	_on_land = on_land

func shoo() -> void:
	shooed.emit()
	_set_state(State.SLEEP)

func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	if state == State.JUMP and _jump_t >= 0.0:
		_jump_t = min(_jump_t + delta / 0.6, 1.0)
		position = _jump_from.lerp(_jump_to, _jump_t) + Vector3(0, 2.2 * sin(PI * _jump_t), 0)
		if _jump_t >= 1.0:
			state = State.LANDED
			_jump_t = -1.0
			Sfx.play("thud")
			if _on_land.is_valid():
				_on_land.call()
	# body language
	var breathe := sin(_t * 1.5) * 0.02 if state == State.SLEEP else 0.0
	var bob := absf(sin(_t * 9.0)) * 0.08 if state == State.WALK else 0.0
	var wiggle := sin(_t * 18.0) * 0.04 if state == State.CROUCH else 0.0
	var squash := Vector3.ONE
	match state:
		State.CROUCH: squash = Vector3(1.1, 0.75, 1.1)
		State.NEAR: squash = Vector3(0.9, 1.25, 0.95)
		State.LOOK: squash = Vector3(1.0, 1.08, 1.0)
		State.JUMP: squash = Vector3(0.9, 1.15, 0.9)
	_body.scale = squash + Vector3(0, breathe, 0)
	_body.position = Vector3(wiggle, bob, 0)
	_head.position.y = 0.75 + (0.25 if state in [State.LOOK, State.NEAR, State.CROUCH] else 0.0) - (0.15 if state == State.SLEEP else 0.0)
	_head.rotation.z = -0.35 if state in [State.LOOK, State.NEAR, State.CROUCH] else 0.0
	_tail.rotation.y = sin(_t * (3.0 if state != State.CROUCH else 14.0)) * 0.5
	_update_facing(delta)

## The model is built looking down -x, so facing `dir` means yaw = atan2(dz, -dx).
## Walking, it looks where it is going; standing still it stares at whatever it
## is stalking; asleep it settles back to its original pose.
func _update_facing(delta: float) -> void:
	var moved := position - _prev_pos
	_prev_pos = position
	if Vector2(moved.x, moved.z).length() > 0.002:
		_face = atan2(moved.z, -moved.x)
	elif state == State.SLEEP:
		_face = 0.0
	elif state != State.JUMP:
		var to := _interest - position
		if Vector2(to.x, to.z).length() > 0.1:
			_face = atan2(to.z, -to.x)
	rotation.y = lerp_angle(rotation.y, _face, minf(delta * 7.0, 1.0))
