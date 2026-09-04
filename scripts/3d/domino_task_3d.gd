class_name DominoTask3D
extends Node3D
## BUILD system, 3D + physics edition.
##
## The course gives you a START peg, a GOAL piece and a desk with obstacles on
## it. Where the run goes between those two is entirely yours - there are no
## slots to fill. Lay pieces close enough to pass the fall along, route around
## whatever is in the way, then push the first one and watch.
##
## WINNING IS CAUSAL, NOT POSITIONAL. "The goal is lying down" proves nothing:
## a careless hand knocks it over just as flat as a chain does. So every piece
## carries a `chain` flag that is set only by the player's own push and then
## rides along the same contacts the fall does. The goal counts only if it went
## down with that flag set - which no cat, gust or brush of the hand can fake.
##
## TWO PHASES, AND THEY DO NOT OVERLAP.
##
## While you are LAYING, the goal cannot be touched by anything at all - not the
## cat, not a gust, not your own hand. While you are PUSHING, the opposite is
## true: the goal is live, and every disruptive agent in the room is switched
## off. So the push judges exactly one thing, how you laid it; and the room
## judges exactly one thing, whether you can lay under pressure. Neither gets to
## spoil the other verdict, which is the whole reason the mechanic is fair.
##
## The player carries a piece by its TOP; the bottom swings like a pendulum.
## Releasing always DROPS it from `drop_height` and hands it to physics. While
## carried it is a real object in the room too: sweep the hand through what is
## already standing and you knock it down.
##
## Two different kinds of damage, two different prices.
##
## A RUN THAT DIES HALFWAY is stood back up exactly as it was built: it was a
## good run, it just had a hole in it, and the seconds the rebuild takes are the
## price. But a piece the cat or the wind knocked over MID-BUILD is swept off the
## desk instead, and you lay that stretch again by hand. Standing one lone piece
## back up would be free; making you rebuild the whole desk for it would be
## brutal. Sweeping is the price that actually matches the damage.
##
## The GOAL is never swept - it is the map, not your work, so it stands itself
## back up wherever it ends up.
##
## Shared API with the 2D DominoTask, used by the events / FocusSystem /
## FailureSystem: is_focusing(), placed_count(), standing_count(),
## get_progress(), focus_point_global(), landing_spot(), set_shaking(),
## set_shield(), shield_active, gust(), smash_at(), debug_place_next()

signal drag_started
signal drag_ended

## BUILD: laying pieces. RUN: the chain is travelling, hands off.
## RESTAND: the dead end is on show, then everything stands back up.
enum Phase { BUILD, RUN, RESTAND }

@export_group("Course")
@export var start_pos := Vector3(-5.2, 0, 2.4)
@export var goal_pos := Vector3(5.2, 0, -2.4)
## Half-extents of the playable desk area, in XZ.
@export var area_half := Vector2(6.2, 3.4)
@export var obstacle_count := 6
## How far apart two pieces may stand and still reliably pass the fall on. A
## piece is 1.0 tall so it could in theory reach further, but past this the
## chain starts dying on the odd wobble - a horrible way to lose. The guide ring
## is drawn at exactly this radius, so the ring is a promise, not a hint.
@export var reach := 0.68
## Impulse that starts the run, applied near the top of the first piece.
@export var trigger_force := 0.7
@export_group("Pendulum")
## Lower = a bigger, heavier swing: amplitude per flick of the hand is dv/sqrt(k),
## so softening the spring widens the swing and slows its beat.
@export var swing_stiffness := 28.0
## Lower = the swing takes longer to die down, so a steady hand has to wait
## longer before the drop is safe - which is time spent not watching the room.
@export var swing_damping := 1.5
## Share of every change in hand speed that goes into the swing. A flick that
## reaches 3 m/s injects 3 * this into swing_vel, whatever the frame rate.
@export var swing_from_hand := 0.7
## How much of max_swing the piece is ALREADY leaning the moment it is picked
## up. The hand never grabs it perfectly straight.
@export var pickup_swing := 0.6
## How far the bottom may swing out either way. 0.34 is a 19 deg lean, far past
## the 6.7 deg a piece can survive - so a big swing at release is a guaranteed
## topple, and topple_swing (0.11 = 6.3 deg) marks the real tipping point.
@export var max_swing := 0.34
## |swing| thresholds for the COLOUR HINTS only - physics, not these numbers,
## decides whether a dropped piece stands. World units at the bottom.
@export var straight_swing := 0.05
@export var topple_swing := 0.11
@export_group("Drop")
## Height of the piece's BOTTOM above the desk while it is carried.
@export var drop_height := 0.3
## XZ distance at which the carried piece counts as hitting a standing one.
@export var carry_hit_radius := 0.3
## Hand speed -> impulse. Low speed nudges and it may survive; a real swipe wipes.
@export var carry_hit_force := 0.5
@export_group("")
@export var tray_pos := Vector3(-6.5, 0, 3.6)
## Where the robot's dock stands, so clutter can be kept off it. It sits behind
## the play area, but the CAMERA looks along that line: a pen pot spawning two
## units in front of the dock does not touch it and still hides it completely,
## which was exactly what a screenshot showed. A dock you cannot see is a button
## you cannot find, so this clearance is wider than the tray's.
@export var dock_pos := Vector3(-2.4, 0, -3.55)
@export var camera_path: NodePath

const HEIGHT := 1.0
## How long a released piece is watched before its verdict is forced.
const SETTLE_TIMEOUT := 2.5
## How long "at rest" has to HOLD before a piece may be locked. A rocking piece
## is motionless for an instant at every turn of the rock - exactly when it
## leans furthest - so a single-frame sample would freeze it mid-lean.
const SETTLE_REST_HOLD := 0.25
## A run gets this long to reach the goal before its verdict is forced.
const RUN_TIMEOUT := 14.0
## The run must be under way this long before "everything is still" can mean
## anything: on the trigger frame nothing has moved yet.
const RUN_MIN := 0.6
## How long the dead end is left on show before the rebuild starts, so the
## player can see WHERE the chain died - that is the whole lesson.
const SHOW_GAP := 1.4
## Stagger between pieces standing back up: it rewinds from the peg outward.
const RESTAND_STEP := 0.045
## How near the peg counts as clicking it.
## How close to the peg counts as pressing GO - and, below, as being inside the
## peg itself. Kept well under the 0.48 the first piece stands at, so the button
## never silently swallows a legitimate placement spot next to the peg.
const PEG_RADIUS := 0.3
## How long a knocked-over piece takes to fade off the desk.
const SWEEP_TIME := 0.35
## The run's colours, in order. A fixed rainbow rather than a hue sweep: the
## repeating band is what makes a long run read as a RUN at a glance, and it is
## how you can see from across the desk which stretch you laid when.
const PALETTE: Array[Color] = [
	Color(0.90, 0.28, 0.28),   # red
	Color(0.95, 0.55, 0.22),   # orange
	Color(0.96, 0.80, 0.28),   # yellow
	Color(0.48, 0.76, 0.36),   # green
	Color(0.26, 0.72, 0.68),   # teal
	Color(0.32, 0.52, 0.85),   # blue
	Color(0.60, 0.42, 0.80),   # violet
]

static func palette_at(i: int) -> Color:
	return PALETTE[posmod(i, PALETTE.size())]

var phase: Phase = Phase.BUILD
var dominoes: Array[DominoBody] = []   # every piece on the desk, goal included
var goal: DominoBody
var obstacles: Array[Dictionary] = []  # { "pos": Vector3, "size": Vector3 }
var total_dominoes := 0                # estimate, for the HUD bar only
var shaking := false
var shield_active := false

