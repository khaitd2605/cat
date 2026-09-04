class_name DominoBody
extends RigidBody3D
## One physical domino. Placed dominoes are FROZEN (kinematic) so they never
## jitter; a moving domino that touches a frozen one wakes it up, which is how
## the chain reaction travels. The carried domino is frozen too and moved by hand.

signal disturbed(body: DominoBody)

const SIZE := Vector3(0.48, 1.0, 0.16)   # width across the run, height, thickness along it
## Centre of mass, measured up from the domino's own centre. A real domino has
## it dead centre; lifting it makes the whole run topple more readily - by hand,
## by gust, by cat and along the chain - from one number, instead of pumping up
## every impulse separately. It lowers the static tipping angle too:
##   atan(SIZE.z * 0.5 / (SIZE.y * 0.5 + COM_HEIGHT)) = atan(0.08 / 0.68) = 6.7 deg
const COM_HEIGHT := 0.18
## basis.y . UP above this counts as resting flat. Must stay INSIDE the tipping
## angle above (acos(0.994) = 6.3 deg < 6.7 deg), otherwise a domino already
## committed to falling would pass is_upright() and get locked mid-lean.
const UPRIGHT_DOT := 0.994

var carried := false
## While false this piece cannot be woken by ANYTHING - not the cat, not a gust,
## not a careless hand. It is how the goal stays untouchable until the run is
## laid and pushed: the one piece you must not lose to bad luck is simply out of
## reach of bad luck until it is your own chain arriving.
var armed := true
var color := Color.WHITE
## True once this piece was woken by the player's trigger, directly or after
## any number of hops down the line. This is the whole answer to "did the GOAL
## fall because of my chain, or because I brushed it with my hand?" - the flag
## rides along the same contacts the chain does, so nothing else can set it.
var chain := false
## The goal piece: it is knocked over like any other, but only a fall with
## `chain` set counts as winning, and it is never removed from the board.
var is_goal := false
## Where this piece stood when it was last locked, so a collapsed run can be
## stood back up exactly as it was built instead of being rebuilt by hand.
var placed_xform := Transform3D.IDENTITY
var has_place := false
## Impulse waiting for the next physics frame. See push_next().
var _pending_push := Vector3.ZERO
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D

func setup(c: Color) -> void:
	color = c
	mass = 0.4
	gravity_scale = 10.0   # a 1 m domino falls like a 5 cm one
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, COM_HEIGHT, 0)
	# Never sleep. `freeze` is what keeps a placed piece from jittering, so
	# sleeping adds nothing - and it actively broke the chain: a piece woken by a
	# contact starts almost motionless, so Jolt put it straight back to sleep,
	# standing bolt upright, where gravity could no longer reach it.
	can_sleep = false
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	contact_monitor = true
	# Generous, because a dropped body_entered is a dropped link in the chain:
	# pieces pile up against each other mid-run and 6 was reachable.
	max_contacts_reported = 12
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.0
	physics_material_override = pm
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	add_child(shape)
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = SIZE
	_mesh.mesh = bm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = c
	_mat.roughness = 0.55
	_mesh.material_override = _mat
	add_child(_mesh)
	# pips on both faces
	for side in [-1.0, 1.0]:
		for k in 2:
			var pip := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.035
			sm.height = 0.07
			pip.mesh = sm
			var pmat := StandardMaterial3D.new()
			pmat.albedo_color = Color(1, 1, 1, 0.9)
			pip.material_override = pmat
			pip.position = Vector3(0, -0.2 + k * 0.4, side * SIZE.z * 0.5)
			_mesh.add_child(pip)
	body_entered.connect(_on_body_entered)

## Loose "is this one still up" query, used for scoring and for picking targets.
## It deliberately tolerates a lean, because a domino mid-fall is still up.
func is_standing() -> bool:
	return global_transform.basis.y.dot(Vector3.UP) > 0.9 and global_position.y > 0.3 and global_position.y < 0.7

## Strict "resting flat on its base" test - the only thing that may be locked.
## With COM_HEIGHT lifted this domino tips past ~6.7 deg, so anything beyond
## 6.3 deg is committed to falling. Never use is_standing() to decide to freeze.
func is_upright() -> bool:
	return global_transform.basis.y.dot(Vector3.UP) > UPRIGHT_DOT and global_position.y > 0.3 and global_position.y < 0.7

## Come to rest properly: flat on the base, at its own yaw, then locked. A real
## domino at rest is never leaning - it either fell or rocked back onto its feet,
## so settling one means straightening the last bit of residual tilt away.
func stand_flat() -> void:
	var fwd := global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = Vector3(0, 0, 1)
	fwd = fwd.normalized()
	var p := global_position
	global_transform = Transform3D(Basis(Vector3.UP.cross(fwd).normalized(), Vector3.UP, fwd), Vector3(p.x, SIZE.y * 0.5, p.z))
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	chain = false
	placed_xform = global_transform
	has_place = true

func is_at_rest() -> bool:
	return freeze or (linear_velocity.length() < 0.06 and angular_velocity.length() < 0.2)

## "This piece has finished whatever it was doing." Velocity alone is not enough
## to answer that: a domino creeping past its own tipping point turns slower than
## any rest threshold worth having, and while the wavefront creeps, everything
## behind it lies still and everything ahead is still frozen - so the WHOLE board
## reads as at rest and a run that is very much alive gets declared dead. Being
## caught mid-lean is the proof it is not over: a piece is only ever found there
## on its way down.
func is_resolved() -> bool:
	return is_at_rest() and (is_upright() or not is_upright_enough())

