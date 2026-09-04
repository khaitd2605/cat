class_name LevelSet
extends RefCounted
## The campaign, as data: six desks, each one teaching exactly one thing.
##
## Anh Khai picked this shape over hand-placing every mug. A level here is a
## handful of numbers - where you start, where the goal stands, how much clutter,
## which of the three troublemakers are awake - plus a SEED. The clutter is still
## scattered by the same generator that has always done it, but from a fixed
## seed, so a level plays the same every time you come back to it while costing
## nothing to author. If a desk turns out badly, change its seed until it plays
## well; that is the whole tuning loop.
##
## THE TEACHING ORDER IS THE POINT. Level 1 has an empty desk and nobody
## attacking it, because the drop itself - lift, wait for the swing to die,
## release - is already a skill, and learning it while a cat is winding up is
## learning nothing. Then clutter (routing), then wind (the shield), then the cat
## (reading the warnings), then the robot (its two buttons), and only then all of
## it at once. Every mechanic gets one desk where it is the only new thing.
##
## Nothing in here knows about the scene. GameManager owns which level is
## current and hands the dictionary out; the task, the scheduler and the robot
## each read the fields they care about. That keeps the dependency one-way -
## LevelSet is data, and data does not ask questions.

## `start`/`goal` are task-local, so they must stay inside DominoTask3D's
## `area_half` of (6.2, 3.4). `obstacles` is a target the generator may fall
## short of on a crowded desk; `seed` is what makes it repeatable.
##
## Two limits on where the landmarks may go, both learned from screenshots and
## both invisible in the numbers. The camera frame narrows towards the near edge
## of the desk, so past |x| = 5.2 down there the label runs off screen - the
## autotest checks that one now. And the near-RIGHT corner is not free desk: the
## cat sleeps there, with the loose paper and the sticky note beside it. Level 4
## was authored with its goal at (5.0, 2.6) and the goal domino spawned inside
## the sleeping cat. Far side right, or mid-right, is where a goal belongs.
##
## Level 5 deliberately reuses level 3's course. Same desk, same walk, one new
## thing on it - that is the cleanest way to ask "what does the robot change?"
const LEVELS: Array[Dictionary] = [
	{
		"name": "Bàn trống",
		"hint": "Bàn trống, không ai phá. Cầm quân lên, đợi hết lắc rồi thả.",
		"start": Vector3(-2.6, 0, 2.2), "goal": Vector3(2.6, 0, -1.4),
		"obstacles": 0, "seed": 1101,
		"wind": false, "cat": false, "robot": false,
		"first_delay": 99.0, "min_gap": 99.0, "max_gap": 99.0,
	},
	{
		"name": "Vòng qua đồ đạc",
		"hint": "Đồ trên bàn không dẹp được - xếp vòng qua nó.",
		"start": Vector3(-5.0, 0, 2.6), "goal": Vector3(4.6, 0, -1.0),
		"obstacles": 4, "seed": 2027,
		"wind": false, "cat": false, "robot": false,
		"first_delay": 99.0, "min_gap": 99.0, "max_gap": 99.0,
	},
	{
		"name": "Gió đầu mùa",
		"hint": "Gió sắp tới. Đóng cửa sổ, hoặc giữ Space che chắn lúc nó thổi.",
		"start": Vector3(-5.0, 0, 2.6), "goal": Vector3(5.0, 0, -2.6),
		"obstacles": 4, "seed": 3313,
		"wind": true, "cat": false, "robot": false,
		"first_delay": 14.0, "min_gap": 10.0, "max_gap": 15.0,
	},
	{
		"name": "Con mèo",
		"hint": "Con mèo đang nhắm cái bàn. Bấm vô nó để xua, đừng đợi nó nhảy.",
		"start": Vector3(-4.8, 0, -2.6), "goal": Vector3(5.4, 0, 0.6),
		"obstacles": 5, "seed": 4409,
		"wind": false, "cat": true, "robot": false,
		"first_delay": 14.0, "min_gap": 10.0, "max_gap": 15.0,
	},
	{
		"name": "Robot hút bụi",
		"hint": "Robot tuần tra bàn. Bấm vô nó để xoay hướng, bấm dock để gọi về.",
		"start": Vector3(-5.0, 0, 2.6), "goal": Vector3(5.2, 0, -2.4),
		"obstacles": 5, "seed": 5501,
		"wind": false, "cat": false, "robot": true,
		"first_delay": 99.0, "min_gap": 99.0, "max_gap": 99.0,
	},
	{
		"name": "Cả căn phòng",
		"hint": "Gió, mèo và robot cùng lúc, đường chéo cả bàn. Bình tĩnh nhé.",
		"start": Vector3(-4.8, 0, -2.8), "goal": Vector3(5.4, 0, 1.6),
		"obstacles": 7, "seed": 6607,
		"wind": true, "cat": true, "robot": true,
		"first_delay": 11.0, "min_gap": 7.0, "max_gap": 12.0,
	},
]