var dragging := false
var drag_pos := Vector3.ZERO           # the hand (top of the carried piece)
var drag_angle := 0.0
var swing := 0.0
var swing_vel := 0.0
var debug_lock_hand := false
var _drag_prev := Vector3.ZERO
var _hand_vel := Vector3.ZERO          # last frame, to read the CHANGE in hand motion
var _carried: DominoBody
var _anchor := Vector3.ZERO            # the piece (or peg) the carried one aims away from

var _settling: DominoBody              # just released, still deciding whether it stands
var _settle_t := 0.0
var _settle_rest_t := 0.0

var _collapse_active := false
var _disturbed: Array[DominoBody] = []
var _collapse_standing_before := 0
var _collapse_rest_t := 0.0
var _last_disturb := 0.0
var _collapse_started := 0.0

var _run_t := 0.0
var _run_rest_t := 0.0

var _time := 0.0
var _pulse := 0.0
var _hover_hot := false

var _camera: Camera3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _base_ring: MeshInstance3D
var _base_mat: StandardMaterial3D
var _feedback: Label3D
var _feedback_t := 0.0
var _hands: Node3D
var _peg_label: Label3D
var _goal_label: Label3D
## Whether the "your run reaches the goal, push it" nudge has been given. Once
## is enough; repeating it every frame would be nagging.
var _told_ready := false
var _goal_mat: StandardMaterial3D
var _fingers: Node3D

func _ready() -> void:
	_camera = get_node(camera_path)
	_apply_level()
	_build_course()
	_build_visuals()
	_spawn_goal()
	total_dominoes = int(ceil(_xz_dist(start_pos, goal_pos) / reach))
	_emit_progress.call_deferred()

# --------------------------------------------------------------- course

## Put the clutter on the desk: a mug, a book, a pen pot, whatever DeskClutter
## picked. They keep clear of the peg, the goal and the tray, and of each other
## by a full domino step - so a route always exists. Routing around the mug is
## the difficulty; a desk you cannot cross would just be a bug.
##
## Each object carries its own footprint, so the spacing is worked out from the
## actual sizes rather than one number that happened to suit grey boxes: a book
## is 4.0 long and a pen pot 1.6, and treating them alike either overlapped the
## books or left the pots marooned in space.
## Take the course from the current level. The seed is the whole trick behind
## Anh Khai's choice of design: the clutter is still scattered by the generator,
## but from a fixed number, so a level is the same desk every time you come back
## to it and tuning one means nudging its seed until it plays well. `randomize()`
## afterwards hands the randomness back - the cat, the wind and the palette all
## draw from the same global stream and would otherwise repeat in lockstep.
func _apply_level() -> void:
	var lv := GameManager.level_def()
	start_pos = lv["start"]
	goal_pos = lv["goal"]
	obstacle_count = lv["obstacles"]
	seed(int(lv["seed"]))

func _build_course() -> void:
	obstacles.clear()
	var tries := 0
	while obstacles.size() < obstacle_count and tries < 400:
		tries += 1
		var used: Array = []
		for other in obstacles:
			used.append(other["kind"])
		var o := DeskClutter.pick(used)
		var half := DeskClutter.span(o) * 0.5
		var p := Vector3(
			randf_range(-area_half.x + half + 0.4, area_half.x - half - 0.4), 0.0,
			randf_range(-area_half.y + half + 0.4, area_half.y - half - 0.4))
		if _xz_dist(p, start_pos) < 1.4 + half or _xz_dist(p, goal_pos) < 1.4 + half:
			continue
		if _xz_dist(p, tray_pos) < 1.4 + half:
			continue
		if _xz_dist(p, dock_pos) < 2.2 + half:
			continue
		var clash := false
		for other in obstacles:
			# a gap a run can actually be laid through, not merely a gap
			if _xz_dist(p, other["pos"]) < half + DeskClutter.span(other) * 0.5 + 1.0:
				clash = true
				break
		if clash:
			continue
		o["pos"] = p
		obstacles.append(o)
	randomize()

static func travel_dir(angle: float) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle))

## Upright pose for a piece standing at `base` (y ignored) facing along `angle`.
static func standing_xform(base: Vector3, angle: float) -> Transform3D:
	var across := travel_dir(angle).cross(Vector3.UP).normalized()
	return Transform3D(
		Basis(across, Vector3.UP, across.cross(Vector3.UP).normalized()),
		Vector3(base.x, HEIGHT * 0.5, base.z))

func _spawn_goal() -> void:
	goal = DominoBody.new()
	goal.is_goal = true
	goal.setup(Color(1.0, 0.82, 0.3))
	goal.disturbed.connect(_on_disturbed)
	add_child(goal)
	# stand it side-on to the peg, so a chain arriving from there hits its face
	var to_goal := Vector3(goal_pos.x - start_pos.x, 0.0, goal_pos.z - start_pos.z)
	goal.global_transform = global_transform * standing_xform(goal_pos, atan2(to_goal.z, to_goal.x))
	goal.stand_flat()
	# Locked until you push. Anh Khai's very first worry about this mechanic was
	# that placing pieces might itself topple the goal; this removes the worry
	# outright rather than merely detecting it afterwards.
	goal.armed = false
	dominoes.append(goal)

# --------------------------------------------------------------- visuals

func _build_visuals() -> void:
	# The clutter: real static bodies, so a chain is genuinely stopped by the mug
	# rather than merely discouraged from being built through it. DeskClutter
	# builds each one standing on the desk surface, so y stays 0 here.
	for o in obstacles:
		var body := DeskClutter.build(o)
		var pos: Vector3 = o["pos"]
		body.position = Vector3(pos.x, 0.0, pos.z)
		add_child(body)

	# start peg - also the button that sets the run going
	var peg := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.28
	pm.bottom_radius = 0.34
	pm.height = 0.12
	peg.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.55, 0.85, 0.6)
	peg.material_override = pmat
	peg.position = Vector3(start_pos.x, 0.06, start_pos.z)
	add_child(peg)
	_peg_label = _make_label("BẮT ĐẦU", 0.24, Color(0.75, 1, 0.8, 0.85))
	_peg_label.position = Vector3(start_pos.x, 0.75, start_pos.z)
	add_child(_peg_label)

	# goal marker above the goal piece
	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.45, 0.28, 0.02)
	flag.mesh = fm
	_goal_mat = StandardMaterial3D.new()
	_goal_mat.albedo_color = Color(1.0, 0.85, 0.45)
	flag.material_override = _goal_mat
	# The flag hangs towards the middle of the desk, never off the near edge of the
	# frame. It used to always chibi out to the right, which is fine for a goal on
	# the left and wrong for every goal on the right: on the level 6 goal at x=5.4
	# the flag's far corner landed 25px outside the frame's safe margin, and the
	# generated desks draw their goals from the same anchors. One sign flip, and no
	# level coordinate has to move.
	flag.position = Vector3(goal_pos.x + 0.24 * flag_side(), 1.45, goal_pos.z)
	add_child(flag)
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.02
	cm.height = 0.6
	pole.mesh = cm
	pole.position = Vector3(goal_pos.x, 1.3, goal_pos.z)
	add_child(pole)
	_goal_label = _make_label("ĐÍCH", 0.26, Color(1, 0.9, 0.6, 0.9))
	var goal_label := _goal_label
	goal_label.position = Vector3(goal_pos.x, 1.9, goal_pos.z)
	add_child(goal_label)

	# reach ring: drawn at exactly `reach`, so what it promises is what physics does
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = reach - 0.035
	torus.outer_radius = reach
	_ring.mesh = torus
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.material_override = _ring_mat
	add_child(_ring)
	# marker under the carried bottom
	_base_ring = MeshInstance3D.new()
	var t2 := TorusMesh.new()
	t2.inner_radius = 0.06
	t2.outer_radius = 0.085
	_base_ring.mesh = t2
	_base_mat = StandardMaterial3D.new()
	_base_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_base_ring.material_override = _base_mat
	_base_ring.visible = false
	add_child(_base_ring)
	# tray of spares, parked off the playable area
	var tray := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(1.6, 0.25, 0.7)
	tray.mesh = tb
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.3, 0.18, 0.1)
	tray.material_override = tm
	tray.position = tray_pos + Vector3(0, 0.125, 0)
	add_child(tray)
	for i in 5:
		var spare := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = DominoBody.SIZE
		spare.mesh = bm2
		var sm := StandardMaterial3D.new()
		sm.albedo_color = palette_at(i)
		spare.material_override = sm
		spare.position = tray_pos + Vector3(-0.5 + i * 0.25, 0.75, 0)
		spare.rotation.z = 0.12 * (i - 2)
		add_child(spare)
	var tray_hint := _make_label("khay domino", 0.24, Color(1, 0.95, 0.85, 0.6))
	tray_hint.position = tray_pos + Vector3(0, 1.35, 0)
	add_child(tray_hint)

	_feedback = _make_label("", 0.34, Color.WHITE)
	_feedback.visible = false
	add_child(_feedback)
	# shield hands
	_hands = Node3D.new()
	_hands.visible = false
	add_child(_hands)
	for side in [-1.0, 1.0]:
		var hand := MeshInstance3D.new()
		var hcm := CapsuleMesh.new()
		hcm.radius = 0.45
		hcm.height = 1.6
		hand.mesh = hcm
		var hm := StandardMaterial3D.new()
		hm.albedo_color = Color(0.93, 0.76, 0.6, 0.85)
		hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hand.material_override = hm
		hand.position = Vector3(side * 2.2, 1.3, 0.2)
		hand.rotation.z = side * 0.5
		_hands.add_child(hand)
	var hl := _make_label("ĐANG CHE CHẮN", 0.34, Color(1, 0.9, 0.6))
	hl.position = Vector3(0, 2.4, 0.5)
	_hands.add_child(hl)
	# fingers pinching the top of the carried piece
	_fingers = Node3D.new()
	_fingers.visible = false
	add_child(_fingers)
	for side in [-1.0, 1.0]:
		var finger := MeshInstance3D.new()
		var fcap := CapsuleMesh.new()
		fcap.radius = 0.09
		fcap.height = 0.5
		finger.mesh = fcap
		var skin := StandardMaterial3D.new()
		skin.albedo_color = Color(0.93, 0.76, 0.6)
		finger.material_override = skin
		finger.position = Vector3(0, 0.18, side * 0.13)
		finger.rotation.x = side * 0.25
		_fingers.add_child(finger)