## Let physics take over. `from_chain` is true only for the piece the player
## pushes to start the run, and for everything that piece knocks over in turn.
## The cat, a gust and a careless hand all leave it false, which is what keeps
## an accidental topple of the goal from counting as a win.
func wake(from_chain := false) -> void:
	if carried or not freeze or not armed:
		return
	chain = from_chain
	freeze = false
	sleeping = false
	disturbed.emit(self)

## Stop dead exactly where you are and stay there.
##
## Used at the start of a rebuild, and for a piece that has come to rest lying
## down. Both want the same thing: nothing left dynamic. During a rebuild that
## is what stops a piece already stood back up from being knocked over again by
## a neighbour the rebuild has not reached yet; on the desk it stops a pile of
## never-sleeping bodies accumulating for the rest of the game.
func hold() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	chain = false
	_pending_push = Vector3.ZERO

## Loose "has not already been flattened" test, with a deliberately huge margin
## (60 deg). It must say YES to a piece that is merely wobbling and NO only to
## one that was already down before the chain got to it. Never use it to decide
## to lock a piece - that is is_upright()'s job, and its margin is tiny.
func is_upright_enough() -> bool:
	return global_transform.basis.y.dot(Vector3.UP) > 0.5

## Stand back up exactly where this piece was built, ready to run again.
func restand() -> void:
	if not has_place:
		return
	freeze = true
	global_transform = placed_xform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	chain = false
	_pending_push = Vector3.ZERO

## The impulse handed to the piece we just hit, in N.s. See _on_body_entered
## for why any of it has to be handed over by script at all.
##
## HANDOFF_MIN is the load-bearing number, and it is sized from the barrier it
## has to clear rather than picked by feel. Lifting a domino's centre of mass
## past its own tipping point takes
##   m * (g * gravity_scale) * dh = 0.4 * 98 * 0.0047 ~= 0.18 J
## and an impulse J applied 0.4 m up delivers (J * 0.4)^2 / (2 * I) with
## I ~= 0.034, so J must exceed ~0.28 N.s to topple anything at all. Below that
## the piece merely leans on the next one and the whole run stalls in a
## staircase with every piece woken, flagged, and still standing. 0.5 clears it
## about threefold - enough to be certain, short of launching pieces.
##
## A fast chain hits harder than the floor, which is what makes a long straight
## stretch look and feel faster than a patched-up corner.
const HANDOFF_MIN := 0.5
const HANDOFF_MAX := 1.5
const HANDOFF_PER_SPEED := 0.8

## Touching the next piece is what makes its fall OURS. That is conferred here,
## on real contact, and never by the proximity wake that runs ahead of the fall -
## so a piece the chain merely got close to is not credited with anything.
##
## `disturbed` is re-emitted when the flag advances onto an already-awake piece,
## because that is the signal the task uses to unfreeze the next piece along.
func _on_body_entered(b: Node) -> void:
	if freeze or not (b is DominoBody) or b.carried:
		return
	# ...and only a piece that had not ALREADY been flattened when we reached it.
	# Brushing past one that is already down earns nothing: otherwise a cat could
	# flatten the goal, the chain could arrive later and nudge the wreckage, and
	# that would read as a win the player never built.
	#
	# The test has to be `is_upright_enough`, not `is_standing`: the proximity
	# wake leaves the piece ahead dynamic, so by the time our fall lands on it it
	# is often already tipping - and is_standing() gives up at 26 deg. Using it
	# here dropped the flag mid-run, and because propagation continues either way
	# every piece after that point, goal included, arrived unflagged. One lost
	# link killed the verdict on a perfectly good run.
	if chain and not b.chain and not b.is_upright_enough():
		return                  # already flat before we got here: earns nothing
	if b.freeze:
		# The contact was spent against a frozen (infinite-mass) body, so none of
		# our momentum crossed over. Hand it the push physics threw away, near its
		# top where it does the tipping - and never less than HANDOFF_MIN. That
		# floor is the whole reason the chain does not run out of
		# steam: letting real physics carry the hop instead means each piece
		# passes on slightly less than it received, and the wave dies in a
		# staircase of pieces leaning on one another.
		# Direction from geometry, not from our own linear_velocity: a domino
		# toppling about its base edge can have almost no horizontal COM speed at
		# the instant it lands, and reading the push off that left the piece ahead
		# woken and flagged but never actually pushed.
		var dir: Vector3 = b.global_position - global_position
		dir.y = 0.0
		if dir.length() < 0.01:
			dir = -global_transform.basis.z
		var speed := Vector3(linear_velocity.x, 0.0, linear_velocity.z).length()
		b.wake(chain)
		b.push_next(dir.normalized() * clampf(speed * HANDOFF_PER_SPEED, HANDOFF_MIN, HANDOFF_MAX))
	elif chain and not b.chain:
		b.chain = true          # awake already, knocked loose earlier: still ours

## Queue an impulse for the NEXT physics frame.
##
## It cannot be applied now: the body has just come out of `freeze` this same
## frame, and Godot resets its state on that transition - an impulse applied
## before the step lands is silently thrown away. That is what stalled the chain
## with the last pieces woken, flagged, and standing bolt upright at exactly
## dot = 1.00 with zero angular velocity.
func push_next(impulse: Vector3) -> void:
	_pending_push = impulse

func _physics_process(_delta: float) -> void:
	if _pending_push == Vector3.ZERO or freeze:
		return
	# near the top, where it tips the piece rather than shoving it along the desk
	apply_impulse(_pending_push, Vector3(0, 0.4, 0))
	_pending_push = Vector3.ZERO

## Small visual jitter (wind) without touching the physics body.
func set_jitter(v: Vector3) -> void:
	_mesh.position = v

func set_alpha(a: float) -> void:
	if a < 1.0:
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(color, a)
