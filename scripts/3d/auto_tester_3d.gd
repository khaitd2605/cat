extends Node
## Debug-only bot for the 3D scene: carries/drops dominoes, lets physics run,
## reacts (or not) to warnings, saves screenshots to user://autotest3d_*.png.

var mode := "fail"
var _task: DominoTask3D
var _t := 0.0
var _shots := {}
var _drag_done := false

func _ready() -> void:
	_task = get_tree().current_scene.get_node("DominoTask")
	EventBus.warning_stage_changed.connect(_on_stage)
	EventBus.collapse_finished.connect(func(k, s): print("[autotest] collapse knocked=%d standing_before=%d" % [k, s]))
	EventBus.game_failed.connect(func(_r): _shot("failed", 0.8))
	EventBus.game_won.connect(func(): _shot("won", 0.5))
	print("[autotest] mode=%s slots=%d" % [mode, _task.slots.size()])
	_drag_scenario()

func _drag_scenario() -> void:
	await get_tree().create_timer(0.8).timeout
	await _shot("idle", 0.0)
	# end-to-end real-input probe: click the slot, wiggle, wait for the swing to
	# die down, release - exactly what a player does.
	var cam := get_viewport().get_camera_3d()
	for i in 2:
		var slot_pos: Vector3 = _task.slots[i]["pos"]
		var screen := cam.unproject_position(_task.to_global(slot_pos))
		Input.warp_mouse(screen)
		await get_tree().process_frame
		_press(screen, true)
		await get_tree().process_frame
		print("[probe] #%d picked=%s carried_bottom=%.3f" % [i, _task.dragging, _task.carried_base().y])
		# wiggle the hand to start it swinging, then hold still
		for k in 6:
			Input.warp_mouse(screen + Vector2(sin(k) * 18.0, 0))
			await get_tree().process_frame
		Input.warp_mouse(screen)
		print("[probe] #%d swing after wiggle=%.3f" % [i, _task.swing])
		await get_tree().create_timer(1.2).timeout
		print("[probe] #%d swing settled=%.3f" % [i, _task.swing])
		_press(screen, false)
		await get_tree().create_timer(0.4).timeout
		var d: DominoBody = _task.dominoes[_task.dominoes.size() - 1]
		print("[probe] #%d placed: bottom_y=%.3f standing=%s counted=%d/%d" % [i, d.global_position.y - 0.5, d.is_standing(), _task.placed_count(), _task.total_dominoes])
	await _shot("placed_two", 0.0)
	_task.debug_lock_hand = true
	# height probe: where is the bottom of a carried domino vs the desk?
	_task._begin_carry(0)
	_task.drag_pos = _task.slots[0]["pos"] + Vector3(0, _task.HAND_Y, 0)
	_task.swing = 0.0
	_task.swing_vel = 0.0
	await get_tree().process_frame
	var c := _task._carried
	print("[probe] carried: hand_y=%.3f center_y=%.3f bottom_y=%.3f (desk top = 0)" % [_task.drag_pos.y, c.global_position.y, c.global_position.y - 0.5])
	_task._drop()
	await get_tree().create_timer(0.5).timeout
	var placed: DominoBody = _task.dominoes[0]
	print("[probe] placed straight: center_y=%.3f bottom_y=%.3f freeze=%s" % [placed.global_position.y, placed.global_position.y - 0.5, placed.freeze])
	# stuck-carry probe: pretend the release was swallowed by a UI panel
	_task.debug_lock_hand = false
	_task._begin_carry(_task.next_slot_index())
	await get_tree().create_timer(0.4).timeout
	print("[probe] release swallowed -> dragging=%s (expect false)" % _task.dragging)
	_task.debug_lock_hand = true
	var s0: Vector3 = _task.slots[0]["pos"]
	# straight drop on slot 0
	_task._begin_carry(0)
	_task.drag_pos = s0 + Vector3(0, _task.HAND_Y, 0)
	_task._drag_prev = _task.drag_pos
	_task.swing = 0.0
	_task.swing_vel = 0.0
	await get_tree().create_timer(0.8).timeout
	_shot("focus_carry", 0.0)
	await get_tree().create_timer(0.2).timeout
	_task.swing = 0.02
	_task._drop()
	await get_tree().create_timer(0.3).timeout
	print("[autotest] straight drop -> placed=%d" % _task.placed_count())
	# two more straight, then a swinging drop on slot 3 -> falls into slot 2 -> chain back?
	_task.debug_place_next()
	_task.debug_place_next()
	var s3: Vector3 = _task.slots[3]["pos"]
	_task._begin_carry(3)
	_task.drag_pos = s3 + Vector3(0, _task.HAND_Y, 0)
	_task.swing = -0.2   # leaning back toward slot 2
	_task._drop()
	print("[autotest] swinging drop -> dominoes=%d" % _task.dominoes.size())
	await get_tree().create_timer(3.0).timeout
	print("[autotest] after topple -> standing=%d placed=%d" % [_task.standing_count(), _task.placed_count()])
	_shot("after_topple", 0.0)
	await get_tree().create_timer(2.5).timeout
	print("[autotest] debris cleared -> dominoes=%d placed=%d" % [_task.dominoes.size(), _task.placed_count()])
	# chain probe: 10 dominoes in a row, tip ONLY the first one forward
	for i in 10:
		_task.debug_place_next()
	await get_tree().create_timer(0.3).timeout
	var first: DominoBody = _task.dominoes[_task.dominoes.size() - 4]
	var fwd := DominoTask3D.travel_dir(_task.slots[first.slot]["angle"])
	print("[probe] chain: standing=%d, tipping slot %d" % [_task.standing_count(), first.slot])
	first.wake()
	first.apply_impulse(fwd * 1.5, Vector3(0, 0.45, 0))
	for i in 8:
		await get_tree().create_timer(0.5).timeout
		print("[probe] t+%.1f standing=%d collapse=%s disturbed=%d" % [(i + 1) * 0.5, _task.standing_count(), _task._collapse_active, _task._disturbed.size()])
	_shot("chain", 0.0)
	_drag_done = true

func _press(pos: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = pos
	Input.parse_input_event(ev)

func _process(delta: float) -> void:
	_t += delta
	if _drag_done and GameManager.is_playing() and fmod(_t, 0.3) < delta:
		_task.debug_place_next()
	if _t > 90.0:
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
	if index == 0 and mode == "fail" and event.event_id == "wind":
		_shot_later("gust_%s" % event.event_id, event.get_time_left() + 1.2)

func _shot_later(name: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	_shot(name, 0.0)

func _shot(name: String, delay: float) -> void:
	if _shots.has(name):
		return
	_shots[name] = true
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://autotest3d_%s_%s.png" % [mode, name]
	img.save_png(path)
	print("[autotest] screenshot -> ", ProjectSettings.globalize_path(path))
	if name == "failed" or name == "won":
		print("[autotest] finished: ", name, " placed=", _task.placed_count())
		await get_tree().create_timer(0.3).timeout
		get_tree().quit(0)
