extends CanvasLayer
## Heads-up display: task panel, title tag, hint, toast notifications and the
## failure / win overlay. Layout is container-based so it scales with the
## viewport on Web.
##
## By design there is NO warning banner and NO action panel: the player has to
## notice the room on their own - the curtain, the window, the cat's body
## language, the sounds - and act on it. Telling them outright, and handing them
## a list of buttons to pick from, is the one thing that empties the mechanic.
## `assist_banner` exists as an opt-in accessibility aid and ships OFF.

## Assist mode: show the explicit warning banner + action buttons.
@export var assist_banner := false

## Percent of the gap bridged. Kept as a number now that the bar is gone - the
## result screen still wants to say how far the run got.
var _progress_pct := 0
var _menu: Control
var _menu_rows: VBoxContainer
var _hint: Label
var _toast: Label
var _overlay: Control
var _overlay_title: Label
var _overlay_reason: Label
var _overlay_stats: Label
var _toast_tween: Tween
var _task_total := 0
var _hint_task_label: Label
var _overlay_next: Button
var _last_failed_event: EnvironmentalEvent
var _mode_label: Label

func _ready() -> void:
	# The menu pauses the game while it is open, so the HUD has to keep running
	# through the pause or its own buttons would stop answering.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	EventBus.task_progress.connect(_on_progress)
	EventBus.impact_started.connect(func(e): _last_failed_event = e)
	EventBus.notify.connect(_on_notify)
	EventBus.focus_changed.connect(_on_focus_changed)
	EventBus.game_failed.connect(_on_failed)
	EventBus.game_won.connect(_on_won)

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ---- top row
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top"]:
		top.add_theme_constant_override(side, 18)
	root.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(top_row)

	# The "VD: XEP DOMINO" sticky note used to hang here. It was a joke about the
	# to-do list the desk belongs to, and Anh Khai is right that it earns nothing:
	# the panel opposite already says what the job is, and the note sat in the one
	# corner of the frame where the room itself is worth looking at.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(spacer)

	var task_panel := PanelContainer.new()
	task_panel.add_theme_stylebox_override("panel", UiTheme.panel())
	task_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	task_panel.custom_minimum_size = Vector2(250, 0)
	top_row.add_child(task_panel)
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 6)
	task_panel.add_child(tcol)
	tcol.add_child(UiTheme.label("NHIỆM VỤ", 18, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	# No "of six" any more - the campaign does not end, so a denominator would be
	# a promise the game cannot keep.
	tcol.add_child(UiTheme.label("Màn %d · %s" % [
		GameManager.level + 1, GameManager.level_def()["name"]],
		13, Color(0.85, 0.78, 0.68, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
	# Spelled out, because the panel is the only place the objective is ever
	# stated and "Xep domino" is not an objective - it is a noun. The two
	# landmarks are in caps to match the labels standing on the desk.
	_hint_task_label = UiTheme.label("Xếp domino từ ô BẮT ĐẦU để làm đổ quân ĐÍCH",
		16, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint_task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tcol.add_child(_hint_task_label)
	# No progress bar. It measured the gap bridged towards the goal, which the
	# desk already shows better than any bar can: the chain is right there, and
	# how far it has to go is the distance you can see. A number ticking up next
	# to it only invites you to watch the number.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	tcol.add_child(buttons)
	var pick := UiTheme.button("Chọn màn", 13, Vector2(0, 30))
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.pressed.connect(_open_menu)
	buttons.add_child(pick)
	var restart := UiTheme.button(UiTheme.say("Chơi lại (R)", "Chơi lại"), 13, Vector2(0, 30))
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart.pressed.connect(GameManager.restart)
	buttons.add_child(restart)

	# mode indicator, centred at the top
	var mode_box := MarginContainer.new()
	mode_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mode_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_box.add_theme_constant_override("margin_top", 14)
	root.add_child(mode_box)
	_mode_label = UiTheme.label("QUAN SÁT", 15, Color(0.7, 0.9, 1.0, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	_mode_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mode_box.add_child(_mode_label)

	# ---- bottom stack
	var bottom := MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("margin_bottom", 16)
	root.add_child(bottom)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_END
	stack.add_theme_constant_override("separation", 10)
	bottom.add_child(stack)

	_toast = UiTheme.label("", 18, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.modulate.a = 0.0
	stack.add_child(_toast)

	# Two hint lines, because naming keys a phone does not have is worse than no
	# hint at all: on touch the same verbs live on the buttons TouchControls puts
	# in the bottom corners, and the cheat key is left unsaid.
	var common := "Xếp từ BẮT ĐẦU tới ĐÍCH, quân sau nằm trong vòng sáng của quân trước, đợi hết lắc rồi thả"
	var keys := "  •  Enter / bấm vạch BẮT ĐẦU: đẩy dây  •  Shift: nhìn gần  •  Space: che chắn  •  F2: xếp sẵn (cheat)"
	var taps := "  •  Chạm giữ để nhấc quân, buông tay để đặt  •  Dùng các nút ở hai góc dưới"
	_hint = UiTheme.label(common + (taps if DisplayServer.is_touchscreen_available() else keys),
		14, Color(1, 0.95, 0.85, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_hint)

	if assist_banner:
		stack.add_child(WarningSystem.new())

	# ---- overlay (failure / win)
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.72)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	root.add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel(Color(0.16, 0.11, 0.08, 0.98), UiTheme.GOLD, 18, 3))
	card.custom_minimum_size = Vector2(520, 0)
	center.add_child(card)
	var ccol := VBoxContainer.new()
	ccol.add_theme_constant_override("separation", 14)
	ccol.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(ccol)
	_overlay_title = UiTheme.label("", 40, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	ccol.add_child(_overlay_title)
	_overlay_reason = UiTheme.label("", 18, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_overlay_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_reason.custom_minimum_size = Vector2(480, 0)
	ccol.add_child(_overlay_reason)
	_overlay_stats = UiTheme.label("", 16, Color(0.8, 0.75, 0.68), HORIZONTAL_ALIGNMENT_CENTER)
	ccol.add_child(_overlay_stats)
	# Only ever shown after a win, and it is the first button so the eye lands on
	# the way forward rather than on the way back.
	_overlay_next = UiTheme.button(UiTheme.say("Màn tiếp theo  (Enter)", "Màn tiếp theo"), 20, Vector2(260, 54))
	_overlay_next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_overlay_next.visible = false
	_overlay_next.pressed.connect(GameManager.next_level)
	ccol.add_child(_overlay_next)
	var retry := UiTheme.button(UiTheme.say("Chơi lại màn này  (R)", "Chơi lại màn này"), 20, Vector2(260, 54))
	retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry.pressed.connect(GameManager.restart)
	ccol.add_child(retry)

	_build_menu(root)

# ----------------------------------------------------------------- signals

## `placed` and `total` are a percentage and 100 - see DominoTask3D._emit_progress
## for why the run is measured by distance bridged and not by pieces laid.
func _on_progress(placed: int, total: int) -> void:
	_task_total = total
	_progress_pct = placed

func _on_focus_changed(is_focus: bool) -> void:
	if is_focus:
		_mode_label.text = "TẬP TRUNG - khó thấy xung quanh"
		_mode_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5, 0.9))
	else:
		_mode_label.text = "QUAN SÁT"
		_mode_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.85))

func _on_notify(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)

func _on_failed(reason: String) -> void:
	_hint.visible = false
	_overlay_next.visible = false
	_overlay_title.text = "ĐỔ HẾT RỒI!"
	_overlay_title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_overlay_reason.text = reason
	if _last_failed_event and _last_failed_event.missed_signals_text != "":
		_overlay_reason.text += "\n\nDấu hiệu đã bỏ lỡ: " + _last_failed_event.missed_signals_text
	_overlay_stats.text = "Nối được %d%% đường  •  Thời gian %s" % [
		_progress_pct, GameManager.format_elapsed()]
	_overlay.visible = true

func _on_won() -> void:
	_hint.visible = false
	_overlay_next.visible = true
	_overlay_title.text = "HOÀN THÀNH!"
	_overlay_title.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6))
	_overlay_reason.text = "Dây domino chạy trọn đường và làm đổ quân ĐÍCH. Màn %d: %s." % [
		GameManager.level + 2, LevelSet.at(GameManager.level + 1)["name"]]
	_overlay_stats.text = "Trọn đường  •  Thời gian %s" % GameManager.format_elapsed()
	_overlay.visible = true

# ------------------------------------------------------------ level menu

## Escape opens and closes it. There is no other menu in the game, so there is
## nothing for Escape to be ambiguous about.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_ESCAPE:
		return
	# The same click the "Chọn màn" button makes - Escape is the shortcut for it,
	# so it should not be the silent way in.
	Sfx.play("ui", -9.0)
	if _menu.visible:
		_close_menu()
	else:
		_open_menu()
	get_viewport().set_input_as_handled()

## Built fresh each time it opens, because `reached` moves while the game runs
## and the list has to grow with it. Nothing here is locked - every row played.
func _open_menu() -> void:
	for old in _menu_rows.get_children():
		old.queue_free()
	# Every authored desk, everything the campaign has been taken to past them, and
	# one more so there is always a next desk to step onto. Unbounded, hence the
	# scroller.
	var rows := maxi(LevelSet.authored(), GameManager.reached + 1)
	# `level` can sit past `reached` when --autotest-level drops you straight onto a
	# generated desk, and a menu that cannot show the level you are standing on is
	# confusing in exactly the situation you opened it to get out of.
	rows = maxi(rows, GameManager.level + 1)
	for i in rows + 1:
		var lv := LevelSet.at(i)
		var mark := "  ← đang chơi" if i == GameManager.level else ""
		var row := UiTheme.button("Màn %d · %s%s" % [i + 1, lv["name"], mark],
			17, Vector2(320, 42))
		row.pressed.connect(func() -> void: GameManager.go_to_level(i))
		_menu_rows.add_child(row)
	_menu.visible = true
	get_tree().paused = true

func _close_menu() -> void:
	_menu.visible = false
	get_tree().paused = false

func _build_menu(root: Control) -> void:
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.visible = false
	root.add_child(_menu)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(centre)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",
		UiTheme.panel(Color(0.16, 0.11, 0.08, 0.98), UiTheme.GOLD, 18, 3))
	centre.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	col.add_child(UiTheme.label("CHỌN MÀN", 28, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	# Scrolled, because the level list has no end. Tall enough for eight rows,
	# which covers the authored campaign plus the first generated desks without
	# ever scrolling; past that the newest levels are the ones you want anyway, so
	# the list is left scrolled where it opens rather than jumped to the bottom.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(336, 392)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_menu_rows = VBoxContainer.new()
	_menu_rows.add_theme_constant_override("separation", 6)
	_menu_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_menu_rows)
	# The cheat used to be F2 and nothing else, which meant it did not exist on a
	# phone. It lives in the menu because the menu is the one surface reachable
	# from every device, and because a cheat that sat on the playfield would be
	# tapped by accident on a screen you place dominoes on with your finger.
	var cheat := UiTheme.button(UiTheme.say("Xếp sẵn cả dây  (F2)", "Xếp sẵn cả dây"),
		17, Vector2(320, 42))
	cheat.pressed.connect(_cheat_fill)
	col.add_child(cheat)
	var close := UiTheme.button(UiTheme.say("Đóng  (Esc)", "Đóng"), 17, Vector2(320, 42))
	close.pressed.connect(_close_menu)
	col.add_child(close)

## Duck-typed like the rest of the shared HUD: the 2D scene has no router, so the
## button simply says so there instead of the HUD needing to know which task it
## is sitting above.
func _cheat_fill() -> void:
	var task: Node = null
	for n in get_parent().get_children():
		if n.has_method("debug_fill_route"):
			task = n
			break
	if task == null:
		EventBus.notify.emit("Bàn này không có cheat.", Color(1, 0.85, 0.5))
		return
	# Close first: the menu pauses the tree, and the router lays real bodies that
	# need the physics step to settle. Deferred so the unpause has landed.
	_close_menu()
	task.debug_fill_route.call_deferred()
