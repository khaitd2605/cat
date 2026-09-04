class_name UiTheme
extends RefCounted
## Tiny helpers so every panel/button in the HUD shares the same warm look.

const PANEL_BG := Color(0.16, 0.11, 0.08, 0.92)
const PANEL_BORDER := Color(0.45, 0.35, 0.25)
const GOLD := Color(0.93, 0.78, 0.4)
const CREAM := Color(0.96, 0.92, 0.85)
const DANGER := Color(0.9, 0.3, 0.25)

static func panel(bg := PANEL_BG, border := PANEL_BORDER, radius := 12, border_w := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(14)
	return sb

static func label(text: String, size: int, color := CREAM, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func button(text: String, size := 18, min_size := Vector2(150, 48)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_stylebox_override("normal", panel(Color(0.3, 0.22, 0.17, 0.95), PANEL_BORDER, 10))
	b.add_theme_stylebox_override("hover", panel(Color(0.42, 0.31, 0.22, 0.98), GOLD, 10))
	b.add_theme_stylebox_override("pressed", panel(Color(0.22, 0.16, 0.12, 1.0), GOLD, 10))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Here rather than at each call site, so a button added later cannot be the one
	# silent button in the game. Quiet: it is confirmation, not an event.
	b.pressed.connect(func() -> void: Sfx.play("ui", -9.0))
	return b
