extends CanvasLayer
## Run HUD: run status, titan build, prompts, the salvage choice and the summary.
## The run manager writes the text; this only lays it out. The titan reticle
## is drawn per weapon (see titan_gun.gd) so each gun reads differently.

const Vices := preload("res://scripts/hub/vices.gd")

var status_label: Label
var build_label: Label
var prompt_label: Label
var toast_label: Label
var fight_label: Label
var pull_label: Label
var crave_bar: Control
var trigger_label: Label
var _crave_fill: ColorRect
var crosshair: Control
## The piloted titan, set on embark; the reticle reads its gun.
var titan: Node
var choice_panel: PanelContainer
var choice_label: Label
var summary_panel: PanelContainer
var summary_label: Label
var _toast_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	status_label = _label(20)
	status_label.position = Vector2(20, 270)  # under the controls help (hud.gd)

	build_label = _label(18)
	build_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build_label.offset_left = -520
	build_label.offset_right = -20
	build_label.offset_top = 20

	prompt_label = _centered(26, 60)
	toast_label = _centered(30, -220)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fight_label = _centered(24, -170)
	fight_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	fight_label.offset_left = -500
	fight_label.offset_right = 500
	fight_label.offset_top = -200

	# Marrow's pull / withdrawal clock at full Hold (hush_pull.gd writes it).
	pull_label = _label(24)
	pull_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	pull_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pull_label.offset_left = -300
	pull_label.offset_right = 300
	pull_label.offset_top = 16
	pull_label.add_theme_color_override("font_color", Color(0.82, 0.55, 1.0))
	pull_label.visible = false

	# How bad the craving is (Vices.crave_level()), a bar under the clock.
	crave_bar = Control.new()
	crave_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	crave_bar.offset_left = -130
	crave_bar.offset_right = 130
	crave_bar.offset_top = 52
	crave_bar.offset_bottom = 74
	crave_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crave_bar.visible = false
	add_child(crave_bar)
	var back := ColorRect.new()
	back.color = Color(0.06, 0.02, 0.1, 0.75)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crave_bar.add_child(back)
	_crave_fill = ColorRect.new()
	_crave_fill.color = Color(0.7, 0.3, 1.0)
	_crave_fill.position = Vector2(2, 2)
	crave_bar.add_child(_crave_fill)
	var word := Label.new()
	word.text = "CRAVING"
	word.add_theme_font_size_override("font_size", 14)
	word.add_theme_color_override("font_outline_color", Color.BLACK)
	word.add_theme_constant_override("outline_size", 4)
	word.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crave_bar.add_child(word)

	# One of Marrow's trigger words, big, and the taps to shake it (trigger_words.gd).
	trigger_label = _centered(40, 150)
	trigger_label.offset_top = 80
	trigger_label.offset_bottom = 220
	trigger_label.add_theme_color_override("font_color", Color(0.85, 0.6, 1.0))
	trigger_label.add_theme_constant_override("outline_size", 10)
	trigger_label.visible = false

	crosshair = Control.new()
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(_draw_reticle)
	crosshair.visible = false
	add_child(crosshair)

	choice_label = Label.new()
	choice_label.add_theme_font_size_override("font_size", 22)
	choice_panel = _panel(choice_label)
	summary_label = Label.new()
	summary_label.add_theme_font_size_override("font_size", 26)
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_panel = _panel(summary_label)


func toast(text: String, seconds := 2.5) -> void:
	toast_label.text = text
	_toast_time = seconds


func _process(delta: float) -> void:
	_toast_time -= delta
	toast_label.visible = _toast_time > 0.0
	var crave := Vices.crave_level()
	crave_bar.visible = crave > 0.01
	if crave_bar.visible:
		_crave_fill.size = Vector2((crave_bar.size.x - 4.0) * crave, crave_bar.size.y - 4.0)
		# it throbs once it's bad
		_crave_fill.color.a = 1.0 if crave < 0.6 else 0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.8)
	if crosshair.visible:
		crosshair.queue_redraw()


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func _centered(size: int, y: float) -> Label:
	var l := _label(size)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.offset_left = -500
	l.offset_right = 500
	l.offset_top = y - 20
	l.offset_bottom = y + 20
	return l


