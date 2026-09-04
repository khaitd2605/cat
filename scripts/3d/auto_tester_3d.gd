extends Node
## Debug-only bot for the 3D scene. It exists to answer the one question the
## new mechanic turns on: does a chain that reaches the goal WIN, and does a
## goal knocked over any other way NOT win?
##
##   --autotest --autotest-win   lay a full route, push, expect game_won
##   --autotest                  lay a short route, push, expect no win
##   --autotest --autotest-cheat lay a full route, flatten the goal BY HAND,
##                               push anyway, expect no win
##
##   --autotest-sabotage        lay a full route, push, then flatten the goal BY
##                               HAND while the chain is still on its way
##   --autotest-robot           park the robot vacuum ON TOP of the goal and let
##                               it run: expect the goal not to budge. Then lay,
##                               push, and expect the robot to be frozen solid
##                               for the whole run. Both halves of the two-phase
##                               rule, aimed at the newest disruptive agent.
##   add --autotest-level N      play level N (0-based). Without it the autotest
##                               runs the LAST level - the crowded desk with the
##                               wind, the cat and the robot all awake, which is
##                               the only one where a pass means anything.
##   add --autotest-obstacles    keep the obstacles. The router plans its corridor
##                               by breadth-first search now, so it routes around
##                               them instead of boxing itself in - which makes
##                               this the mode that tests the hard courses.
##
## Run with: godot --path . -- --autotest --autotest-win

var mode := "fail"
var _task: DominoTask3D
var _t := 0.0
var _pushed := false
var _won := false
var _laid := 0
var _sampled := false
var _next_sample := 1.5
var _samples := 0
## Highest chain_flagged seen while the run was live. The verdict is taken long
## after the rebuild has reset every flag, so this is the only place the run's
## own reach survives - and it is what tells a real negative from one that
## passed because the chain never got anywhere.
var _peak_flagged := 0
## cheat mode: was the goal still standing after being hit by hand mid-BUILD?
var _goal_survived := false
var _sabotaged := false
var _shot := false
var _robot: RobotVacuum3D
## robot mode: 0 not started, 1 sitting on the goal, 2 done
var _robot_probe := 0
var _robot_goal_ok := false
var _robot_froze := false
var _robot_checked := false
var _robot_at_push := Vector3.ZERO
## Ground covered in the free-roam probe. Wedged, docked or dead all look the
## same from the outside; this is the one number that tells them apart.
## Both landmarks inside the camera frame. See _check_frame.
var _frame_ok := true
var _robot_travel := 0.0
var _robot_prev := Vector3.ZERO
var _robot_next := 1.0
var _first: DominoBody

func _ready() -> void:
	_check_frame.call_deferred()

	_task = get_tree().current_scene.get_node("DominoTask")
	# Silence the room. The first run of this probe failed because a gust
	# flattened the goal mid-build and _trigger_run() rightly refused to start -
	# the game working as designed, but it tells us nothing about the win rule.
	# The room gets tested by playing; this bot tests cause and effect.
	var sched := get_tree().current_scene.get_node_or_null("Scheduler")
	if sched:
		sched.process_mode = Node.PROCESS_MODE_DISABLED
	EventBus.collapse_finished.connect(func(k: int, s: int) -> void:
		print("[autotest] collapse knocked=%d standing_before=%d" % [k, s]))
	EventBus.game_failed.connect(func(r: String) -> void: print("[autotest] FAILED: %s" % r))
	EventBus.notify.connect(func(t: String, _c: Color) -> void: print("[autotest] notify: %s" % t))
	EventBus.game_won.connect(func() -> void:
		_won = true
		print("[autotest] WON"))
	# Clear the obstacles unless asked to keep them. Whether the bot can route
	# around a box is a question about the bot; whether a chain that reaches the
	# goal wins is a question about the game, and it deserves a clean desk.
	if not "--autotest-obstacles" in OS.get_cmdline_user_args():
		_task.obstacles.clear()
		for c in _task.get_children():
			if c is StaticBody3D:
				c.queue_free()
		print("[autotest] obstacles cleared")
	# The robot roams and flattens; every other mode in here is measuring
	# something else and would just become flaky. It gets its own mode.
	_robot = get_tree().current_scene.get_node_or_null("RobotVacuum") as RobotVacuum3D
	if _robot and mode != "robot":
		_robot.set_enabled(false)
		print("[autotest] robot parked")
	print("[autotest] mode=%s span=%.2f need~%d" % [
		mode, DominoTask3D._xz_dist(_task.start_pos, _task.goal_pos), _task.total_dominoes])

