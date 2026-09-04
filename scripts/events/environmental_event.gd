class_name EnvironmentalEvent
extends Node
## Base class for anything in the room that can ruin the player's work.
##
## Lifecycle:  IDLE -> WARNING -> ESCALATING -> DANGER -> TRIGGERED / RESOLVED
## An event runs through a list of STAGES, each tagged with a phase, a text and
## a duration. The player can resolve it during any stage; if none of them do,
## it TRIGGERS (impact). Subclasses override the _on_* hooks and get_actions();
## they never touch UI.

signal finished(resolved: bool)

enum Phase { IDLE, WARNING, ESCALATING, DANGER, TRIGGERED, RESOLVED }

## Action id every event offers: keep working and accept the risk.
const ACTION_IGNORE := "ignore"

@export var event_id := "event"
## Short title, e.g. "GIÓ LÙA".
@export var warning_title := "SỰ CỐ"
## Icon kind understood by WarningIcon ("wind", "cat", ...).
@export var icon_kind := "generic"
## Shown on the failure screen when this event knocks the dominoes.
@export var failure_text := "Sự cố đã phá hỏng công việc của bạn."
## The signals the player should have noticed - taught on the failure screen.
@export var missed_signals_text := ""
## The work being threatened. Every event needs it (impact target, shaking...).
## Duck-typed (2D DominoTask or 3D DominoTask3D share the same API).
@export var task_path: NodePath

var task: Node
var phase: Phase = Phase.IDLE
## Each entry: { "phase": Phase, "text": String, "duration": float }
var stages: Array[Dictionary] = []
var stage_index := -1
var active := false
var _stage_time_left := 0.0
var _speed_scale := 1.0

func _ready() -> void:
	task = get_node_or_null(task_path)
	stages = _build_stages()
	set_process(false)
	EventBus.game_won.connect(cancel)
	EventBus.game_failed.connect(func(_reason): cancel())

# ----------------------------------------------------------------- lifecycle

func start(speed_scale := 1.0) -> void:
	if active:
		return
	_speed_scale = speed_scale
	active = true
	stage_index = -1
	set_process(true)
	_on_start()
	EventBus.warning_started.emit(self)
	_next_stage()

func _process(delta: float) -> void:
	if not active:
		return
	_stage_time_left -= delta
	if _stage_time_left <= 0.0:
		_next_stage()

func _next_stage() -> void:
	stage_index += 1
	if stage_index >= stages.size():
		_impact()
		return
	var s := stages[stage_index]
	phase = s.get("phase", Phase.WARNING)
	_stage_time_left = s["duration"] * _speed_scale
	_on_stage_entered(stage_index)
	EventBus.warning_stage_changed.emit(self, stage_index, s["text"])

## Player dealt with the threat before it hit.
func resolve() -> void:
	if not active:
		return
	if OS.is_debug_build():
		print("[event] %s resolved at stage %d, elapsed %.1f" % [event_id, stage_index, GameManager.elapsed])
	_end(Phase.RESOLVED)
	_on_resolved()
	EventBus.warning_ended.emit(self, true)
	finished.emit(true)

## The run ended (win/other failure) while this event was still building up.
func cancel() -> void:
	if not active:
		return
	_end(Phase.IDLE)
	_on_cancelled()
	EventBus.warning_ended.emit(self, true)
	finished.emit(true)

func _impact() -> void:
	if OS.is_debug_build():
		print("[event] %s IMPACT, elapsed %.1f" % [event_id, GameManager.elapsed])
	_end(Phase.TRIGGERED)
	var mitigated := _on_impact()
	if mitigated:
		EventBus.impact_mitigated.emit(self)
	else:
		EventBus.impact_started.emit(self)
	EventBus.warning_ended.emit(self, mitigated)
	finished.emit(mitigated)

func _end(p: Phase) -> void:
	active = false
	phase = p
	set_process(false)
	# back to IDLE once the dust settles so status text reads right
	get_tree().create_timer(2.0).timeout.connect(func():
		if not active and is_instance_valid(self):
			phase = Phase.IDLE)

# ------------------------------------------------------------------ queries

func get_stage_text() -> String:
	if stage_index < 0 or stage_index >= stages.size():
		return ""
	return stages[stage_index]["text"]

func get_total_time() -> float:
	var t := 0.0
	for s in stages:
		t += s["duration"] * _speed_scale
	return t

func get_time_left() -> float:
	if not active:
		return 0.0
	var t := _stage_time_left
	for i in range(stage_index + 1, stages.size()):
		t += stages[i]["duration"] * _speed_scale
	return t

## 0 = just started, 1 = about to impact.
func get_danger() -> float:
	var total := get_total_time()
	if total <= 0.0:
		return 1.0
	return clamp(1.0 - get_time_left() / total, 0.0, 1.0)

## Actions offered to the player: [{ "id", "label", "hint", "callable" }].
func get_actions() -> Array[Dictionary]:
	return [{
		"id": ACTION_IGNORE,
		"label": "Tiếp tục xếp",
		"hint": "(Rủi ro cao)",
		"callable": Callable(),
	}]

# -------------------------------------------------------- subclass hooks

func _build_stages() -> Array[Dictionary]:
	return []

func _on_start() -> void:
	pass

func _on_stage_entered(_index: int) -> void:
	pass

func _on_resolved() -> void:
	pass

func _on_cancelled() -> void:
	pass

## Return true if the player mitigated the impact (no damage).
func _on_impact() -> bool:
	return false