static func _make_label(text: String, size: float, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = 0.004
	l.font_size = int(size * 100)
	l.modulate = col
	l.outline_size = 6
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	return l

# --------------------------------------------------------------- queries (shared API)

func can_work() -> bool:
	return GameManager.is_playing()

## Is the room allowed to interfere right now?
##
## Only while you are LAYING. The moment you push, every disruptive agent is
## off - the run has to be decided by how you built it, not by whether the cat
## happened to land mid-fall. One gate, asked by the gust, by the cat, by the
## shaking, and by the scheduler that starts them.
func accepts_events() -> bool:
	return phase == Phase.BUILD and can_work()

func is_focusing() -> bool:
	return dragging

## Pieces of your own run still standing. The goal is not one of yours.
## Tell the HUD how far the run has got, as a percentage of the start-to-goal
## distance rather than a count of pieces.
##
## A count cannot be honest here: the player routes freely, so how many pieces
## the job takes is unknowable - the old estimate said 17 for a course that
## really needed 26 - and counting STANDING pieces made the bar empty itself at
## the exact moment of victory, when the whole run is lying down. Distance
## bridged has neither problem, and reads 100% precisely when the dominoes reach
## the goal. `full` is for the win, where every piece is down and there is no
## standing piece left to measure from.
func _emit_progress(full := false) -> void:
	EventBus.task_progress.emit(100 if full else int(round(get_progress() * 100.0)), 100)

func placed_count() -> int:
	var n := 0
	for d in dominoes:
		if not d.is_goal and not d.carried and d.is_standing():
			n += 1
	return n

func standing_count() -> int:
	var n := 0
	for d in dominoes:
		if not d.carried and d.is_standing():
			n += 1
	return n

## How much of the gap between peg and goal the run has bridged. This drives how
## fast the room turns against you, so it has to mean "closer to done", not
## "more pieces used" - a long detour around an obstacle is not progress.
func get_progress() -> float:
	var span := _xz_dist(start_pos, goal_pos)
	var best := span
	for d in dominoes:
		if d.is_goal or d.carried or not d.is_standing():
			continue
		best = minf(best, _xz_dist(d.position, goal_pos))
	return clampf(1.0 - best / maxf(span, 0.001), 0.0, 1.0)

## The standing piece of yours closest to the goal: the working end of the run.
func chain_head() -> DominoBody:
	var best: DominoBody = null
	var best_d := INF
	for d in dominoes:
		if d.is_goal or d.carried or not d.is_standing():
			continue
		var dist := _xz_dist(d.position, goal_pos)
		if dist < best_d:
			best_d = dist
			best = d
	return best

func focus_point_global() -> Vector3:
	if dragging:
		return to_global(drag_pos)
	return landing_spot()

## Where an incoming disaster should aim: the working end of the run, which is
## where the player is looking. A fixed point on the desk hit bare wood.
func landing_spot() -> Vector3:
	var head := chain_head()
	if head:
		return head.global_position
	return to_global(Vector3(start_pos.x, 0, start_pos.z))

## Hand height while carrying: the hand holds the TOP, so the bottom ends up
## exactly `drop_height` above the desk.
func hand_y() -> float:
	return HEIGHT + drop_height

func carried_base() -> Vector3:
	return drag_pos + Vector3(0, -HEIGHT, 0) + travel_dir(drag_angle) * swing

## What the piece under the hand should be aimed away from: the nearest standing
## piece of the run, or the peg if the run has not started. Nearest rather than
## last, so a gap in the middle can be patched with the very same gesture.
func _anchor_for(p: Vector3) -> Vector3:
	var best := Vector3(start_pos.x, 0, start_pos.z)
	var best_d := INF
	for d in dominoes:
		if d.is_goal or d.carried or not d.is_standing():
			continue
		var dist := _xz_dist(d.position, p)
		if dist < best_d:
			best_d = dist
			best = Vector3(d.position.x, 0, d.position.z)
	return best

# --------------------------------------------------------------- input

## Where the hand must be so the BOTTOM of the carried piece sits under the
## cursor's point on the desk.
func _hand_from_cursor() -> Vector3:
	return to_local(_mouse_on_plane(0.0)) + Vector3(0, hand_y(), 0)

func _mouse_on_plane(plane_y: float) -> Vector3:
	var mp := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mp)
	var dir := _camera.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		return Vector3(origin.x, plane_y, origin.z)
	var t := (plane_y - origin.y) / dir.y
	return origin + dir * t

func _unhandled_input(event: InputEvent) -> void:
	if not can_work():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not dragging:
			if _cursor_over_interactable():
				return
			if _try_pick(to_local(_mouse_on_plane(0.0))):
				get_viewport().set_input_as_handled()
		elif not event.pressed and dragging:
			_drop()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_trigger_run()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F2:
			debug_fill_route()
			get_viewport().set_input_as_handled()

