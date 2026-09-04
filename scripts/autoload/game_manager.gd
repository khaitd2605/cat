extends Node
## Owns the high-level game state (playing / failing / failed / won), which
## level is being played, and restart.
##
## The level lives here rather than in the scene because the scene is thrown
## away and rebuilt on every restart - `reload_current_scene` is how both "R"
## and "next level" work - so anything that has to survive that has to sit in an
## autoload. Everyone else asks `level_def()`; nobody else counts levels.

enum State { PLAYING, FAILING, FAILED, WON }

const SAVE_PATH := "user://progress.cfg"

var state: State = State.PLAYING
var elapsed := 0.0
## Index into LevelSet.LEVELS.
var level := 0
## Highest level index reached. Kept so quitting mid-campaign does not cost the
## progress, which matters more here than a level-select screen would.
var reached := 0

func _ready() -> void:
	EventBus.task_completed.connect(win)
	_load_progress()
	# The autotest needs a specific desk, and it needs it before the scene is
	# built - which is exactly when an autoload runs. Plain --autotest gets the
	# last level: the crowded, everything-awake desk is the one worth proving.
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		level = LevelSet.authored() - 1
		for i in args.size():
			if args[i] == "--autotest-level" and i + 1 < args.size():
				# No upper clamp: the generated levels have to be testable too, and
				# past the authored ones any index is a real desk.
				level = maxi(0, int(args[i + 1]))

## Jump straight to a level from the menu. The menu only offers levels already
## reached, so this never hands out progress that was not earned.
func go_to_level(i: int) -> void:
	level = clampi(i, 0, reached)
	_save_progress()
	restart()

func level_def() -> Dictionary:
	return LevelSet.at(level)

## Always. Past the six authored desks the campaign generates them, so there is
## no last level to run out of - the ramp flattens, the desks keep coming.
func has_next() -> bool:
	return true

## Move on and rebuild the desk. Only ever called from the win screen.
func next_level() -> void:
	if not has_next():
		return
	level += 1
	reached = maxi(reached, level)
	_save_progress()
	restart()

func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	# No upper bound on `reached` any more, only sanity: the campaign is endless, so
	# a large number here is a player who has been at it, not a corrupt save.
	reached = clampi(int(cfg.get_value("progress", "reached", 0)), 0, 9999)
	# Resume where the player left off, but never past what they have unlocked -
	# a save written by a build with more levels in it must not open a door.
	level = clampi(int(cfg.get_value("progress", "level", reached)), 0, reached)

func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "reached", reached)
	cfg.set_value("progress", "level", level)
	cfg.save(SAVE_PATH)

func _process(delta: float) -> void:
	if state == State.PLAYING:
		elapsed += delta

func is_playing() -> bool:
	return state == State.PLAYING

## True once the result screen is up (not during the falling animation).
func is_over() -> bool:
	return state == State.FAILED or state == State.WON

## Called the moment an impact lands. Input is locked while the dominoes fall.
func start_failing() -> void:
	if state == State.PLAYING:
		state = State.FAILING

func fail(reason: String) -> void:
	if state == State.FAILED or state == State.WON:
		return
	state = State.FAILED
	EventBus.game_failed.emit(reason)

func win() -> void:
	if state != State.PLAYING:
		return
	state = State.WON
	Sfx.play("win")
	EventBus.game_won.emit()

func restart() -> void:
	state = State.PLAYING
	elapsed = 0.0
	# The level menu pauses the tree while it is open, and a restart from inside
	# it would otherwise load the new desk frozen.
	get_tree().paused = false
	get_tree().reload_current_scene()

func format_elapsed() -> String:
	var total := int(elapsed)
	return "%02d:%02d" % [total / 60, total % 60]