func _panel(content: Label) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.88)
	style.border_color = Color(1.0, 0.75, 0.2)
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(content)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.visible = false
	add_child(panel)
	return panel


func _draw_reticle() -> void:
	var c := crosshair.size * 0.5
	if titan == null or not is_instance_valid(titan) or titan.gun == null:
		crosshair.draw_circle(c, 2.0, Color.WHITE)
		return
	var gun = titan.gun
	var col := Color(1.0, 0.85, 0.45, 0.9)
	var t := Time.get_ticks_msec() / 1000.0
	match gun.id:
		"xo16":
			# Ring tightens as the barrels spin up; three ticks spin with them.
			var r: float = lerpf(44.0, 24.0, gun.spin)
			crosshair.draw_arc(c, r, 0.0, TAU, 40, Color(col, 0.5), 2.0)
			var turn: float = t * (1.0 + gun.spin * 14.0)
			for i in 3:
				var a := turn + TAU * i / 3.0
				var d := Vector2(cos(a), sin(a))
				crosshair.draw_line(c + d * (r - 6.0), c + d * (r + 8.0), col, 3.0)
		"tracker":
			# Heavy brackets; a bar under them refills until the next shell.
			var s := 30.0
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var k: Vector2 = c + corner * s
				crosshair.draw_line(k, k - Vector2(corner.x * 12.0, 0), col, 3.0)
				crosshair.draw_line(k, k - Vector2(0, corner.y * 12.0), col, 3.0)
			var ready: float = 1.0 - clampf(gun.cooldown / gun.interval(), 0.0, 1.0)
			crosshair.draw_rect(Rect2(c + Vector2(-s, s + 10.0), Vector2(s * 2.0 * ready, 4.0)), col)
			crosshair.draw_line(c + Vector2(-6, 6), c, col, 2.0)
			crosshair.draw_line(c, c + Vector2(6, 6), col, 2.0)
		"splitter":
			# Two prongs close in and the meter heats up as the ramp builds.
			var ramp_max := maxf(float(titan.stats.get("ramp", 0.0)), 0.01)
			var heat: float = clampf(titan.ramp_bonus / ramp_max, 0.0, 1.0)
			var hot := Color(0.35, 0.9, 1.0).lerp(Color(1.0, 0.35, 0.75), heat)
			var gap := lerpf(34.0, 12.0, heat)
			for side in [-1.0, 1.0]:
				crosshair.draw_line(c + Vector2(side * gap, -14), c + Vector2(side * gap, 14), hot, 3.0)
			crosshair.draw_arc(c, 46.0, PI * 0.75, PI * 0.75 + PI * 1.5 * heat, 24, hot, 4.0)
			crosshair.draw_circle(c, 2.0, hot)
		_:
			# Taped-together scrap sight: crooked, uneven, and it complains.
			var tilt: float = 0.06 + (sin(t * 37.0) * 0.08 if gun.jammed() else 0.0)
			var arms := [Vector2(0, -16), Vector2(19, 0), Vector2(0, 13), Vector2(-17, 0)]
			for d in arms:
				var e: Vector2 = d.rotated(tilt)
				crosshair.draw_line(c + e * 0.35, c + e, col, 3.0)
			crosshair.draw_rect(Rect2(c + Vector2(9, -3).rotated(tilt), Vector2(6, 6)), Color(0.75, 0.7, 0.55, 0.8))
			if gun.jammed() and fmod(t, 0.3) < 0.18:
				var font := ThemeDB.fallback_font
				crosshair.draw_string(font, c + Vector2(-26, 44), "JAMMED", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.3, 0.2))
	# Hitmarker when a round lands on the enemy titan.
	if gun.since_hit < 0.12:
		var a: float = 1.0 - gun.since_hit / 0.12
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			crosshair.draw_line(c + d * 9.0, c + d * 17.0, Color(1, 1, 1, a), 3.0)
