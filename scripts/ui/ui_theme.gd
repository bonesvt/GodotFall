extends RefCounted
## The look of the menus (title, pause, settings): dark glass panels, amber
## accents like the tutorial cards, and a condensed sans font (Bahnschrift on
## Windows, falling back to whatever the system has).

const AMBER := Color(1.0, 0.78, 0.25)
const AMBER_DIM := Color(1.0, 0.78, 0.25, 0.35)
const TEXT := Color(0.93, 0.92, 0.88)
const MUTED := Color(0.62, 0.62, 0.6)
const PANEL := Color(0.05, 0.06, 0.07, 0.86)
const FIELD := Color(0.12, 0.13, 0.14, 0.95)

static var _theme: Theme


static func font(bold := false) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Bahnschrift", "DIN Alternate", "Roboto Condensed", "Arial Narrow", "Helvetica Neue", "Arial", "Sans-Serif"])
	f.font_weight = 700 if bold else 400
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)

	var flat := _box(Color(0, 0, 0, 0), 0, Color.TRANSPARENT)
	var hover := _box(Color(1.0, 0.78, 0.25, 0.14), 0, AMBER)
	hover.border_width_left = 4
	var pressed := _box(Color(1.0, 0.78, 0.25, 0.28), 0, AMBER)
	pressed.border_width_left = 4
	for kind in ["normal", "disabled"]:
		t.set_stylebox(kind, "Button", flat)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", AMBER)
	t.set_color("font_focus_color", "Button", AMBER)
	t.set_color("font_pressed_color", "Button", AMBER)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.45))
	t.set_font_size("font_size", "Button", 26)

	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 6, AMBER_DIM))
	t.set_stylebox("panel", "Panel", _box(PANEL, 6, AMBER_DIM))

	# Option buttons, checkboxes and key buttons inside settings rows.
	var field := _box(FIELD, 4, Color(1, 1, 1, 0.12))
	var field_hover := _box(FIELD.lightened(0.08), 4, AMBER)
	for cls in ["OptionButton", "CheckButton"]:
		t.set_stylebox("normal", cls, field)
		t.set_stylebox("hover", cls, field_hover)
		t.set_stylebox("focus", cls, field_hover)
		t.set_stylebox("pressed", cls, field_hover)
		t.set_font_size("font_size", cls, 20)
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, AMBER)
	t.set_stylebox("panel", "PopupMenu", _box(Color(0.08, 0.09, 0.1, 0.98), 4, AMBER_DIM))
	t.set_font_size("font_size", "PopupMenu", 20)
	t.set_color("font_hover_color", "PopupMenu", AMBER)
	t.set_stylebox("hover", "PopupMenu", _box(Color(1.0, 0.78, 0.25, 0.18), 2, Color.TRANSPARENT))

	# Sliders: a thin track, amber fill, a square grabber.
	var track := _box(Color(1, 1, 1, 0.14), 2, Color.TRANSPARENT)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := _box(AMBER, 2, Color.TRANSPARENT)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := Image.create(14, 22, false, Image.FORMAT_RGBA8)
	grab.fill(TEXT)
	var grab_hi := Image.create(14, 22, false, Image.FORMAT_RGBA8)
	grab_hi.fill(AMBER)
	t.set_icon("grabber", "HSlider", ImageTexture.create_from_image(grab))
	t.set_icon("grabber_highlight", "HSlider", ImageTexture.create_from_image(grab_hi))

	# Tabs along the top of the settings.
	var tab := _box(Color(0, 0, 0, 0), 0, Color.TRANSPARENT)
	tab.content_margin_left = 18
	tab.content_margin_right = 18
	tab.content_margin_top = 8
	tab.content_margin_bottom = 8
	var tab_on := tab.duplicate() as StyleBoxFlat
	tab_on.border_color = AMBER
	tab_on.border_width_bottom = 3
	tab_on.bg_color = Color(1.0, 0.78, 0.25, 0.1)
	t.set_stylebox("tab_unselected", "TabBar", tab)
	t.set_stylebox("tab_hovered", "TabBar", tab)
	t.set_stylebox("tab_selected", "TabBar", tab_on)
	t.set_stylebox("tab_focus", "TabBar", tab_on)
	t.set_color("font_unselected_color", "TabBar", MUTED)
	t.set_color("font_hovered_color", "TabBar", TEXT)
	t.set_color("font_selected_color", "TabBar", AMBER)
	t.set_font_size("font_size", "TabBar", 22)
	t.set_stylebox("panel", "TabContainer", _box(Color(0, 0, 0, 0), 0, Color.TRANSPARENT))
	t.set_stylebox("tabbar_background", "TabContainer", _box(Color(0, 0, 0, 0), 0, Color.TRANSPARENT))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	_theme = t
	return t


static func _box(bg: Color, radius: int, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(1)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


## A big label for headings.
static func heading(text: String, size := 40) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(true))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", AMBER)
	return l


static func label(text: String, size := 22, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(on_press)
	return b


## Focuses a control next frame (for keyboard and pad navigation), if it's
## still on screen by then.
static func focus(c: Control) -> void:
	var grab := func() -> void:
		if is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree():
			c.grab_focus()
	grab.call_deferred()
