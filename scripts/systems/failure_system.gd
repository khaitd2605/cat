class_name FailureSystem
extends Node
## Turns collapses into consequences.
## Small collapse  -> recovery: the fallen dominoes fade, the player rebuilds.
## Big collapse    -> the run is over.

@export var task_path: NodePath
## A collapse that topples at least this share of what stood is fatal...
@export var fatal_share := 0.5
## ...but only when at least this many dominoes were standing.
@export var fatal_min_standing := 8

var _task: Node
var _last_event: EnvironmentalEvent

func _ready() -> void:
	_task = get_node(task_path)
	EventBus.impact_started.connect(func(e): _last_event = e)
	EventBus.collapse_finished.connect(_on_collapse)

func _on_collapse(knocked: int, standing_before: int) -> void:
	if not GameManager.is_playing():
		return
	var share := float(knocked) / maxi(standing_before, 1)
	if standing_before >= fatal_min_standing and share >= fatal_share:
		GameManager.start_failing()
		var reason := _last_event.failure_text if _last_event else "Domino đổ dây chuyền - không cứu được nữa."
		await get_tree().create_timer(0.8).timeout
		GameManager.fail(reason)
	else:
		Sfx.play("thud", -6.0)
		EventBus.notify.emit("Đổ %d quân. Xếp lại nào." % knocked, Color(1.0, 0.8, 0.45))
		_last_event = null
