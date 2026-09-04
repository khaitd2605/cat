class_name WarningSystem
extends VBoxContainer
## Presents the active EnvironmentalEvent to the player: what is happening,
## how long until it hits, and the actions available. Built entirely in code.
## It only *reads* the event and calls the callables the event exposes.

var _event: EnvironmentalEvent
var _banner: PanelContainer
var _icon: WarningIcon
var _title: Label
var _stage: Label
var _time: Label
var _bar: ProgressBar
var _actions_panel: PanelContainer
var _actions_box: HBoxContainer
var _banner_style: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override("separation", 10)
	_build()
	visible = false
	EventBus.warning_started.connect(_on_started)
	EventBus.warning_stage_changed.connect(_on_stage)
	EventBus.warning_ended.connect(_on_ended)

func _build() -> void:
	_banner = PanelContainer.new()
	_banner_style = UiTheme.panel(Color(0.2, 0.08, 0.06, 0.94), UiTheme.DANGER, 14)
	_banner.add_theme_stylebox_override("panel", _banner_style)
	_banner.custom_minimum_size = Vector2(620, 0)
	add_child(_banner)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_banner.add_child(row)
	_icon = WarningIcon.new()
	row.add_child(_icon)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)
	_title = UiTheme.label("CẢNH BÁO", 22, Color(1.0, 0.45, 0.4))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	_time = UiTheme.label("0.0s", 22, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
	top.add_child(_time)

	_stage = UiTheme.label("", 16, UiTheme.CREAM)
	col.add_child(_stage)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.min_value = 0
	_bar.max_value = 1
	_bar.custom_minimum_size = Vector2(0, 10)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.05, 0.04)
	bg.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.DANGER
	fill.set_corner_radius_all(5)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)
	col.add_child(_bar)

	_actions_panel = PanelContainer.new()
	_actions_panel.add_theme_stylebox_override("panel", UiTheme.panel(Color(0.12, 0.09, 0.07, 0.94), UiTheme.PANEL_BORDER, 16))
	_actions_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_actions_panel)
	var acol := VBoxContainer.new()
	acol.add_theme_constant_override("separation", 10)
	_actions_panel.add_child(acol)
	acol.add_child(UiTheme.label("CHỌN HÀNH ĐỘNG", 18, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	_actions_box = HBoxContainer.new()
	_actions_box.add_theme_constant_override("separation", 14)
	_actions_box.alignment = BoxContainer.ALIGNMENT_CENTER
	acol.add_child(_actions_box)

# ----------------------------------------------------------------- events

func _on_started(event: EnvironmentalEvent) -> void:
	_event = event
	_icon.kind = event.icon_kind
	_title.text = "CẢNH BÁO: %s" % event.warning_title
	_rebuild_actions()
	_actions_panel.visible = true
	visible = true
	_refresh()

func _on_stage(event: EnvironmentalEvent, _index: int, text: String) -> void:
	if event != _event:
		return
	_stage.text = text
	_refresh()

func _on_ended(event: EnvironmentalEvent, _resolved: bool) -> void:
	if event != _event:
		return
	_event = null
	visible = false

func _rebuild_actions() -> void:
	for c in _actions_box.get_children():
		c.queue_free()
	for action in _event.get_actions():
		var b := UiTheme.button("%s\n%s" % [action["label"], action["hint"]], 17, Vector2(170, 92))
		var id: String = action["id"]
		var callable: Callable = action["callable"]
		b.pressed.connect(func():
			if id == EnvironmentalEvent.ACTION_IGNORE:
				_actions_panel.visible = false
				EventBus.notify.emit("Tiếp tục xếp... mắt vẫn phải để ý xung quanh!", Color(1.0, 0.8, 0.4))
			elif callable.is_valid():
				callable.call()
		)
		_actions_box.add_child(b)

func _process(_delta: float) -> void:
	if _event and visible:
		_refresh()

func _refresh() -> void:
	if not _event:
		return
	var left := _event.get_time_left()
	_time.text = "%.1fs" % left
	_bar.value = _event.get_danger()
	var danger := _event.get_danger()
	var col := Color(1.0, 0.75, 0.3).lerp(UiTheme.DANGER, danger)
	if danger > 0.66:
		col = col.lerp(Color.WHITE, 0.4 + 0.4 * sin(Time.get_ticks_msec() / 90.0))
	_icon.color = col
	_banner_style.border_color = col
	_title.add_theme_color_override("font_color", col)