func _try_pick(table_local: Vector3) -> bool:
	if phase != Phase.BUILD:
		EventBus.notify.emit(
			"Dây đang chạy - bỏ tay ra!" if phase == Phase.RUN else "Đang dựng lại...",
			Color(1.0, 0.85, 0.5))
		return true
	if _collapse_active:
		EventBus.notify.emit("Đang đổ - đợi yên đã!", Color(1.0, 0.85, 0.5))
		return true
	# the peg doubles as the GO button, but only once there is a piece for it to
	# push - otherwise the first placement could never be made on the peg itself
	if _xz_dist(table_local, start_pos) <= PEG_RADIUS and _starter() != null:
		_trigger_run()
		return true
	var on_tray := _xz_dist(table_local, tray_pos) <= 1.0
	var in_area := absf(table_local.x) <= area_half.x and absf(table_local.z) <= area_half.y
	if not (on_tray or in_area):
		return false
	if _settling != null and is_instance_valid(_settling):
		EventBus.notify.emit("Đợi quân vừa thả đứng yên đã!", Color(1.0, 0.85, 0.5))
		return true
	if shield_active:
		EventBus.notify.emit("Đang che chắn - bỏ tay ra mới xếp tiếp được!", Color(1.0, 0.8, 0.4))
		return true
	_begin_carry()
	return true

func _begin_carry() -> void:
	dragging = true
	drag_pos = _hand_from_cursor()
	_anchor = _anchor_for(Vector3(drag_pos.x, 0, drag_pos.z))
	drag_angle = _aim_from_anchor()
	_drag_prev = drag_pos
	_hand_vel = Vector3.ZERO
	swing = randf_range(-1.0, 1.0) * pickup_swing * max_swing
	swing_vel = randf_range(-1.3, 1.3)
	_carried = DominoBody.new()
	_carried.carried = true
	_carried.setup(palette_at(dominoes.size()))
	_carried.disturbed.connect(_on_disturbed)
	add_child(_carried)
	_place_carried_transform()
	Sfx.play("place", -12.0)
	drag_started.emit()

## Face the piece along the line from its anchor to the hand, so it always falls
## onward down the run. Position is the only thing left for the player to get
## right, which is plenty to be going on with.
func _aim_from_anchor() -> float:
	var d := Vector3(drag_pos.x - _anchor.x, 0.0, drag_pos.z - _anchor.z)
	return atan2(d.z, d.x) if d.length() > 0.05 else drag_angle

func _place_carried_transform() -> void:
	var top := drag_pos
	var base := carried_base()
	var axis := (top - base).normalized()
	var across := travel_dir(drag_angle).cross(Vector3.UP).normalized()
	_carried.global_transform = global_transform * Transform3D(
		Basis(across, axis, across.cross(axis).normalized()), (top + base) * 0.5)

## Why this spot will not take a piece, or an empty string if it will.
func _placement_problem(base: Vector3) -> String:
	if absf(base.x) > area_half.x or absf(base.z) > area_half.y:
		return "Ngoài vùng chơi"
	if _xz_dist(base, start_pos) < PEG_RADIUS:
		return "Vướng cọc BẮT ĐẦU"
	for o in obstacles:
		var op: Vector3 = o["pos"]
		var sz: Vector3 = o["size"]
		if absf(base.x - op.x) < sz.x * 0.5 + 0.2 and absf(base.z - op.z) < sz.z * 0.5 + 0.2:
			return "Vướng vật cản"
	for d in dominoes:
		if d.carried:
			continue
		var dist := _xz_dist(d.position, base)
		if not d.is_standing() and dist < 0.6:
			return "Còn quân đổ ở đó"
		if d.is_standing() and dist < 0.26:
			return "Sát quân khác quá"
	return ""

func _drop() -> void:
	dragging = false
	drag_ended.emit()
	var d := _carried
	_carried = null
	var base := carried_base()
	var problem := _placement_problem(base)
	if problem != "":
		d.queue_free()
		_show_feedback(problem, Color(1, 0.85, 0.5), base)
		Sfx.play("place", -14.0)
		return
	d.carried = false
	dominoes.append(d)
	# Hand it to physics exactly as the hand held it: bottom `drop_height` above
	# the desk, tilted by the current swing and turning at the pendulum's rate.
	# It falls, it lands, gravity decides. The verdict comes in _update_settle().
	var tilt := absf(swing)
	var bottom := Vector3(base.x, drop_height, base.z)
	var axis := (drag_pos - bottom).normalized()
	var across := travel_dir(drag_angle).cross(Vector3.UP).normalized()
	d.global_transform = global_transform * Transform3D(
		Basis(across, axis, across.cross(axis).normalized()), (drag_pos + bottom) * 0.5)
	# Remember where it was MEANT to stand before physics gets it. A piece that
	# topples on its very first drop is never locked, so without this it would
	# have no pose to be stood back up into - it would lie there for the rest of
	# the game, blocking its own spot, with no way at all to clear it.
	d.placed_xform = global_transform * standing_xform(base, drag_angle)
	d.has_place = true
	_settling = d
	_settle_t = 0.0
	_settle_rest_t = 0.0
	d.wake()
	d.angular_velocity = across * (swing_vel / HEIGHT)
	Sfx.play("miss" if tilt > topple_swing else "place", -3.0)
	if tilt > topple_swing:
		_show_feedback("Thả lúc đang lắc!", Color(1, 0.45, 0.4), base)
	elif tilt > straight_swing:
		_show_feedback("Hơi nghiêng...", Color(1, 0.9, 0.6), base)
	_emit_progress()

# --------------------------------------------------------------- the run

## The piece the peg pushes: the one of yours nearest the peg, close enough that
## a shove at the peg would actually reach it.
func _starter() -> DominoBody:
	var best: DominoBody = null
	var best_d := reach
	for d in dominoes:
		if d.is_goal or d.carried or not d.is_standing():
			continue
		var dist := _xz_dist(d.position, start_pos)
		if dist < best_d:
			best_d = dist
			best = d
	return best

func _trigger_run() -> void:
	if phase != Phase.BUILD or dragging or not can_work():
		return
	if _settling != null and is_instance_valid(_settling):
		EventBus.notify.emit("Đợi quân vừa thả đứng yên đã!", Color(1.0, 0.85, 0.5))
		return
	if _collapse_active:
		EventBus.notify.emit("Đợi mọi thứ đứng yên đã!", Color(1.0, 0.85, 0.5))
		return
	# is_upright(), not is_standing(): the latter tolerates a 26 deg lean, and a
	# goal the cat left resting past its own tipping point would then be pushed
	# over by the faintest nudge and counted as the player's doing.
	if not goal.is_upright():
		EventBus.notify.emit("Quân ĐÍCH đang nghiêng - đợi nó đứng lại đã!", Color(1, 0.6, 0.45))
		return
	var first := _starter()
	if first == null:
		EventBus.notify.emit("Chưa có quân nào ở vạch BẮT ĐẦU.", Color(1.0, 0.85, 0.5))
		return
	phase = Phase.RUN
	goal.armed = true        # from here on it is fair game - for the chain only
	_run_t = 0.0
	_run_rest_t = 0.0
	var push := Vector3(first.position.x - start_pos.x, 0.0, first.position.z - start_pos.z)
	if push.length() < 0.05:
		push = travel_dir(0.0)
	# wake(true) is the ONLY place the chain flag is ever set true; from here it
	# travels from piece to piece through DominoBody._on_body_entered
	first.wake(true)
	first.apply_impulse(push.normalized() * trigger_force, Vector3(0, 0.4, 0))
	Sfx.play("thud", -4.0)
	# Built from the level rather than written once. It used to name the cat and the
	# wind on every desk, including level 1, whose entire premise is that nothing is
	# attacking it - and it never mentioned the robot, which on the later desks is
	# the thing that actually stops. A line that lists hazards you never met teaches
	# the player that the game's own messages are decoration.
	var lv := GameManager.level_def()
	var quiet: Array[String] = []
	if lv["wind"]:
		quiet.append("gió")
	if lv["cat"]:
		quiet.append("mèo")
	if lv["robot"]:
		quiet.append("robot")
	var line := "ĐẨY RỒI! Giờ chỉ còn dây của anh."
	if not quiet.is_empty():
		# Commas for all but the last, "và" before it - "gió, mèo và robot", the way
		# it is said. And NOT String.capitalize(): that title-cases every word, so
		# the first attempt shipped "Gió Và Mèo Và Robot".
		var names: String = quiet[0]
		for k in range(1, quiet.size()):
			names += (" và " if k == quiet.size() - 1 else ", ") + quiet[k]
		names = names.substr(0, 1).to_upper() + names.substr(1)
		line = "ĐẨY RỒI! %s nghỉ - giờ chỉ còn dây của anh." % names
	EventBus.notify.emit(line, Color(0.75, 0.95, 1.0))

