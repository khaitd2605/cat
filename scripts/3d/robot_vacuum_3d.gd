class_name RobotVacuum3D
extends InteractableObject3D
## The robot vacuum: the desk's weather.
##
## The cat and the gust are EVENTS - they announce themselves, you react, they
## end. This thing is different in kind. It is always there, it is always
## moving, and its road is something you can read several seconds ahead. That
## turns "which way do I lay?" into a question about time as well as space: the
## short line straight across is quick to build and sits right in its path; the
## long way round behind it costs pieces but survives.
##
## TWO BUTTONS, AND THEY ARE MEANT TO BE USED TOGETHER.
##
## Clicking the robot turns it a quarter turn - cheap, instant, and it buys you
## only a few seconds. Clicking the DOCK sends it home, but home is a straight
## line and it flattens whatever of yours is standing on that line. So the dock
## is not an off switch: it is a shot you have to line up. You steer with the
## turn button until the road home is clear of your run, and only then do you
## call it in. That is Anh Khai's design, and it is better than the one I
## proposed, because it makes the two buttons into one mechanic instead of two.
##
## THE BATTERY IS A CLOCK YOU CAN READ. It has to charge before it will set off,
## and when it runs flat it takes itself home - along a line you did not choose,
## unless you were watching the light on its lid. Green, amber, red. That is the
## whole warning system; there is no banner and there is not going to be one.
##
## It obeys the two-phase rule like everything else in the room. `accepts_events`
## goes false the moment you push, and the robot stops dead where it stands: no
## movement, no sweeping, no drain. The push is judged by how you laid it, never
## by where the robot happened to be standing.
##
## IT CLIMBS THE FLAT THINGS AND BUMPS THE TALL ONES. A desk vacuum drives over
## a paperback; it stops dead at a mug. The threshold is its own height, which
## is the one number that needs no explaining: it goes over what it is taller
## than. Halving the robot moved that line - the tape roll and the mouse used to
## be speed bumps and are now walls - and it is worth the loss, because a 4 cm
## machine hopping a stapler looked like a bug in the physics. It can afford the
## extra walls now: the exclusion pad shrank with the body, so the desk has far
## more free floor than it did at the old size.
##
## AND IT CAN NEVER BE WEDGED. Solid things only turn it when it is driving from
## clear floor INTO them; if it somehow finds itself already inside one it keeps
## going until it is out. Only the desk edge is absolute. The first version had
## the hard rule both ways and the free-roam probe caught it inside a second:
## parked on its dock in the shadow of a book, every direction refused, sitting
## there cycling dock-charge-set-off-stop for the whole level.
##
## NO COLLIDER, ON PURPOSE. The Area3D here is for the mouse, not for physics -
## a moving solid body on the desk would make a route impossible to plan, since
## a chain you laid correctly could die on something that wandered into it after
## you had already committed. The robot's only power over your pieces is to
## knock them down while you are still building, where you can see it coming and
## do something about it.

enum State {
	CHARGING,   ## sat on the dock, filling up. Harmless.
	ROAMING,    ## out on the desk, driving, flattening what it touches
	RETURNING,  ## going home in a straight line - the dangerous one
}

