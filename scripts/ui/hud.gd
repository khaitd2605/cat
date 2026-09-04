extends CanvasLayer
## Heads-up display: task panel, title tag, hint, toast notifications and the
## failure / win overlay. Layout is container-based so it scales with the
## viewport on Web.
##
## By design there is NO warning banner: the player has to notice the room
## (curtain, window, cat body language, sounds) on their own. The explicit
## WarningSystem still exists as an optional assist mode.

## Assist mode: show the explicit warning banner + action buttons.
@export var assist_banner := false

var _progress_bar: ProgressBar
var _progress_label: Label
var _hint: Label
var _toast: Label
var _overlay: Control
var _overlay_title: Label
var _overlay_reason: Label
var _overlay_stats: Label
var _toast_tween: Tween
var _task_total := 0
var _hint_task_label: Label
var _last_failed_event: EnvironmentalEvent
var _mode_label: Label

func _ready() -> void:
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

	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", UiTheme.panel(Color(0.9, 0.76, 0.38, 0.95), Color(0.6, 0.45, 0.2), 6, 2))
	tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tag.rotation_degrees = -2.5
	tag.add_child(UiTheme.label("VD: XẾP DOMINO", 18, Color(0.2, 0.13, 0.08)))
	top_row.add_child(tag)

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
	_hint_task_label = UiTheme.label("Xếp domino", 16, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	tcol.add_child(_hint_task_label)
	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0, 22)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.06, 0.05)
	bg.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.56, 0.75, 0.27)
	fill.set_corner_radius_all(8)
	_progress_bar.add_theme_stylebox_override("background", bg)
	_progress_bar.add_theme_stylebox_override("fill", fill)
	tcol.add_child(_progress_bar)
	_progress_label = UiTheme.label("0 / 0", 15, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_progress_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_progress_bar.add_child(_progress_label)
	var restart := UiTheme.button("Chơi lại (R)", 13, Vector2(0, 30))
	restart.pressed.connect(GameManager.restart)
	tcol.add_child(restart)

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

	_hint = UiTheme.label("Cầm domino từ khay, đưa đầu dưới vào vòng sáng, đợi hết lắc rồi thả  •  Giữ Shift / lăn chuột: nhìn gần  •  Giữ Space / chuột phải: che chắn", 15, Color(1, 0.95, 0.85, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
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
	var retry := UiTheme.button("Thử lại  (R)", 20, Vector2(220, 54))
	retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry.pressed.connect(GameManager.restart)
	ccol.add_child(retry)

# ----------------------------------------------------------------- signals

func _on_progress(placed: int, total: int) -> void:
	_task_total = total
	_hint_task_label.text = "Xếp %d quân tới ĐÍCH" % total
	_progress_bar.max_value = total
	_progress_bar.value = placed
	_progress_label.text = "%d / %d" % [placed, total]

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
	_overlay_title.text = "ĐỔ HẾT RỒI!"
	_overlay_title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_overlay_reason.text = reason
	if _last_failed_event and _last_failed_event.missed_signals_text != "":
		_overlay_reason.text += "\n\nDấu hiệu đã bỏ lỡ: " + _last_failed_event.missed_signals_text
	_overlay_stats.text = "Đã xếp %d / %d quân  •  Thời gian %s" % [int(_progress_bar.value), _task_total, GameManager.format_elapsed()]
	_overlay.visible = true

func _on_won() -> void:
	_hint.visible = false
	_overlay_title.text = "HOÀN THÀNH!"
	_overlay_title.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6))
	_overlay_reason.text = "Toàn bộ domino đã đứng vững. Gió và mèo đều không làm gì được bạn."
	_overlay_stats.text = "%d / %d quân  •  Thời gian %s" % [_task_total, _task_total, GameManager.format_elapsed()]
	_overlay.visible = true