## Watch the run to a standstill, then judge it. The goal must be DOWN and its
## chain flag set: down without the flag means something else knocked it, which
## is exactly the case a naive "is the goal lying down" test would get wrong.
func _update_run(delta: float) -> void:
	_run_t += delta
	var settled := true
	for d in dominoes:
		if is_instance_valid(d) and not d.is_resolved():
			settled = false
			break
	_run_rest_t = _run_rest_t + delta if settled else 0.0
	if _run_t < RUN_MIN:
		return
	if _run_rest_t < SETTLE_REST_HOLD and _run_t < RUN_TIMEOUT:
		return
	if goal.chain and not goal.is_upright():
		phase = Phase.BUILD
		# The winning run is finished with; stop simulating it. With can_sleep off
		# nothing else ever would, and a won board left 27 live bodies grinding
		# away behind the victory overlay.
		for d in dominoes:
			d.hold()
		_show_feedback("ĐỔ ĐÍCH RỒI!", Color(0.7, 1, 0.7), Vector3(goal_pos.x, 0, goal_pos.z))
		_emit_progress(true)
		EventBus.task_completed.emit()
		return
	# it failed. Say why, in the words that tell the player what to fix.
	var dead := _dead_end()
	if not goal.is_standing():
		_begin_restand("ĐÍCH đổ nhưng không phải do dây - không tính!", Color(1, 0.6, 0.45), dead)
	else:
		_begin_restand("Dây chết giữa đường - vá chỗ hở rồi đẩy lại.", Color(1, 0.8, 0.45), dead)

## The furthest the chain actually got: the piece it reached last. The gap is
## right in front of that piece, so it is the one worth pointing at.
func _dead_end() -> Vector3:
	var best := Vector3(start_pos.x, 0, start_pos.z)
	var best_d := -1.0
	for d in dominoes:
		if d.is_goal or not d.chain:
			continue
		var dist := _xz_dist(d.position, start_pos)
		if dist > best_d:
			best_d = dist
			best = Vector3(d.position.x, 0, d.position.z)
	return best

# --------------------------------------------------------------- standing back up

func _begin_restand(msg: String, col: Color, point_at: Vector3) -> void:
	phase = Phase.RESTAND
	goal.armed = false       # back to being untouchable while you patch the run
	_cancel_carry("")
	EventBus.notify.emit(msg, col)
	if point_at != Vector3.ZERO:
		_show_feedback("chết ở đây", Color(1, 0.55, 0.45), point_at)
	Sfx.play("miss", -8.0)
	# Freeze EVERYTHING first. The rebuild puts pieces back one at a time, so
	# without this a piece already stood up is still surrounded by dynamic
	# wreckage leaning on it - it gets woken straight back over, and the board
	# ends the rebuild with pieces down and unfrozen.
	for d in dominoes:
		d.hold()
	# rewind from the peg outward, so the eye follows the run back into place
	var order := dominoes.duplicate()
	order.sort_custom(func(a: DominoBody, b: DominoBody) -> bool:
		return _xz_dist(a.placed_xform.origin, start_pos) < _xz_dist(b.placed_xform.origin, start_pos))
	var tw := create_tween()
	tw.tween_interval(SHOW_GAP)
	for d in order:
		tw.tween_callback(func() -> void:
			if is_instance_valid(d) and d.has_place:
				d.restand()
				Sfx.play("place", -18.0)).set_delay(RESTAND_STEP)
	tw.tween_callback(func() -> void:
		phase = Phase.BUILD
		_disturbed.clear()
		_collapse_active = false
		_settling = null
		EventBus.notify.emit("Xếp lại xong - đẩy tiếp đi!", Color(0.75, 0.95, 1.0))
		_emit_progress())

# --------------------------------------------------------------- environment hooks

func set_shaking(on: bool) -> void:
	shaking = on and accepts_events()
	if not on:
		for d in dominoes:
			d.set_jitter(Vector3.ZERO)

func set_shield(on: bool) -> void:
	shield_active = on
	_hands.visible = on
	if on and dragging:
		_cancel_carry("Buông quân ra để che")

func _cancel_carry(reason: String) -> void:
	if not dragging and _carried == null:
		return
	dragging = false
	drag_ended.emit()
	if _carried:
		if reason != "":
			_show_feedback(reason, Color(1, 0.85, 0.5), carried_base())
		_carried.queue_free()
		_carried = null

## Gust from the window (back of the desk, -z): everything standing on the
## window half is shoved toward the player. The shield absorbs it.
func gust() -> void:
	if shield_active or not accepts_events():
		return
	for d in dominoes:
		if not d.is_standing():
			continue
		if d.position.z < 0.3:
			d.wake()
			d.apply_impulse(Vector3(randf_range(-0.2, 0.2), 0.0, 3.0), Vector3(0, 0.45, 0))

## The carried piece is no ghost: whatever it sweeps through gets hit, and the
## hand speed decides between a wobble and a wipe-out. Only frozen, standing
## pieces are candidates - the hit unfreezes them, which takes them out of the
## running until they settle again, so nothing is hit twice in one fall.
func _sweep_carried(hand_vel: Vector3) -> void:
	var flat := Vector3(hand_vel.x, 0.0, hand_vel.z)
	var speed := flat.length()
	var base := carried_base()
	for d in dominoes:
		if d.carried or not d.freeze or not d.is_standing():
			continue
		if _xz_dist(d.position, base) > carry_hit_radius:
			continue
		var dir := flat
		if speed <= 0.05:
			dir = Vector3(d.position.x - base.x, 0.0, d.position.z - base.z)
		if dir.length() < 0.05:
			dir = travel_dir(drag_angle)
		d.wake()
		d.apply_impulse(
			dir.normalized() * clampf(speed * carry_hit_force, 0.2, 3.0) + Vector3(0, 0.15, 0),
			Vector3(0, 0.45, 0))
		Sfx.play("thud", -9.0)
		_show_feedback(
			"Quơ tay vào quân ĐÍCH!" if d.is_goal else "Quơ tay vào quân đã xếp!",
			Color(1, 0.5, 0.4), d.position)

## Something lands at a global point: flatten whatever is nearby.
## `force` is how hard it hits. The cat lands with its whole weight and deserves
## the default; the robot only rolls into things, and at 4.0 it flung pieces
## across the desk like a bowling ball. A domino needs almost nothing to go over,
## so a gentler shove still topples the run - it just does not scatter it.
func smash_at(global_pos: Vector3, radius: float, force := 4.0) -> void:
	if not accepts_events():
		return          # the cat may land on the desk mid-run; it may not decide it
	var local := to_local(global_pos)
	for d in dominoes:
		var dist := _xz_dist(d.position, local)
		if dist <= radius:
			var away := Vector3(d.position.x - local.x, 0, d.position.z - local.z)
			if away.length() < 0.1:
				away = Vector3(1, 0, 0)
			d.wake()
			d.apply_impulse(
				away.normalized() * force * (1.0 - dist / (radius + 0.5)) + Vector3(0, 0.3, 0),
				Vector3(0, 0.4, 0))