## Body radius. Half of what it started at, on Anh Khai's eye: 0.5 units is
## about 4.5 cm across the shell, one of those palm-sized keyboard-crumb vacuums
## rather than a floor robot. A real floor robot is 35 cm and would cover a third
## of this desk; at the first size it read as a saucepan lid parked next to the
## mug. Small also buys the mechanic something real - a little machine slips
## between the clutter instead of being walled in by it.
@export var radius := 0.5
## Height of the shell above the desk. Kept in proportion with the radius.
@export var body_h := 0.42
## Units per second on patrol. Slow enough to be dodged, fast enough that
## ignoring it for ten seconds is a mistake.
@export var speed := 0.6
## Coming home it is in a hurry. Also stops a flat battery from taking forever.
@export var return_speed := 0.85
## Seconds from empty to full on the dock. The quiet window: this is how long
## you get to build without it.
@export var charge_time := 20.0
## Seconds of patrolling a full charge buys. Longer than the charge by a lot,
## because being out is the normal state and docked is the exception.
@export var roam_time := 26.0
## How wide it knocks pieces over. A shade more than the body, so contact
## happens when it LOOKS like contact - and no more, because at this size a
## generous radius would have it flattening pieces it visibly drove past.
@export var hit_radius := 0.62
## How hard. Far below the cat's landing (4.0): the robot rolls into a piece, it
## does not pounce on it. A domino goes over at the lightest touch, so this is
## still fatal to a run - it just topples it instead of scattering it.
@export var hit_force := 1.6
## One click of the turn button. A quarter turn: coarse on purpose, because the
## button is for shoving it off your run, not for aiming it.
@export var turn_step := PI * 0.5
## Where it may drive. Reaches the whole build diagonal and the strip at the
## back where the dock sits, while staying clear of the room's own furniture
## along the edges of the desk - the lamp foot, the big mug, the notebook, the
## crate of pens. Slightly tighter in x than the play area (6.2) for that
## reason, which costs nothing: the peg and the goal are both inside it.
@export var roam_half := Vector2(5.6, 3.7)
@export var task_path: NodePath
@export var dock_path: NodePath

## Battery below this and the lid light goes amber; half of it and it goes red.
const WARN_LEVEL := 0.45
## Stuck for this long and it gives up and goes home. Nothing should be able to
## trap it, but "nothing should" is not the same as "nothing can", and a robot
## wedged against a mug for the rest of the level is a dead mechanic.
const STUCK_LIMIT := 1.5

var state: State = State.CHARGING
var battery := 0.0
## Bearing it is driving along: the direction is (cos, 0, sin), matching the
## convention `facing_of` reads off a domino.
var heading := 0.0
var enabled := true

var _task: DominoTask3D
var _dock: VacuumDock3D
var _dock_pos := Vector3.ZERO
## Middle of the desk in world space, for pointing it somewhere useful.
var _centre := Vector3.ZERO
var _lid_mat: StandardMaterial3D
var _brush: Node3D
var _stuck := 0.0
var _hum := 0.0
var _flash := ""
var _flash_t := 0.0
## Has it explained itself yet? The room teaches the cat through the warning
## system; the robot has no warning to hang a lesson on, so it gets one line the
## first time it matters and never mentions it again.
var _taught := false

func _ready() -> void:
	# Deliberately larger than the shell. Turning it is half the mechanic, and a
	# 4 cm disc on a 67 cm desk is a fiddly thing to hit at this camera distance;
	# nothing else competes for that patch of desk, so the slack costs nothing.
	hit_size = Vector3(radius * 3.0, body_h * 2.4, radius * 3.0)
	hit_offset = Vector3(0, body_h * 0.9, 0)
	super._ready()
	hover_label = "Xoay robot"
	_task = get_node_or_null(task_path) as DominoTask3D
	_dock = get_node_or_null(dock_path) as VacuumDock3D
	if _task:
		_centre = _task.to_global(Vector3.ZERO)
	if _dock:
		_dock_pos = _dock.global_position
		_dock.interacted.connect(_on_dock_clicked)
	else:
		_dock_pos = global_position
	global_position = _dock_pos
	interacted.connect(_on_clicked)
	_build()
	_paint_lid()
	# Off the desk entirely until the level that teaches it. Hidden and
	# un-clickable, not merely parked: a machine sitting there doing nothing is a
	# question the player cannot answer yet.
	var lv := GameManager.level_def()
	if not lv["robot"]:
		enabled = false
		visible = false
		input_ray_pickable = false
		return
	# The generated levels get their difficulty from timing, and this is the
	# robot's share of it: the same machine, quicker. Speed alone would only make
	# it cross the desk sooner, so the charge shortens with it - what actually hurts
	# is how OFTEN it comes out, and a robot that recharges in half the time is out
	# on the desk twice as much. Defaulted, so the six authored desks say nothing
	# about it and get exactly the robot Anh Khai tuned by hand.
	var mult: float = lv.get("robot_speed", 1.0)
	if not is_equal_approx(mult, 1.0):
		speed *= mult
		return_speed *= mult
		charge_time /= mult