## How many desks were authored by hand. Past this the campaign generates them,
## so this is NOT the number of levels - there is no number of levels.
static func authored() -> int:
	return LEVELS.size()

## Where a generated course may start and end. These are not random points on the
## desk: every one of them is a coordinate that was already shipped in an authored
## level, which means each has passed the two constraints that cost the most to
## discover - inside the camera frame (the frame narrows towards the near edge, so
## past |x| = 5.2 down there a label runs off screen) and clear of the fixed room
## decor (the near-right corner is the sleeping cat, the loose paper and the sticky
## note; level 4's goal once spawned inside the cat). Generating from a set of
## known-good anchors means a generated desk can never be broken in a way an
## authored one was not.
const _STARTS: Array[Vector3] = [
	Vector3(-5.0, 0, 2.6), Vector3(-4.8, 0, -2.6), Vector3(-4.8, 0, -2.8),
	Vector3(-5.0, 0, 0.4), Vector3(-2.6, 0, 2.2), Vector3(-3.4, 0, -2.8),
]
const _GOALS: Array[Vector3] = [
	Vector3(5.0, 0, -2.6), Vector3(5.4, 0, 0.6), Vector3(4.6, 0, -1.0),
	Vector3(5.2, 0, -2.4), Vector3(5.4, 0, 1.6), Vector3(2.6, 0, -1.4),
]
## Shortest course a generated level may hand out. Below this the desk is crossed
## in a dozen pieces and none of the three hazards gets a chance to matter.
const _MIN_SPAN := 8.0
## Levels over which the ramp runs before it flattens. Past here the desk is as
## hostile as it gets and the only thing still rising is the player.
const _RAMP := 12.0

static var _cache_index := -1
static var _cache: Dictionary = {}

static func count() -> int:
	return LEVELS.size()

## Never out of range: a bad index is a bug somewhere else, and crashing the
## whole desk over it would hide the actual mistake.
static func at(i: int) -> Dictionary:
	if i < 0:
		return LEVELS[0]
	if i < LEVELS.size():
		return LEVELS[i]
	# Generated, and cached because `level_def()` is asked several times per scene
	# load - by the task, the robot, the dock, the scheduler and both toasts - and
	# rebuilding the dictionary each time would be five chances to disagree.
	if i != _cache_index:
		_cache_index = i
		_cache = _generate(i)
	return _cache

## A desk nobody drew. Anh Khai's rule for these: all three hazards awake, always,
## and the difficulty rises through TIMING rather than through anything new - the
## gaps between events close and the robot gets quicker. Nothing appears after
## level 6 that level 6 did not already teach, so a loss here is never a surprise,
## only a thing you were too slow for.
##
## Seeded off the level index, so a given level is the same desk every time you
## open it. That is deliberate: a failed run costs time and makes you rebuild, and
## re-rolling the furniture under a player who is rebuilding would turn their own
## memory of the desk against them.
static func _generate(i: int) -> Dictionary:
	var tier := i - LEVELS.size()
	var t: float = minf(float(tier) / _RAMP, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210 + i * 7919
	# Walk the anchor pairs from a seeded offset and take the first one that spans
	# far enough. A loop rather than a retry: it always terminates, and the pairs
	# are few enough that the first acceptable one is still effectively arbitrary.
	var start: Vector3 = _STARTS[0]
	var goal: Vector3 = _GOALS[0]
	var s0 := rng.randi() % _STARTS.size()
	var g0 := rng.randi() % _GOALS.size()
	for a in _STARTS.size():
		var found := false
		for b in _GOALS.size():
			var cs: Vector3 = _STARTS[(s0 + a) % _STARTS.size()]
			var cg: Vector3 = _GOALS[(g0 + b) % _GOALS.size()]
			if Vector2(cs.x - cg.x, cs.z - cg.z).length() >= _MIN_SPAN:
				start = cs
				goal = cg
				found = true
				break
		if found:
			break
	return {
		"name": "Ngẫu nhiên #%d" % (tier + 1),
		"hint": "Bàn lạ: gió, mèo và robot cùng lúc, và nhịp nhanh hơn màn trước.",
		"start": start, "goal": goal,
		"obstacles": int(roundf(lerpf(7.0, 11.0, t))),
		"seed": 7717 + i * 913,
		"wind": true, "cat": true, "robot": true,
		"first_delay": lerpf(10.0, 4.0, t),
		"min_gap": lerpf(6.5, 2.5, t),
		"max_gap": lerpf(11.0, 5.0, t),
		"robot_speed": lerpf(1.0, 2.0, t),
	}
