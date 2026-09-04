class_name Cat3D
extends InteractableObject3D
## Box-and-sphere cat. Same verb API as the 2D Cat:
## look() walk() sit_near() crouch() jump_to(target, on_land) shoo() sleep()

enum State { SLEEP, LOOK, WALK, NEAR, CROUCH, JUMP, LANDED }

signal shooed

var state: State = State.SLEEP
var sleep_pos: Vector3
var approach_pos: Vector3
var _t := 0.0
var _body: Node3D
var _head: Node3D
var _eyes: Array[MeshInstance3D] = []
var _tail: MeshInstance3D
var _move_tween: Tween
var _jump_from := Vector3.ZERO
var _jump_to := Vector3.ZERO
var _jump_t := -1.0
var _on_land: Callable

func _ready() -> void:
	hit_size = Vector3(2.2, 1.6, 1.6)
	hit_offset = Vector3(0, 0.7, 0)
	super._ready()
	sleep_pos = position
	approach_pos = position + Vector3(-2.4, 0, -0.9)
	hover_label = "Vuốt mèo"
	_build()

func _build() -> void:
	var fur := Color(0.24, 0.24, 0.29)
	var white := Color(0.94, 0.93, 0.9)
	_body = Node3D.new()
	add_child(_body)
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
			_move_to(sleep_pos, 1.4)
		State.LOOK, State.NEAR, State.CROUCH:
			hover_label = "Xua mèo!"
		State.WALK:
			hover_label = "Xua mèo!"
			_move_to(approach_pos, 2.8)
		State.JUMP:
			hover_label = ""

func _move_to(target: Vector3, duration: float) -> void:
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# verb API
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
	# the cat always faces the dominoes (-x)
	rotation.y = 0.0