## --autotest-shot: photograph the desk and quit. Debug-only, and the only way
## to check what the clutter on the desk actually looks like without playing.
func _shoot() -> void:
	_shot = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://.shot.png")
	print("[autotest] shot saved %dx%d" % [img.get_width(), img.get_height()])
	get_tree().quit()

func _process(delta: float) -> void:
	_t += delta
	if "--autotest-shot" in OS.get_cmdline_user_args():
		if _t > 1.2 and not _shot:
			# with --autotest-robot, pose the robot out on the desk first - docked
			# and charging is what it looks like least of the time
			if mode == "robot" and _robot:
				_robot.global_position = _task.to_global(Vector3(0.8, 0, 0.6))
				_robot.battery = 0.8
				_robot.heading = 0.6
				_robot.rotation.y = -0.6
				_robot.state = RobotVacuum3D.State.ROAMING
			# --autotest-menu: photograph the level menu instead of the desk. The
			# menu is the one screen no gameplay mode ever reaches, so without this
			# it can only be checked by opening it by hand.
			# --autotest-lamp-off: photograph the desk with the lamp switched off, so
			# the one state that is only reachable by clicking can still be checked.
			if "--autotest-lamp-off" in OS.get_cmdline_user_args():
				var lamp := get_tree().current_scene.get_node_or_null("DeskLamp")
				if lamp:
					lamp._toggle()
			if "--autotest-menu" in OS.get_cmdline_user_args():
				var hud := get_tree().current_scene.get_node_or_null("HUD")
				if hud:
					hud._open_menu()
			_shoot()
		return
	if _pushed:
		# sabotage: flatten the goal BY HAND while the chain is still on its way,
		# so the chain arrives at a goal that is already down through no fault of
		# its own. This is the case Anh Khai worried about, run deliberately.
		if mode == "sabotage" and not _sabotaged and _t > 0.35:
			_sabotaged = true
			print("[autotest] sabotage: hand-toppling the goal mid-run")
			_hand_topple_goal()
		# sample the board mid-run: after the restand the evidence is wiped clean
		if _t > _next_sample and _samples < 6:
			_next_sample += 1.0
			_samples += 1
			_sampled = true
			var down := 0
			var flagged := 0
			for d in _task.dominoes:
				if not d.is_standing():
					down += 1
				if d.chain:
					flagged += 1
			_peak_flagged = maxi(_peak_flagged, flagged)
			print("[autotest] +%.1fs: down=%d chain_flagged=%d first_vel=%.2f" % [_t,
				down, flagged, _first.linear_velocity.length() if _first else -1.0])
			_dump_chain()
		# The robot must not have moved one millimetre since the push. This is the
		# other half of the two-phase rule: the run is judged by how it was laid.
		if mode == "robot" and not _robot_checked and _t > 1.0:
			_robot_checked = true
			var moved := _robot.global_position.distance_to(_robot_at_push)
			_robot_froze = moved < 0.05
			print("[autotest] robot moved %.3f during the run - frozen: %s" % [
				moved, _robot_froze])
		if _t > 26.0:
			_verdict()
		return
	if _t < 0.5:
		return
	if mode == "robot" and _robot_probe < 4:
		_probe_robot()
		return
	# Lay one piece per frame; "fail" mode stops halfway on purpose. Done means
	# the head genuinely AIMS at the goal, not merely that the router ran out of
	# room next to it - and a detour around an obstacle may take three times the
	# pieces a straight line would, so the cap is only a runaway guard.
	var limit := 400 if mode != "fail" else int(_task.total_dominoes * 0.5)
	var done: bool = mode != "fail" and _task._reaches_goal(_task._router_tip())
	if not done and _laid < limit and _task.debug_place_next():
		_laid += 1
		return
	if _laid == 0:
		print("[autotest] could not lay a single piece - course is blocked?")
		_verdict()
		return
	var head := _task.chain_head()
	print("[autotest] laid=%d head_to_goal=%.2f" % [
		_laid, DominoTask3D._xz_dist(head.position, _task.goal_pos) if head else -1.0])
	if not done and mode != "fail":
		_why_stopped()
	_pushed = true      # set BEFORE any await, or _process re-enters and loops
	_t = 0.0
	if mode == "robot":
		# Put it back on the desk, live, in the far corner where it cannot reach
		# the run - so "it did not move" means the gate held, not that it had
		# nothing to do.
		_robot.set_enabled(true)
		_robot.global_position = _task.to_global(Vector3(-5.5, 0, -3.0))
		_robot.battery = 1.0
		_robot.heading = 0.0
		_robot.state = RobotVacuum3D.State.ROAMING
		_robot_at_push = _robot.global_position
		print("[autotest] robot armed in the far corner before the push")
	if mode == "cheat":
		# The goal is LOCKED during BUILD, so this must achieve nothing at all.
		# What used to be tested here - "the trigger refuses while the goal is
		# down" - can no longer be reached: the goal cannot be got down in the
		# first place. So the assertion moved to the lock itself.
		# knock the goal flat by hand: it goes down, but with chain = false
		print("[autotest] hand-toppling the goal before the push")
		_hand_topple_goal()
		# Short, deliberately: the goal stands ITSELF back up once the collapse
		# settles, so waiting it out would just hand us an honest run. The gate
		# under test is "you cannot push while the goal is lying there", and the
		# only window to test it in is before the desk tidies itself.
		await get_tree().create_timer(1.2).timeout
		_goal_survived = _task.goal.is_upright()
		print("[autotest] goal survived the hand-topple: %s" % _goal_survived)
		_t = 0.0
	_first = _task._starter()
	if _first == null:
		print("[autotest] no starter within reach of the peg")
	else:
		print("[autotest] starter at %.2f from peg" % DominoTask3D._xz_dist(_first.position, _task.start_pos))
	_task.debug_trigger()
	if _task.phase != DominoTask3D.Phase.RUN:
		print("[autotest] trigger REFUSED (goal standing=%s)" % _task.goal.is_standing())
		_verdict()

