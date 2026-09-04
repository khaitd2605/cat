extends Node
## Owns the high-level game state (playing / failing / failed / won) and restart.

enum State { PLAYING, FAILING, FAILED, WON }

var state: State = State.PLAYING
var elapsed := 0.0

func _ready() -> void:
	EventBus.task_completed.connect(win)

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
	get_tree().reload_current_scene()

func format_elapsed() -> String:
	var total := int(elapsed)
	return "%02d:%02d" % [total / 60, total % 60]
