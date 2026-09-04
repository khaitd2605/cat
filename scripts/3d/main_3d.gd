extends Node3D
## 3D scene root. Glue only: physics picking, keyboard restart, debug bot.

func _ready() -> void:
	get_viewport().physics_object_picking = true
	# Deferred so the HUD - a child, therefore already built - has its toast
	# ready to receive it. One line, once, and then the room speaks for itself.
	EventBus.notify.emit.call_deferred(
		"Màn %d: %s" % [GameManager.level + 1, GameManager.level_def()["name"]],
		Color(0.85, 0.92, 1.0))
	Sfx.play.call_deferred("stage", -5.0)
	# A child Timer, not `create_timer`. The lambda on a SceneTreeTimer referenced
	# nothing from `self`, so the engine compiled it as an ownerless callable and
	# did NOT disconnect it when this node was freed - restarting or jumping levels
	# inside 2.6 seconds left an orphan that fired into the NEW scene and clobbered
	# whatever toast was up. A Timer node dies with the scene, which is the point.
	var hint := Timer.new()
	hint.wait_time = 2.6
	hint.one_shot = true
	hint.timeout.connect(_say_hint)
	add_child(hint)
	hint.start()
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		var tester: Node = load("res://scripts/3d/auto_tester_3d.gd").new()
		var modes := {
			"--autotest-win": "win", "--autotest-cheat": "cheat",
			"--autotest-sabotage": "sabotage", "--autotest-robot": "robot" }
		tester.mode = "fail"
		for flag in modes:
			if flag in args:
				tester.mode = modes[flag]
		add_child(tester)

func _say_hint() -> void:
	EventBus.notify.emit(GameManager.level_def()["hint"], Color(1, 0.95, 0.8))

## R replays this level and Enter moves on, but only once the game is over:
## during play an accidental press would throw away a run that took minutes to
## lay, and Enter is the push key.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if GameManager.is_playing():
		return
	if event.keycode == KEY_R:
		GameManager.restart()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER] and GameManager.state == GameManager.State.WON:
		GameManager.next_level()