func _on_disturbed(d: DominoBody) -> void:
	if d.carried:
		return
	# During a run the whole board is MEANT to be falling, and while pieces are
	# standing back up they are not being disturbed either. Collapse bookkeeping
	# belongs to the BUILD phase alone - otherwise a won run would be reported to
	# FailureSystem as a catastrophe and end the game on the player's success.
	if phase != Phase.BUILD:
		return
	if not _collapse_active:
		# a freshly released piece settling by itself is not a collapse
		if d == _settling:
			return
		_collapse_active = true
		_collapse_started = _time
		_collapse_rest_t = 0.0
		_disturbed.clear()
		_collapse_standing_before = standing_count()
		Sfx.play("fall", -6.0)
	if not _disturbed.has(d):
		_disturbed.append(d)
	_last_disturb = _time

# --------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	_time += delta
	_pulse += delta * 4.0
	if _feedback_t > 0.0:
		_feedback_t -= delta
		_feedback.position.y += delta * 0.4
		_feedback.modulate.a = clamp(_feedback_t * 1.5, 0.0, 1.0)
		if _feedback_t <= 0.0:
			_feedback.visible = false

	if shaking:
		for d in dominoes:
			if d.is_standing():
				d.set_jitter(Vector3(randf_range(-0.012, 0.012), 0, randf_range(-0.012, 0.012)))

	if dragging:
		# Safety net: the button can be released over a HUD panel or outside the
		# canvas, and that event never reaches us - the piece would then hang in
		# the air following the cursor forever.
		if not debug_lock_hand and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_drop()
		elif not can_work() or phase != Phase.BUILD:
			_cancel_carry("")
		else:
			if not debug_lock_hand:
				drag_pos = _hand_from_cursor()
			_anchor = _anchor_for(Vector3(drag_pos.x, 0, drag_pos.z))
			drag_angle = _aim_from_anchor()
			var hand_vel: Vector3 = (drag_pos - _drag_prev) / maxf(delta, 0.0001)
			_drag_prev = drag_pos
			_sweep_carried(hand_vel)
			var t := travel_dir(drag_angle)
			# The pendulum answers to CHANGES in hand motion, not to raw speed:
			# driving it with speed pinned it against max_swing for as long as the
			# hand kept moving, and without a delta it was applied 60 times a
			# second. Delta-v is frame-rate independent - starting, stopping and
			# turning kick it, a constant glide leaves it swinging freely.
			swing_vel -= (hand_vel - _hand_vel).dot(t) * swing_from_hand
			_hand_vel = hand_vel
			if shaking:
				swing_vel += randf_range(-0.4, 0.4)
			swing_vel += (-swing_stiffness * swing - swing_damping * swing_vel) * delta
			swing += swing_vel * delta
			swing = clamp(swing, -max_swing, max_swing)
			if _carried:
				_place_carried_transform()
	_fingers.visible = dragging
	if dragging:
		_fingers.position = drag_pos
		_fingers.rotation.y = -drag_angle

	if phase == Phase.RUN:
		_update_run(delta)
	else:
		_update_settle(delta)
		_update_collapse(delta)
	_update_ring()
	_update_cursor()

## The piece just released is still falling or rocking. Landing upright is the
## normal, successful outcome, so it stays out of the collapse bookkeeping until
## it comes to rest. If it knocks neighbours over instead, the collapse system
## claims it and takes over from here.
func _update_settle(delta: float) -> void:
	if _settling == null:
		return
	if not is_instance_valid(_settling):
		_settling = null
		return
	if _disturbed.has(_settling):
		_settling = null
		return
	_settle_t += delta
	_settle_rest_t = _settle_rest_t + delta if _settling.is_at_rest() else 0.0
	if _settle_rest_t < SETTLE_REST_HOLD and _settle_t < SETTLE_TIMEOUT:
		return
	var d := _settling
	_settling = null
	_settle_rest_t = 0.0
	if d.is_upright():
		d.stand_flat()           # landed on its feet: straighten it and lock it
		Sfx.play("place")
		var gap := _xz_dist(d.position, _nearest_neighbour(d))
		if gap > reach:
			_show_feedback("Xa quá - dây sẽ chết ở đây", Color(1, 0.7, 0.4), d.position)
		else:
			_show_feedback("Ổn", Color(0.7, 1, 0.7), d.position)
	else:
		Sfx.play("miss", -6.0)
		# leaning or lying: it is not a placement, hand it to the collapse flow
		_on_disturbed(d)
	_emit_progress()

## Nearest thing the piece just placed could pass a fall to - another standing
## piece, or the peg. Beyond `reach` the chain will not carry across, and the
## player deserves to hear that the moment it lands, not after a failed run.
func _nearest_neighbour(self_d: DominoBody) -> Vector3:
	var best := Vector3(start_pos.x, 0, start_pos.z)
	var best_d := _xz_dist(self_d.position, best)
	for d in dominoes:
		if d == self_d or d.carried or not d.is_standing():
			continue
		var dist := _xz_dist(d.position, self_d.position)
		if dist < best_d:
			best_d = dist
			best = Vector3(d.position.x, 0, d.position.z)
	return best

func _update_collapse(delta: float) -> void:
	if not _collapse_active:
		return
	var settled := _time > _last_disturb + 0.5
	for d in _disturbed:
		if is_instance_valid(d) and not d.is_at_rest():
			settled = false
			break
	# rest has to hold here too, for the same turn-of-the-rock reason
	_collapse_rest_t = _collapse_rest_t + delta if settled else 0.0
	# safety net: if something keeps twitching, call it after a while anyway
	if _collapse_rest_t < SETTLE_REST_HOLD and _time < _collapse_started + 6.0:
		return
	_collapse_active = false
	_collapse_rest_t = 0.0
	var knocked := 0
	var goal_down := false
	for d in _disturbed:
		if not is_instance_valid(d):
			continue
		if d.is_upright():
			d.stand_flat()           # survived: straighten it and lock it again
		else:
			d.hold()             # nothing else re-freezes it, and can_sleep is off
			knocked += 1
			if d.is_goal:
				goal_down = true
				d.restand()      # the map puts itself back; only your work is swept
			else:
				_sweep_away(d)
	_disturbed.clear()
	if goal_down:
		# The case Anh Khai spotted: the goal is down, but nothing that counts
		# pushed it. Say so plainly, so it never looks like a win that was missed.
		EventBus.notify.emit("Quân ĐÍCH bị làm đổ - không tính là thắng. Đã dựng lại.", Color(1, 0.55, 0.45))
	elif knocked > 0:
		EventBus.notify.emit("Đổ %d quân - đã dọn đi, xếp lại chỗ đó nhé." % knocked, Color(1.0, 0.8, 0.45))
	EventBus.collapse_finished.emit(knocked, _collapse_standing_before)
	_emit_progress()

## Sweep a fallen piece off the desk: fade it out, then it is gone for good.
##
## The fade matters more than it looks. A piece that simply vanished the instant
## it settled would read as a bug; watching it go is what tells you the desk was
## tidied rather than that your work was eaten. It is dropped from `dominoes`
## straight away so nothing aims at it while it is still fading.
func _sweep_away(d: DominoBody) -> void:
	dominoes.erase(d)
	if d == _settling:
		_settling = null
	var tw := create_tween()
	tw.tween_method(d.set_alpha, 1.0, 0.0, SWEEP_TIME)
	tw.tween_callback(d.queue_free)