func _verdict() -> void:
	var down := 0
	var flagged := 0
	var unfrozen := 0
	for d in _task.dominoes:
		if not d.is_standing():
			down += 1
		if d.chain:
			flagged += 1
		if not d.freeze:
			unfrozen += 1
	print("[autotest] board: total=%d down=%d chain_flagged=%d unfrozen=%d phase=%d" % [
		_task.dominoes.size(), down, flagged, unfrozen, _task.phase])
	var g := _task.goal
	print("[autotest] goal: chain=%s upright=%s standing=%s -> won=%s" % [
		g.chain, g.is_upright(), g.is_standing(), _won])
	# cheat expects a WIN: the hand-topple is refused outright, so the run that
	# follows it is an ordinary honest one.
	var want := mode == "win" or mode == "cheat" or mode == "robot"
	var ok := _won == want
	# Checked first, because a course half off the frame makes every other
	# verdict below it meaningless - the bot passes by coordinates on a desk the
	# player cannot see.
	if ok and not _frame_ok:
		print("[autotest] LEVEL BROKEN: part of the course is outside the camera frame")
		ok = false
	# A negative test that passes because the chain never got there proves nothing
	# about the win rule. Sabotage in particular has to show a healthy run that
	# reached the goal's own neighbour and STILL was not credited.
	# 70%, not "every piece": the hand-toppled goal lies across the end of the
	# route and legitimately blocks the last piece or two. The bar only has to be
	# high enough that a chain which died early cannot pass for a sabotaged one.
	if mode == "cheat" and ok and not _goal_survived:
		print("[autotest] LOCK BROKEN: the goal was toppled by hand during BUILD")
		ok = false
	# Eight seconds at full speed is the ceiling; a robot that patrols properly
	# loses some of it to bumps and to the trip home on a flat battery. Half of
	# the ceiling is the floor, and the threshold is derived rather than typed
	# because it was a hard 5.0 when `speed` was tuned down to 0.6 - the test
	# went red on a robot that was working perfectly.
	var floor_travel := _robot.speed * 8.0 * 0.5
	if mode == "robot" and ok and _robot_travel < floor_travel:
		print("[autotest] robot only covered %.1f of a possible %.1f units in 8s - wedged?" % [
			_robot_travel, _robot.speed * 8.0])
		ok = false
	if mode == "robot" and ok and not _robot_goal_ok:
		print("[autotest] LOCK BROKEN: the robot knocked the goal over during BUILD")
		ok = false
	if mode == "robot" and ok and not _robot_froze:
		print("[autotest] GATE BROKEN: the robot kept driving during the push")
		ok = false
	if mode == "sabotage" and ok and _peak_flagged < int(_task.dominoes.size() * 0.7):
		print("[autotest] VACUOUS: chain only reached %d of %d - nothing was sabotaged" % [
			_peak_flagged, _task.dominoes.size()])
		ok = false
	print("[autotest] RESULT %s (expected won=%s)" % ["PASS" if ok else "FAIL", want])
	get_tree().quit()

