class_name WindEvent
extends EnvironmentalEvent
## A gust of wind.
## curtain moves -> small wind (leaves) -> paper flutters -> dominoes shake -> GUST
## Player: close the window (resolve), or hold the hand shield when it hits.

const ACTION_CLOSE := "close_window"

@export var window_path: NodePath
@export var curtain_path: NodePath
@export var paper_path: NodePath
@export var particles_path: NodePath

# duck-typed so the 2D and 3D scenes can share this event
var _window: Node
var _curtain: Node
var _paper: Node
var _particles: Node
var _cleanup_timer: Timer

func _ready() -> void:
	super._ready()
	_window = get_node(window_path)
	_curtain = get_node(curtain_path)
	_paper = get_node_or_null(paper_path)
	_particles = get_node_or_null(particles_path)
	_window.interacted.connect(_on_window_clicked)
	_cleanup_timer = Timer.new()
	_cleanup_timer.one_shot = true
	_cleanup_timer.timeout.connect(_finish_cleanup)
	add_child(_cleanup_timer)

func _build_stages() -> Array[Dictionary]:
	return [
		{ "phase": Phase.WARNING,    "text": "Rèm cửa khẽ động, cửa sổ hé ra",      "duration": 3.0 },
		{ "phase": Phase.WARNING,    "text": "Gió nhẹ lùa vào, vài chiếc lá bay",   "duration": 3.0 },
		{ "phase": Phase.ESCALATING, "text": "Tờ giấy trên bàn bắt đầu bay",        "duration": 3.0 },
		{ "phase": Phase.DANGER,     "text": "Domino rung lên - gió lớn sắp tới!",   "duration": 3.0 },
	]

func get_actions() -> Array[Dictionary]:
	var actions: Array[Dictionary] = [
		{ "id": ACTION_CLOSE, "label": "Đóng cửa sổ", "hint": "Chặn gió hoàn toàn", "callable": close_window },
	]
	actions.append_array(super.get_actions())
	return actions

# ----------------------------------------------------------------- hooks

func _on_start() -> void:
	if not _cleanup_timer.is_stopped():
		_cleanup_timer.stop()
		_finish_cleanup()

func _on_stage_entered(index: int) -> void:
	_window.status_text = get_stage_text()
	match index:
		0:
			_window.set_open(true)
			_curtain.wind_level = 1.0
			Sfx.play("creak", -6.0)
		1:
			_curtain.wind_level = 2.0
			if _particles:
				_particles.emitting = true
			Sfx.play("wind", -12.0)
		2:
			_curtain.wind_level = 2.6
			if _paper:
				_paper.flutter = 1.0
			Sfx.play("rattle", -14.0)
		3:
			_curtain.wind_level = 3.2
			if _paper:
				_paper.flutter = 2.0
			task.set_shaking(true)
			Sfx.play("wind", -4.0)
			Sfx.play("rattle", -8.0)

func _on_resolved() -> void:
	EventBus.notify.emit("Đã đóng cửa sổ - gió không vào được nữa.", Color(0.6, 0.95, 0.6))
	Sfx.play("resolve")
	_cleanup(false)

func _on_cancelled() -> void:
	_cleanup(false)

func _on_impact() -> bool:
	_curtain.gust()
	Sfx.play("wind", 0.0)
	if _particles:
		_particles.amount = 60
		_particles.emitting = true
	if _paper:
		_paper.blow_away()
	var shielded: bool = task.shield_active
	if shielded:
		EventBus.notify.emit("Gió thổi qua... tay che kịp! Domino vẫn đứng.", Color(0.6, 0.95, 0.6))
		Sfx.play("resolve")
	else:
		task.gust()
	_cleanup(true)
	return shielded

## Wind dies down and the window bangs shut (so it can pop open again later).
func _cleanup(after_gust: bool) -> void:
	task.set_shaking(false)
	_cleanup_timer.start(1.4 if after_gust else 0.2)

func _finish_cleanup() -> void:
	_curtain.wind_level = 0.0
	_window.set_open(false)
	_window.status_text = ""
	if _paper:
		_paper.flutter = 0.0
	if _particles:
		_particles.emitting = false
		_particles.amount = 30

# ----------------------------------------------------------------- actions

func close_window() -> void:
	if not active:
		return
	_window.set_open(false)
	resolve()

func _on_window_clicked() -> void:
	if active and _window.is_open:
		close_window()
