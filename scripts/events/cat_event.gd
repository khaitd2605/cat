class_name CatEvent
extends EnvironmentalEvent
## The cat.
## looks at table -> walks over -> stops near the table -> prepares to jump -> JUMPS
## Player: click the cat (shoo) at any stage.

const ACTION_SHOO := "shoo"

@export var cat_path: NodePath
## How wide the landing flattens dominoes (local px).
@export var smash_radius := 60.0

var _cat: Node   # duck-typed: Cat (2D) or Cat3D

func _ready() -> void:
	super._ready()
	_cat = get_node(cat_path)
	_cat.interacted.connect(_on_cat_clicked)

func _build_stages() -> Array[Dictionary]:
	return [
		{ "phase": Phase.WARNING,    "text": "Mèo mở mắt, nhìn chằm chằm lên bàn",   "duration": 3.0 },
		{ "phase": Phase.ESCALATING, "text": "Mèo đứng dậy, đi về phía đống domino", "duration": 3.5 },
		{ "phase": Phase.ESCALATING, "text": "Mèo ngồi sát mép, mắt dán vào domino", "duration": 2.5 },
		{ "phase": Phase.DANGER,     "text": "Mèo thu mình - chuẩn bị nhảy!",         "duration": 2.5 },
	]

func get_actions() -> Array[Dictionary]:
	var actions: Array[Dictionary] = [
		{ "id": ACTION_SHOO, "label": "Xua mèo", "hint": "Đuổi mèo về chỗ ngủ", "callable": shoo },
	]
	actions.append_array(super.get_actions())
	return actions

# ----------------------------------------------------------------- hooks

func _on_stage_entered(index: int) -> void:
	_cat.status_text = get_stage_text()
	match index:
		0:
			_cat.look()
			Sfx.play("meow", -14.0)
		1:
			_cat.walk()
			Sfx.play("steps", -10.0)
		2:
			_cat.sit_near()
		3:
			_cat.crouch()
			Sfx.play("growl", -8.0)

func _on_resolved() -> void:
	Sfx.play("meow")
	EventBus.notify.emit("Mèo lười biếng quay về chỗ ngủ.", Color(0.6, 0.95, 0.6))
	_cat.status_text = ""
	_cat.shoo()

func _on_cancelled() -> void:
	_cat.status_text = ""
	_cat.sleep()

func _on_impact() -> bool:
	Sfx.play("meow", 2.0)
	var landing = task.landing_spot()
	_cat.status_text = ""
	_cat.jump_to(landing, func(): task.smash_at(landing, smash_radius))
	return false

# ----------------------------------------------------------------- actions

func shoo() -> void:
	if not active:
		return
	resolve()

func _on_cat_clicked() -> void:
	if active:
		shoo()
	else:
		Sfx.play("purr", -4.0)