## Walk the run in placement order and print where the fall stops. `dominoes[0]`
## is the goal, so the route itself is [1..]. dot is basis.y . UP: 1.0 upright,
## 0.0 flat. gap is the centre distance to the next piece along the route.
func _dump_chain() -> void:
	var route := _task.dominoes.slice(1)
	var lines: Array[String] = []
	for i in route.size():
		var d: DominoBody = route[i]
		var gap := -1.0
		if i + 1 < route.size():
			gap = DominoTask3D._xz_dist(d.position, route[i + 1].position)
		if i < route.size() - 8:
			continue
		lines.append("%d:dot=%.2f%s%s gap=%.2f w=%.2f slp=%s cs=%s" % [
			i, d.global_transform.basis.y.dot(Vector3.UP),
			"C" if d.chain else "-", "F" if d.freeze else "d", gap,
			d.angular_velocity.length(), d.sleeping, d.can_sleep])
	print("[autotest] tail: %s" % " | ".join(lines))
	var g: DominoBody = _task.dominoes[0]
	print("[autotest] goalpiece: dot=%.2f chain=%s head_gap=%.2f" % [
		g.global_transform.basis.y.dot(Vector3.UP), g.chain,
		DominoTask3D._xz_dist(route[route.size() - 1].position, g.position) if route.size() > 0 else -1.0])

## Knock the goal flat BY HAND, the way a careless player or the cat would.
##
## The impulse cannot go in the same frame as the wake: Godot resets a body's
## state coming out of `freeze` and throws the impulse away - the same trap the
## chain's own handoff fell into. Waiting one physics frame is what makes this
## test actually test something.
func _hand_topple_goal() -> void:
	_task.goal.wake()
	await get_tree().physics_frame
	_task.goal.apply_impulse(Vector3(0, 0, 6.0), Vector3(0, 0.45, 0))

## robot mode, first half: drop the robot straight onto the goal with a full
## battery and let it drive into it for a moment.
##
## It cannot get away - `_blocked` keeps its centre well clear of the goal, so
## it bumps in place and sweeps the same spot every frame, which is the harshest
## version of the test there is. If the BUILD lock is real the goal does not
## move at all; if it is not, this finds out in one second flat.
func _probe_robot() -> void:
	if _robot == null:
		_robot_probe = 4
		_robot_goal_ok = true
		_robot_froze = true
		_robot_travel = 99.0
		print("[autotest] no RobotVacuum in the scene - skipping the probe")
		return
	match _robot_probe:
		0:
			# Let it loose from its dock with a full charge and just watch. This
			# is the half of the mechanic no assertion about the goal can reach:
			# whether the thing actually patrols, or wedges itself against the
			# first mug it meets and stands there humming for the rest of the
			# level. Total distance covered answers all of that at once.
			_robot_probe = 1
			_robot.set_enabled(true)
			_robot.battery = 1.0
			_robot.state = RobotVacuum3D.State.ROAMING
			_robot_prev = _robot.global_position
			print("[autotest] robot let loose from its dock")
			_t = 0.0
		1:
			var p := _robot.global_position
			_robot_travel += p.distance_to(_robot_prev)
			_robot_prev = p
			if _t > _robot_next:
				_robot_next += 1.0
				print("[autotest] +%.0fs robot at (%.1f, %.1f) state=%d pin=%.0f%% travelled=%.1f" % [
					_t, p.x, p.z, _robot.state, _robot.battery * 100.0, _robot_travel])
			if _t > 8.0:
				_robot_probe = 2
		2:
			# Now the harsh one: pin it to the goal and hold it there, sweeping
			# the same spot every frame for over a second. Held deliberately -
			# the robot is allowed to drive out of anything it finds itself
			# inside, so left to itself it would slide off and prove much less.
			_robot_probe = 3
			_robot.global_position = _task.to_global(
				Vector3(_task.goal_pos.x, 0, _task.goal_pos.z))
			_robot.battery = 1.0
			_robot.state = RobotVacuum3D.State.ROAMING
			print("[autotest] robot dropped on the goal, running")
			_t = 0.0
		3:
			_robot.global_position = _task.to_global(
				Vector3(_task.goal_pos.x, 0, _task.goal_pos.z))
			if _t > 1.2:
				_robot_probe = 4
				_robot_goal_ok = _task.goal.is_upright()
				print("[autotest] goal survived the robot: %s" % _robot_goal_ok)
				# Off the desk for the laying: whether the router can dodge a
				# moving robot is a different question, and not this test's.
				_robot.set_enabled(false)
				_t = 0.6

