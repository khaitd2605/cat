extends Node2D
## Scene root. Only glue: keyboard restart and optional debug auto-tester.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		var tester: Node = load("res://scripts/debug/auto_tester.gd").new()
		tester.mode = "win" if "--autotest-win" in args else "fail"
		add_child(tester)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		GameManager.restart()
