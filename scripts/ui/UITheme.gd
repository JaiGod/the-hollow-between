extends RefCounted
## One theme for every menu: square pixel panels, high-contrast text.

const BG := Color("0b0716")
const PANEL := Color("140d26")
const BORDER := Color("e8e0ff")
const ACCENT := Color("c0a0ff")
const GOLD := Color("ffe08a")
const DIM := Color("8a80a8")
const DANGER := Color("ff6a7a")
const GOOD := Color("9fe0c0")

static var _theme: Theme


static func panel_style(border: Color = BORDER, bg: Color = PANEL, width: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(0)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 16
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("default_color", "RichTextLabel", Color.WHITE)
	var btn := panel_style(DIM, Color("1c1434"), 2)
	var btn_hover := panel_style(GOLD, Color("2a1e4a"), 2)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("focus", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", panel_style(ACCENT, Color("3a2a6a"), 2))
	t.set_stylebox("disabled", "Button", panel_style(Color("3a3050"), Color("120c20"), 2))
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color("5a5070"))
	t.set_stylebox("normal", "LineEdit", panel_style(ACCENT, Color("1c1434"), 2))
	t.set_stylebox("focus", "LineEdit", panel_style(GOLD, Color("1c1434"), 2))
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("2a1e3a")
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = GOOD
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_stylebox("slider", "HSlider", bar_bg)
	_theme = t
	return t


static func label(text: String, size: int = 16, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
