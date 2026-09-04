class_name Window3D
extends InteractableObject3D
## Window on the back wall: a pair of casement leaves hinged on the OUTER jambs
## and meeting in the middle with no mullion between them, so the gap opens at
## the centre. They swing into the room, the way a window the wind leans on does
## - and outward is not an option here anyway, the back wall is right behind.
## The wind never takes both leaves at once. One gives first, the other follows
## a random beat later - two separate things to catch out of the corner of the
## eye, instead of one symmetrical flourish the player learns to ignore.
## Same API as the 2D WindowObject: set_open(), is_open.

signal opened
signal closed

## How far a leaf swings in. 1.1 rad is ~63 deg: wide enough to read at a glance,
## short of the curtain panels hanging either side of the opening.
const SWING := 1.1
## Half the opening's width. The jambs stand here and the leaves hinge just inside.
const HALF := 1.8
## Seconds between the first leaf giving and the second one following.
const FOLLOW_MIN := 0.9
const FOLLOW_MAX := 2.8
## How fast each leaf swings. Different per leaf, so two open ones never look
## geared to each other.
const RATE := [2.5, 2.1]
## Sign of the yaw that swings each leaf INTO the room, given its own hinge:
## hinged on opposite jambs, they must turn opposite ways to part in the middle.
const TURN := [-1.0, 1.0]

var is_open := false
var _sashes: Array[Node3D] = []
var _leaf_open := [false, false]
var _leaf_t := [0.0, 0.0]      # 0 = shut, 1 = fully swung
var _leaf_delay := [0.0, 0.0]  # seconds left before this leaf starts to move

func _ready() -> void:
	hit_size = Vector3(3.6, 3.0, 0.6)
	hit_offset = Vector3(0, 1.5, 0)
	super._ready()
	hover_label = "Cửa sổ"
	_build()

func _build() -> void:
	var frame := Color(0.36, 0.22, 0.13)
	# fixed frame: head, foot and the two jambs the leaves hinge on
	add_child(box(Vector3(3.6, 0.15, 0.3), frame, Vector3(0, 0, 0)))
	add_child(box(Vector3(3.6, 0.15, 0.3), frame, Vector3(0, 3.0, 0)))
	add_child(box(Vector3(0.15, 3.0, 0.3), frame, Vector3(-HALF, 1.5, 0)))
	add_child(box(Vector3(0.15, 3.0, 0.3), frame, Vector3(HALF, 1.5, 0)))
	add_child(box(Vector3(4.2, 0.12, 0.7), Color(0.5, 0.33, 0.2), Vector3(0, -0.06, 0.2)))  # sill
	# deliberately NO centre post: the two leaves part right there
	_sashes = [_build_sash(-1.0), _build_sash(1.0)]
	# night outside: dark blue plane behind, bushes in front of it
	add_child(box(Vector3(3.4, 2.8, 0.02), Color(0.1, 0.2, 0.28), Vector3(0, 1.5, -0.6)))
	for p in [Vector3(-1.2, 0.9, -0.5), Vector3(1.2, 0.8, -0.5), Vector3(0.0, 0.6, -0.5)]:
		add_child(sphere(0.4, Color(0.12, 0.26, 0.18), p))

## One leaf, hinged on its own jamb (side -1 = left, +1 = right) and reaching in
## to the centre. Every offset is mirrored through `side`, so the two leaves are
## the same object twice and their meeting stiles always land on x = 0.
func _build_sash(side: float) -> Node3D:
	var frame := Color(0.36, 0.22, 0.13)
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.3, 0.5, 0.6, 0.45)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.emission_enabled = true
	glass_mat.emission = Color(0.2, 0.4, 0.5)
	glass_mat.emission_energy_multiplier = 0.35
	var sash := Node3D.new()
	sash.position = Vector3(side * (HALF - 0.06), 0, 0)   # the hinge, just inside the jamb
	add_child(sash)
	var mid := -side * 0.87                               # pane centre, back toward x = 0
	var pane := box(Vector3(1.7, 2.8, 0.04), Color.WHITE, Vector3(mid, 1.5, 0))
	pane.material_override = glass_mat
	sash.add_child(pane)
	sash.add_child(box(Vector3(1.75, 0.12, 0.14), frame, Vector3(mid, 0.1, 0)))
	sash.add_child(box(Vector3(1.75, 0.12, 0.14), frame, Vector3(mid, 2.9, 0)))
	sash.add_child(box(Vector3(0.12, 2.9, 0.14), frame, Vector3(-side * 1.72, 1.5, 0)))  # meeting stile
	sash.add_child(box(Vector3(0.08, 2.8, 0.1), frame, Vector3(mid, 1.5, 0)))            # glazing bars
	sash.add_child(box(Vector3(1.7, 0.08, 0.1), frame, Vector3(mid, 1.5, 0)))
	return sash

func set_open(open: bool) -> void:
	if is_open == open:
		return
	is_open = open
	hover_label = "Đóng cửa sổ" if open else "Cửa sổ"
	if open:
		# one leaf gives straight away, the other a random beat later; which of
		# the two leads is a coin toss, so neither the order nor the timing repeats
		var lead := randi() % 2
		var follow := randf_range(FOLLOW_MIN, FOLLOW_MAX)
		for i in 2:
			_leaf_open[i] = true
			_leaf_delay[i] = 0.0 if i == lead else follow
		opened.emit()
	else:
		# closing is the player's doing (or the wind dying): both shut at once
		for i in 2:
			_leaf_open[i] = false
			_leaf_delay[i] = 0.0
		closed.emit()

func _process(delta: float) -> void:
	super._process(delta)
	for i in 2:
		if _leaf_delay[i] > 0.0:
			_leaf_delay[i] -= delta
			if _leaf_delay[i] <= 0.0:
				Sfx.play("creak", -7.0)   # the follower needs its own cue, or it opens silently
			continue
		_leaf_t[i] = move_toward(_leaf_t[i], 1.0 if _leaf_open[i] else 0.0, delta * RATE[i])
		_sashes[i].rotation.y = _leaf_t[i] * SWING * TURN[i]