# --------------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
	status_text = _status()
	if _dock:
		_dock.status_text = "Robot đang sạc" if state == State.CHARGING else "Bấm để gọi về"
	super._process(delta)
	if _brush and state != State.CHARGING:
		_brush.rotation.y += delta * 9.0
	if not enabled or _task == null:
		return
	# The one gate. Off during the push, off when the game is not being played -
	# the robot stops exactly where it stands and picks up again afterwards.
	if not _task.accepts_events():
		return
	match state:
		State.CHARGING:
			battery = minf(battery + delta / charge_time, 1.0)
			_paint_lid()
			if battery >= 1.0:
				_set_off()
		State.ROAMING:
			battery = maxf(battery - delta / roam_time, 0.0)
			_paint_lid()
			if battery <= 0.0:
				_go_home("flat")
				return
			_drive(delta)
			_sweep()
			_motor(delta)
		State.RETURNING:
			_drive_home(delta)
			_sweep()
			_motor(delta)

# ------------------------------------------------------------------- states

func _set_off() -> void:
	state = State.ROAMING
	# Off the dock and into the room, not along the edge: aim at the middle of
	# the desk with a bit of slop, so it arrives somewhere different every time.
	var to_middle := Vector3(_centre.x - _dock_pos.x, 0, _centre.z - _dock_pos.z)
	if to_middle.length() < 0.1:
		to_middle = Vector3(0, 0, -1)
	heading = atan2(to_middle.z, to_middle.x) + randf_range(-0.7, 0.7)
	_stuck = 0.0
	Sfx.play("motor", -12.0)
	if _taught:
		EventBus.notify.emit("Robot hút bụi sạc đầy - nó ra bàn rồi!", Color(1, 0.82, 0.5))
	else:
		_taught = true
		EventBus.notify.emit(
			"Robot hút bụi ra bàn! Bấm vô nó để nó quay hướng khác, bấm dock để gọi nó về.",
			Color(1, 0.82, 0.5))

## Head for the dock. Three things send it home and the player needs to know
## which: a call is a line you chose, a flat battery is a line the desk chose for
## you, and stuck is the game admitting it got itself into a mess.
func _go_home(reason: String) -> void:
	state = State.RETURNING
	_stuck = 0.0
	Sfx.play("beep", -6.0)
	match reason:
		"flat":
			EventBus.notify.emit("Robot hết pin, tự chạy về dock - nó không tránh gì đâu!",
				Color(1, 0.6, 0.45))
		"stuck":
			EventBus.notify.emit("Robot bị kẹt, nó bò về dock - vẫn cán đường nhé!",
				Color(1, 0.6, 0.45))
		_:
			EventBus.notify.emit("Robot đang chạy thẳng về dock - tránh đường!",
				Color(1, 0.75, 0.5))

func _arrive() -> void:
	state = State.CHARGING
	global_position = _dock_pos
	var out := Vector3(_centre.x - _dock_pos.x, 0, _centre.z - _dock_pos.z)
	if out.length() > 0.1:
		heading = atan2(out.z, out.x)
	_face(heading)
	_paint_lid()
	Sfx.play("resolve", -10.0)
	EventBus.notify.emit("Robot về dock nghỉ - anh có %.0f giây yên tĩnh." % charge_time,
		Color(0.7, 1, 0.75))

# -------------------------------------------------------------------- driving

func _drive(delta: float) -> void:
	var next := global_position + _dir(heading) * speed * delta
	# Off the desk is absolute. Everything else only turns it while it is on
	# clear floor - see the wedging note at the top of the file.
	if _off_desk(next) or (_solid_at(next) and not _solid_at(global_position)):
		_bump()
		_stuck += delta
		if _stuck > STUCK_LIMIT:
			_go_home("stuck")
	else:
		global_position = next
		_stuck = 0.0
		_face(heading)