## The router stopped without aiming at the goal. Say why, in one line.
##
## "Stopped short" has several quite different causes and they need quite
## different fixes: the plan ran out and a fresh one could not be found; the next
## planned spot became illegal; or a piece fell over and left a hole nothing may
## be placed in. Guessing between them wasted an afternoon once already.
func _why_stopped() -> void:
	var fallen := 0
	for d in _task.dominoes:
		if not d.is_goal and not d.is_standing():
			fallen += 1
	var nxt := "(plan exhausted)"
	if _task._plan_i < _task._plan.size():
		nxt = "'%s'" % _task._placement_problem(_task._plan[_task._plan_i])
	var tip := _task._router_tip()
	var replan := _task._plan_route(tip)
	var first := "-"
	if replan and not _task._plan.is_empty():
		first = "'%s'" % _task._placement_problem(_task._plan[0])
	print("[autotest] gave up: at %d/%d next=%s fallen=%d tip=%s replan=%s len=%d first=%s" % [
		_task._plan_i, _task._plan.size(), nxt, fallen,
		"yes" if tip != null else "NONE", replan, _task._plan.size(), first])

## Is the course actually ON SCREEN? A level whose goal sits past the edge of
## the frame is unplayable and every other assertion in here passes happily -
## the bot routes to it by coordinates and never has to look at it. Level 6 was
## authored with its goal at x=5.8 on the near edge and the screenshot showed
## the label sliced off, which is how this check came to exist.
func _check_frame() -> void:
	var cam := get_tree().current_scene.get_node_or_null("Camera") as Camera3D
	if cam == null or _task == null:
		return
	var vp := get_viewport().get_visible_rect().size
	# Fractions, not pixels. The old check hardcoded 90/60/80 against whatever
	# viewport it happened to get, so the same desk passed at one window size and
	# failed at another - and 1152x720 is not the resolution anyone asked for, it
	# is what the window manager handed back.
	var mx := vp.x * 0.07
	var mt := vp.y * 0.085
	var mb := vp.y * 0.11
	# Every probe is a point that is actually DRAWN, which is the whole fix here.
	# The check used to unproject the landmark's base at y=0.5 and pass, while the
	# thing hanging off it went over the edge: the goal wears a flag at
	# (x + 0.24, 1.45) whose quad reaches another 0.225 further out, and a label
	# above that at y=1.9. On the level 6 goal the base reported 51px of headroom
	# while the flag sat 22px outside the margin. A frame check that measures the
	# one part of a landmark with nothing attached to it is not a frame check.
	#
	# Per landmark, because they are not decorated alike: the start is a flat peg
	# with a low label, the goal is a flag on a pole. Probing the start at the
	# goal's heights would fail desks that are perfectly fine.
	var s: Vector3 = _task.start_pos
	var g: Vector3 = _task.goal_pos
	var probes := [
		["BAT DAU", "chan", Vector3(s.x, 0.06, s.z)],
		["BAT DAU", "nhan", Vector3(s.x, 0.75, s.z)],
		["DICH", "chan", Vector3(g.x, 0.5, g.z)],
		["DICH", "nhan", Vector3(g.x, 1.9, g.z)],
		["DICH", "co", Vector3(g.x + 0.465 * _task.flag_side(), 1.45, g.z)],
	]
	for probe in probes:
		var sp := cam.unproject_position(_task.to_global(probe[2]))
		if sp.x < mx or sp.x > vp.x - mx or sp.y < mt or sp.y > vp.y - mb:
			_frame_ok = false
			print("[autotest] OFF SCREEN: %s %s at %s lands at %s in a %s frame" % [
				probe[0], probe[1], probe[2], sp, vp])