func _update_ring() -> void:
	# reach ring: around the anchor while carrying, around the working end while not
	var show_ring := can_work() and phase == Phase.BUILD
	_ring.visible = show_ring
	if show_ring:
		var at := _anchor if dragging else _ring_home()
		_ring.position = Vector3(at.x, 0.01, at.z)
		var glow := 0.55 + 0.3 * sin(_pulse)
		var col := Color(1.0, 0.9, 0.55, glow)
		if shield_active:
			col = Color(0.7, 0.7, 0.7, 0.4)
		elif dragging:
			var gap := _xz_dist(carried_base(), _anchor)
			# green only when it is both in reach AND steady enough to land flat
			if gap <= reach and absf(swing) <= straight_swing:
				col = Color(0.6, 1.0, 0.6, 0.95)
			elif gap > reach:
				col = Color(1.0, 0.45, 0.4, 0.9)
		_ring_mat.albedo_color = col
	_goal_mat.albedo_color = Color(0.6, 1.0, 0.6) if phase == Phase.RUN else Color(1.0, 0.85, 0.45)
	_goal_label.text = "ĐÍCH" if goal.armed else "ĐÍCH  (đang khoá)"
	var ready := phase == Phase.BUILD and _starter() != null
	_peg_label.text = "▸ ĐẨY DÂY  (Enter)" if ready else "BẮT ĐẦU"
	# A sign that pulses is a sign you notice. The static one was there all along
	# and got missed, which is the only evidence that matters about it.
	_peg_label.modulate = Color(0.7, 1.0, 0.75) if not ready 		else Color(1.0, 1.0, 0.6).lerp(Color(0.4, 1.0, 0.5), 0.5 + 0.5 * sin(_time * 6.0))
	_peg_label.font_size = 34 if ready else 26
	if ready and not _told_ready:
		var head := chain_head()
		if _reaches_goal(head):
			_told_ready = true
			EventBus.notify.emit("Dây đã tới ĐÍCH - bấm ENTER (hoặc bấm vạch BẮT ĐẦU) để đẩy!", Color(0.7, 1, 0.75))
	_base_ring.visible = dragging
	if dragging:
		var b := carried_base()
		_base_ring.position = Vector3(b.x, 0.012, b.z)
		var a := absf(swing)
		_base_mat.albedo_color = Color(0.6, 1, 0.6) if a <= straight_swing \
			else (Color(1, 0.8, 0.4) if a <= topple_swing else Color(1, 0.4, 0.35))

func _ring_home() -> Vector3:
	var head := chain_head()
	if head:
		return Vector3(head.position.x, 0, head.position.z)
	return Vector3(start_pos.x, 0, start_pos.z)

func _update_cursor() -> void:
	var hot := false
	if can_work() and not dragging and phase == Phase.BUILD:
		var tl := to_local(_mouse_on_plane(0.0))
		hot = _xz_dist(tl, tray_pos) <= 1.0 \
			or _xz_dist(tl, start_pos) <= PEG_RADIUS \
			or (absf(tl.x) <= area_half.x and absf(tl.z) <= area_half.y and _placement_problem(tl) == "")
	if hot != _hover_hot:
		_hover_hot = hot
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hot else Input.CURSOR_ARROW)

# --------------------------------------------------------------- helpers

static func _xz_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _show_feedback(text: String, col: Color, at: Vector3) -> void:
	_feedback.text = text
	_feedback.modulate = col
	_feedback.position = at + Vector3(0, 1.5, 0)
	_feedback.visible = true
	_feedback_t = 1.4

## Debug/bot helper: lay the next piece toward the goal, stepping around
## anything in the way. Used by the headless probes, not by the game.
## True when the cursor is over one of the room's own clickable objects.
##
## The cat sits at x 5.6, z 3.0 - inside the play area - so a click on it also
## reads as a click on a spot to place a domino, and whichever handler ran first
## won. That is why the cat could not always be petted. The task yields: a
## domino can go almost anywhere, the cat is only in one place.
func _cursor_over_interactable() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var m := get_viewport().get_mouse_position()
	var q := PhysicsRayQueryParameters3D.create(
		cam.project_ray_origin(m), cam.project_ray_origin(m) + cam.project_ray_normal(m) * 60.0)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.has("collider") and hit["collider"] is InteractableObject3D

# ---------------------------------------------------------------- the router
#
# One router, two users: F2 ("lay me a finished run") and the probe bot. It has
# to produce a route the chain can GENUINELY carry, so it is built out of the two
# things that were killing the routes it laid before.
#
# 1. A DEAD END. The old router was greedy - aim at the goal, take the first
#    legal spot, repeat - so it walked itself into pockets it could not leave and
#    reported the desk as blocked when it was only its own nose that was. The
#    corridor is now planned FIRST, by breadth-first search over a grid of the
#    desk, which finds a way through whenever one exists at all.
#
# 2. A CORNER TOO SHARP TO CARRY. A piece is 0.48 wide, so a fall lands on the
#    next piece only while the turn stays under asin(0.24 / step) - 29 deg at
#    this step. The old router offered 38 deg, and a route with one of those in
#    it lays perfectly and then dies at the bend. Laying is now a PURSUIT: each
#    piece turns at most BOT_MAX_TURN toward the corridor, so a corner comes out
#    as an arc of several pieces instead of one impossible kink.

## Distance between two pieces the plan lays. Comfortably inside `reach`.
const BOT_STEP := 0.49
## Headings the plan may use. 24 of them means the sharpest turn between two
## consecutive pieces is 360/24 = 15 deg, and at this step that puts the next
## piece only 0.49 * sin(15) = 0.13 sideways of where the last one falls - half
## the 0.24 half-width it has to land within. A comfortable margin at every bend,
## by construction rather than by luck.
const BOT_HEADINGS := 24
## How far off the straight line into the goal the last piece may point. Looser
## than one turn step, so a final approach slightly off-axis still counts.
const BOT_MAX_TURN := 0.35
## Clearance the plan keeps from an obstacle. Slightly MORE than
## _placement_problem demands, so every spot the plan picks is a legal one.
const BOT_CLEAR := 0.26
## Cell the search collapses positions into: half a step, so two pieces of one
## route can never land in the same cell.
const BOT_CELL := 0.24

## The plan: a piece per entry, position and the bearing it faces.
var _plan: Array[Vector3] = []
var _plan_ang: Array[float] = []
var _plan_i := 0
## The last piece the router itself laid.
##
## It cannot use chain_head() for this. chain_head() means "the standing piece
## closest to the goal", which is the right answer for the player - but a detour
## around an obstacle moves AWAY from the goal for several pieces, and there
## chain_head() points back at where the detour began. The router would lay from
## the wrong end over and over, going nowhere.
var _route_tip: DominoBody = null
## Free/blocked answers for this plan, keyed by cell. The search asks the same
## few hundred cells thousands of times over.
var _free_cache := {}

## The end the router lays from: its own last piece while that still stands,
## otherwise the working end of whatever the player has built.
func _router_tip() -> DominoBody:
	if _route_tip != null and is_instance_valid(_route_tip) and _route_tip.is_standing():
		return _route_tip
	return chain_head()

## Can a piece stand here? Desk, obstacles, and anything already standing. The
## goal is not an obstacle - arriving at it is the entire point.
func _route_free(p: Vector3) -> bool:
	if absf(p.x) > area_half.x or absf(p.z) > area_half.y:
		return false
	if _xz_dist(p, start_pos) < PEG_RADIUS:
		return false
	for o in obstacles:
		var op: Vector3 = o["pos"]
		var sz: Vector3 = o["size"]
		if absf(p.x - op.x) < sz.x * 0.5 + BOT_CLEAR and absf(p.z - op.z) < sz.z * 0.5 + BOT_CLEAR:
			return false
	for d in dominoes:
		if d.is_goal or d.carried:
			continue          # arriving at the goal is the entire point
		var dist := _xz_dist(d.position, p)
		if not d.is_standing():
			# A piece lying on the desk is a HOLE, not empty space, and it has to
			# be one here as well: _placement_problem refuses anything within 0.6
			# of one, so a plan that ignored them would keep proposing spots the
			# placement rule then rejected, and the router would deadlock five
			# pieces short with no way to explain itself. This is the one place
			# the two rules have to agree.
			if dist < 0.65:
				return false
		elif dist < 0.3:
			return false
	return true