## Straight home - that is the whole point of the dock button, and the reason it
## is a decision instead of a free escape.
##
## It does sidestep the mug: solid clutter turns it a little and it re-aims at
## the dock next frame, which looks like a robot brushing past furniture and
## keeps the line essentially straight. Your dominoes get no such courtesy.
func _drive_home(delta: float) -> void:
	var to := Vector3(_dock_pos.x - global_position.x, 0, _dock_pos.z - global_position.z)
	var step := return_speed * delta
	if to.length() <= step + 0.05:
		_arrive()
		return
	heading = atan2(to.z, to.x)
	var next := global_position + _dir(heading) * step
	if _solid_at(next):
		for side in [0.5, -0.5, 1.0, -1.0, 1.6, -1.6]:
			var h: float = heading + side
			if not _solid_at(global_position + _dir(h) * step):
				heading = h
				break
	global_position += _dir(heading) * step
	_face(heading)

## Pick a new bearing after a knock. Random, but only ever one that is actually
## free - a reflection off the surface would look tidier and would also send it
## straight back into the corner it just found.
func _bump() -> void:
	Sfx.play("thud", -18.0)
	var inside := _solid_at(global_position)
	for i in 16:
		var h := randf() * TAU
		var probe := global_position + _dir(h) * (radius + 0.3)
		if _off_desk(probe):
			continue
		if inside or not _solid_at(probe):
			heading = h
			return
	heading = wrapf(heading + PI, -PI, PI)

## Would the body centre be off the patrol area? The one hard rule.
func _off_desk(world_p: Vector3) -> bool:
	var p := _task.to_local(world_p)
	return absf(p.x) > roam_half.x or absf(p.z) > roam_half.y

## Is there something solid here - tall clutter, the goal, or the peg? Dominoes
## are deliberately absent: knocking them over is the job, and bouncing off them
## would defeat it.
func _solid_at(world_p: Vector3) -> bool:
	var p := _task.to_local(world_p)
	if _near(p, _task.goal_pos, radius + 0.5) or _near(p, _task.start_pos, radius + 0.4):
		return true
	for o in _task.obstacles:
		var sz: Vector3 = o["size"]
		if sz.y < body_h:
			continue          # shorter than the robot: it drives over the top
		var op: Vector3 = o["pos"]
		# 0.8 of the radius, not all of it: the shell may overlap the mug by a
		# hair, which reads as brushing past it and leaves the desk with enough
		# free floor to patrol.
		var pad := radius * 0.8
		if absf(p.x - op.x) < sz.x * 0.5 + pad and absf(p.z - op.z) < sz.z * 0.5 + pad:
			return true
	return false

## Flatten what it is standing on. `smash_at` is the cat's own routine, so the
## robot inherits the existing rule for free: pieces knocked over mid-build get
## swept off the desk, and the goal - unarmed while you build - does not move
## for it any more than it moves for the cat.
func _sweep() -> void:
	_task.smash_at(global_position, hit_radius, hit_force)

func _motor(delta: float) -> void:
	_hum -= delta
	if _hum <= 0.0:
		_hum = 0.9
		Sfx.play("motor", -19.0)

static func _dir(a: float) -> Vector3:
	return Vector3(cos(a), 0.0, sin(a))

## The shell is modelled facing +x, so the yaw that points it along a bearing is
## simply the negated bearing.
func _face(a: float) -> void:
	rotation.y = -a

static func _near(a: Vector3, b: Vector3, r: float) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() < r

# ---------------------------------------------------------------- the buttons

func _on_clicked() -> void:
	if not enabled:
		return
	match state:
		State.ROAMING:
			heading = wrapf(heading + turn_step, -PI, PI)
			_face(heading)
			_stuck = 0.0
			Sfx.play("beep", -10.0)
			_say("Quay hướng khác!")
		State.RETURNING:
			# No abort. Calling it in is a commitment - if the button could be
			# taken back the moment the line looked bad, the line would cost
			# nothing and the dock would be an off switch after all.
			Sfx.play("miss", -8.0)
			_say("Đang về dock - không dừng được!")
		State.CHARGING:
			Sfx.play("beep", -14.0)
			_say("Đang sạc, chưa chạy đâu.")

