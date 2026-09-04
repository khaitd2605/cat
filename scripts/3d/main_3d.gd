extends Node3D
## 3D scene root. Glue only: physics picking, keyboard restart, debug bot.

func _ready() -> void:
	get_viewport().physics_object_picking = true
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		var tester: Node = load("res://scripts/3d/auto_tester_3d.gd").new()
		tester.mode = "win" if "--autotest-win" in args else "fail"
		add_child(tester)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		GameManager.restart()
