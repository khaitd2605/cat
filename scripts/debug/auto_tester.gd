extends Node
## Debug-only driver used from the command line to exercise the whole loop
## without a human: builds dominoes, reacts (or not) to warnings, and saves
## screenshots to user://autotest_*.png. Never runs in a normal session.

var mode := "fail"   # "fail": ignore warnings -> failure. "win": resolve everything.
var _task: DominoTask
var _t := 0.0
var _shots := {}
var _drag_done := false

func _ready() -> void:
	_task = get_tree().current_scene.get_node("DominoTask")
	if mode == "win":
		_task.total_dominoes = 40
		_task._build_spiral()
	EventBus.warning_stage_changed.connect(_on_stage)
	EventBus.collapse_finished.connect(func(k, s): print("[autotest] collapse knocked=%d standing_before=%d" % [k, s]))
	EventBus.game_failed.connect(func(_r): _shot("failed", 0.8))
	EventBus.game_won.connect(func(): _shot("won", 0.5))
	print("[autotest] mode=", mode)
	_drag_scenario()

## Exercise carry/drop: a straight drop, a mid-swing drop (topples), a bump.
func _drag_scenario() -> void:
	await get_tree().create_timer(0.6).timeout
	_shot("idle", 0.0)
	var s0: Vector2 = _task.slots[0]["pos"]
	_task.debug_lock_hand = true
	# straight drop on slot 0
	_task.dragging = true
	_task.drag_angle = _task.slots[0]["angle"]
	_task.drag_pos = s0 - Vector2(0, Domino.HEIGHT)
	_task._drag_prev = _task.drag_pos
	_task.swing = 0.0
	_task.swing_vel = 0.0
	_task.drag_started.emit()
	await get_tree().create_timer(0.7).timeout
	_shot("focus_drag", 0.0)
	await get_tree().create_timer(0.2).timeout
	_task.swing = 2.0
	_task._drop()
	print("[autotest] straight drop -> placed=%d" % _task.placed_count())
	# mid-swing drop on slot 1 -> topples (and may take slot 0 with it)
	_task.dragging = true
	_task.drag_angle = _task.slots[1]["angle"]
	_task.drag_pos = _task.slots[1]["pos"] - Vector2(0, Domino.HEIGHT)
	_task.swing = 14.0
	_task._drop()
	print("[autotest] swinging drop -> dominoes=%d" % _task.dominoes.size())
	await get_tree().create_timer(1.5).timeout
	print("[autotest] after topple -> standing=%d placed=%d" % [_task.standing_count(), _task.placed_count()])
	await get_tree().create_timer(2.0).timeout
	print("[autotest] debris cleared -> dominoes=%d" % _task.dominoes.size())
	_drag_done = true

func _process(delta: float) -> void:
	_t += delta
	if _drag_done and GameManager.is_playing() and fmod(_t, 0.3) < delta:
		_task.debug_place_next()
	if _t > 75.0:
		print("[autotest] timeout")
		get_tree().quit(1)

func _on_stage(event: EnvironmentalEvent, index: int, text: String) -> void:
	print("[autotest] %s stage %d [%s]: %s (left %.1fs)" % [event.event_id, index, EnvironmentalEvent.Phase.keys()[event.phase], text, event.get_time_left()])
	if index == 3:
		_shot("danger_%s" % event.event_id, 0.6)
		if mode == "win":
			await get_tree().create_timer(1.0).timeout
			if event.active:
				var actions := event.get_actions()
				print("[autotest] resolving with action: ", actions[0]["label"])
				actions[0]["callable"].call()

func _shot(name: String, delay: float) -> void:
	if _shots.has(name):
		return
	_shots[name] = true
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://autotest_%s_%s.png" % [mode, name]
	img.save_png(path)
	print("[autotest] screenshot -> ", ProjectSettings.globalize_path(path))
	if name == "failed" or name == "won":
		print("[autotest] finished: ", name, " placed=", _task.placed_count())
		await get_tree().create_timer(0.3).timeout
		get_tree().quit(0)