func _on_dock_clicked() -> void:
	if not enabled:
		return
	if state == State.ROAMING:
		_go_home("called")
	elif state == State.CHARGING:
		_say("Robot đang ở dock rồi.")

# ------------------------------------------------------------------- readout

## Battery as a colour on the lid. This IS the warning system - the number in
## the hover label is for reading, the light is for noticing out of the corner
## of an eye while you are busy placing a piece.
func _paint_lid() -> void:
	var col := Color(0.35, 0.95, 0.5)
	if battery < WARN_LEVEL * 0.5:
		col = Color(1, 0.32, 0.28)
	elif battery < WARN_LEVEL:
		col = Color(1, 0.75, 0.25)
	if _lid_mat:
		_lid_mat.albedo_color = col
		_lid_mat.emission = col
	if _dock:
		# lit means it is home. Dark means it is out there somewhere.
		_dock.set_led(col if state == State.CHARGING else Color(0.2, 0.24, 0.3))

func _status() -> String:
	if _flash_t > 0.0:
		return _flash
	match state:
		State.CHARGING:
			return "Đang sạc %d%%" % roundi(battery * 100.0)
		State.RETURNING:
			return "Đang về dock"
		_:
			return "Pin %d%%" % roundi(battery * 100.0)

func _say(text: String) -> void:
	_flash = text
	_flash_t = 1.4

# ------------------------------------------------------------------- the shell

## Debug and the autotest bot: park it and switch it off.
func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		state = State.CHARGING
		battery = 0.0
		global_position = _dock_pos
		_paint_lid()

func _build() -> void:
	var shell := Color(0.30, 0.31, 0.35)
	var trim := Color(0.16, 0.17, 0.20)
	# body: a squat disc, with the bumper as a slightly wider band at the bottom
	add_child(_cyl(radius * 0.97, body_h * 0.78, shell, Vector3(0, body_h * 0.39, 0)))
	add_child(_cyl(radius, body_h * 0.22, trim, Vector3(0, body_h * 0.11, 0)))
	# lid: a ring of casing with the battery light in the middle of it
	add_child(_cyl(radius * 0.9, body_h * 0.14, Color(0.38, 0.39, 0.44),
		Vector3(0, body_h * 0.82, 0)))
	var lid := _cyl(radius * 0.34, body_h * 0.1, Color(0.35, 0.95, 0.5),
		Vector3(0, body_h * 0.9, 0))
	_lid_mat = lid.material_override as StandardMaterial3D
	_lid_mat.emission_enabled = true
	# Low on purpose. At 1.4 the tonemapper clipped every colour to the same
	# cream blob, which is a warning light that warns of nothing.
	_lid_mat.emission_energy_multiplier = 0.6
	add_child(lid)
	# which way it is pointing, read at a glance: a darker bumper plate and two
	# little sensor eyes on the leading edge. +x is forward.
	add_child(box(Vector3(0.12, body_h * 0.4, radius * 1.15),
		trim, Vector3(radius * 0.9, body_h * 0.3, 0)))
	for z in [-0.32, 0.32]:
		add_child(sphere(0.09, Color(0.9, 0.35, 0.3),
			Vector3(radius * 0.92, body_h * 0.55, radius * z)))
	# The brush, spinning under the front lip - the bit that makes it read as a
	# machine doing something rather than a puck sliding about. Tucked well under
	# the shell and in a dull bristle colour: at full length in cream it stuck out
	# past the body and read as something spilled on the desk.
	_brush = Node3D.new()
	_brush.position = Vector3(radius * 0.34, 0.045, 0)
	add_child(_brush)
	for i in 4:
		var arm := box(Vector3(radius * 0.42, 0.04, 0.07), Color(0.52, 0.46, 0.34))
		arm.rotation.y = float(i) * PI * 0.5
		arm.position = _dir(float(i) * PI * 0.5) * radius * 0.2
		_brush.add_child(arm)

static func _cyl(r: float, h: float, col: Color, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	m.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	m.material_override = mat
	m.position = pos
	return m