func _cell_free(p: Vector3) -> bool:
	var k := Vector2i(roundi(p.x / BOT_CELL), roundi(p.z / BOT_CELL))
	if not _free_cache.has(k):
		_free_cache[k] = _route_free(p)
	return _free_cache[k]

func _bucket(a: float) -> int:
	return wrapi(roundi(a / TAU * BOT_HEADINGS), 0, BOT_HEADINGS)

func _bucket_angle(h: int) -> float:
	return float(h) / float(BOT_HEADINGS) * TAU

## Would a piece here, facing this way, fall ONTO the goal? Near enough, far
## enough not to be standing on top of it, and pointed at it. Distance alone was
## the old test, and it happily stopped with a piece that would topple PAST the
## goal instead of into it.
func _hits_goal(pos: Vector3, angle: float) -> bool:
	var to_goal := Vector3(goal_pos.x - pos.x, 0.0, goal_pos.z - pos.z)
	var dist := to_goal.length()
	if dist > reach * 0.92 or dist < 0.3:
		return false
	return absf(angle_difference(angle, atan2(to_goal.z, to_goal.x))) <= BOT_MAX_TURN

func _reaches_goal(d: DominoBody) -> bool:
	if d == null or not is_instance_valid(d):
		return false
	return _hits_goal(Vector3(d.position.x, 0, d.position.z), facing_of(d))

## The bearing a piece will fall along. standing_xform builds the basis so that
## -z is the direction of travel.
static func facing_of(d: DominoBody) -> float:
	var f := -d.transform.basis.z
	return atan2(f.z, f.x)

## Plan the whole run: every piece, in order, from `tip` (or the peg) to the goal.
##
## The search runs over (where a piece stands, which way it faces) and its only
## move is "the next piece, one step on, turned at most one heading bucket". So a
## plan is not a corridor that still has to be followed - it IS the run, and
## every hop in it is one the chain can carry. That is the difference between a
## cheat that hands you the answer and one that hands you a second puzzle.
##
## The old router planned a corridor and then chased it, which sounds equivalent
## and is not: chasing has a minimum turning radius, so it drifted wide in tight
## gaps, walked into its own pieces, and reported the desk as blocked while
## sitting five metres short of the goal.
func _plan_route(tip: DominoBody = null) -> bool:
	_plan.clear()
	_plan_ang.clear()
	_plan_i = 0
	_free_cache.clear()
	var nodes: Array[Dictionary] = []
	var seen := {}
	if tip != null:
		nodes.append({
			"pos": Vector3(tip.position.x, 0, tip.position.z),
			"h": _bucket(facing_of(tip)), "prev": -1})
	else:
		# From the peg the first piece may set off in any direction, and it faces
		# the way the peg's shove will send it - so seed one state per heading.
		for h in BOT_HEADINGS:
			var p := Vector3(start_pos.x, 0, start_pos.z) + travel_dir(_bucket_angle(h)) * BOT_STEP
			if _cell_free(p):
				nodes.append({"pos": p, "h": h, "prev": -1})
	for n in nodes:
		seen[Vector3i(roundi(n["pos"].x / BOT_CELL), roundi(n["pos"].z / BOT_CELL), n["h"])] = true
	var at := 0
	var found := -1
	# breadth-first, so the plan that comes back uses the fewest pieces
	while at < nodes.size():
		var pos: Vector3 = nodes[at]["pos"]
		var h: int = nodes[at]["h"]
		if _hits_goal(pos, _bucket_angle(h)):
			found = at
			break
		for dh in [0, 1, -1]:
			var h2: int = wrapi(h + dh, 0, BOT_HEADINGS)
			var p2: Vector3 = pos + travel_dir(_bucket_angle(h2)) * BOT_STEP
			var key := Vector3i(roundi(p2.x / BOT_CELL), roundi(p2.z / BOT_CELL), h2)
			if seen.has(key) or not _cell_free(p2):
				continue
			seen[key] = true
			nodes.append({"pos": p2, "h": h2, "prev": at})
		at += 1
	if found < 0:
		return false
	var order: Array[int] = []
	var i := found
	while i >= 0:
		order.append(i)
		i = nodes[i]["prev"]
	order.reverse()
	if tip != null:
		order.remove_at(0)      # the tip is already on the desk
	for k in order:
		_plan.append(nodes[k]["pos"])
		_plan_ang.append(_bucket_angle(nodes[k]["h"]))
	return not _plan.is_empty()

## Lay ONE piece of the plan. The bot calls this once a frame so its run can be
## watched being built; debug_fill_route calls it in a loop.
func debug_place_next() -> bool:
	if phase != Phase.BUILD or not can_work():
		return false
	if _plan_i >= _plan.size() and not _plan_route(_router_tip()):
		return false
	if _placement_problem(_plan[_plan_i]) != "":
		# Something is standing where the plan wanted to go. Re-plan around it
		# from the working end: skipping the spot would leave a hole, and a hole
		# is the one thing a run cannot survive.
		if not _plan_route(_router_tip()) or _placement_problem(_plan[0]) != "":
			return false
	var base: Vector3 = _plan[_plan_i]
	var angle: float = _plan_ang[_plan_i]
	_plan_i += 1
	var d := DominoBody.new()
	d.setup(palette_at(dominoes.size()))
	d.disturbed.connect(_on_disturbed)
	add_child(d)
	d.global_transform = global_transform * standing_xform(base, angle)
	d.stand_flat()
	dominoes.append(d)
	_route_tip = d
	_emit_progress()
	return true

## Cheat (F2): lay a FINISHED run, from wherever your own work ends all the way
## to the goal.
##
## Anh Khai's test of this is the right one - "F2 co phai la loi giai khong?" If
## pressing it can leave you stuck, or leave a run that will not carry, then it
## is not a cheat, it is a second puzzle.
func debug_fill_route() -> void:
	if phase != Phase.BUILD or not can_work():
		EventBus.notify.emit("Chưa xếp được lúc này.", Color(1, 0.85, 0.5))
		return
	if dragging:
		_cancel_carry("")
	_route_tip = null
	_plan.clear()
	_plan_i = 0
	if _reaches_goal(_router_tip()):
		EventBus.notify.emit("Dây đã tới ĐÍCH rồi - bấm ENTER để đẩy!",
			Color(0.7, 1, 0.75))
		return
	if not _plan_route(_router_tip()):
		EventBus.notify.emit("Bàn này không có đường nào tới ĐÍCH.",
			Color(1, 0.6, 0.45))
		return
	var laid := 0
	while laid < 400 and not _reaches_goal(_router_tip()):
		if not debug_place_next():
			break
		laid += 1
	if not _reaches_goal(_router_tip()):
		EventBus.notify.emit("Chỉ xếp được %d quân - đường bị chặn." % laid,
			Color(1, 0.7, 0.45))
	else:
		EventBus.notify.emit("CHEAT: xếp sẵn %d quân tới ĐÍCH - bấm ENTER để đẩy!" % laid,
			Color(0.8, 0.9, 1.0))
	_emit_progress()

## Debug/bot helper: start the run without a click.
func debug_trigger() -> void:
	_trigger_run()

## Which way the goal flag points: towards the middle of the desk. The autotest's
## frame check probes the same expression, so the flag it measures is the flag
## that gets drawn.
func flag_side() -> float:
	return -1.0 if goal_pos.x > 0.0 else 1.0
