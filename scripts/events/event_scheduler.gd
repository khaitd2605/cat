class_name EventScheduler
extends Node
## Picks which EnvironmentalEvent (its child nodes) fires next and when.
## Adding a new event = drop a new EnvironmentalEvent node under this one.

@export var task_path: NodePath
@export var first_delay := 7.0
@export var min_gap := 5.0
@export var max_gap := 10.0
## How much faster/denser events get at 100% task progress.
@export var final_speed_scale := 0.7

var _events: Array[EnvironmentalEvent] = []
var _current: EnvironmentalEvent
var _last: EnvironmentalEvent
var _timer := 0.0
var _task: Node

func _ready() -> void:
	_task = get_node_or_null(task_path)
	for child in get_children():
		if child is EnvironmentalEvent:
			_events.append(child)
	_timer = first_delay

func _process(delta: float) -> void:
	if not GameManager.is_playing() or _current != null or _events.is_empty():
		return
	_timer -= delta
	if _timer <= 0.0:
		_start_next()

func _start_next() -> void:
	var candidates := _events.duplicate()
	if candidates.size() > 1 and _last:
		candidates.erase(_last)
	_current = candidates.pick_random()
	_last = _current
	_current.finished.connect(_on_event_finished, CONNECT_ONE_SHOT)
	_current.start(lerp(1.0, final_speed_scale, _progress()))

func _on_event_finished(_resolved: bool) -> void:
	_current = null
	_timer = randf_range(min_gap, max_gap) * lerp(1.0, 0.6, _progress())

func _progress() -> float:
	return _task.get_progress() if _task else 0.0
