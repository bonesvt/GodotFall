extends CanvasLayer
## Run HUD: prompts, toasts, the salvage choice and the summary, and three of
## the screen's corners (the fight is hud.gd's, bottom left): top left who Eco's
## with (relations_label), top right what's got a hold on her (the pull clock,
## craving, dose cuff, Hymn, Keepsake; hidden when nothing has), bottom right the
## run status and titan build, small.
## The run manager writes the text; this only lays it out. The titan reticle
## is drawn per weapon (see titan_gun.gd) so each gun reads differently.

const Vices := preload("res://scripts/hub/vices.gd")
const Obsession := preload("res://scripts/hub/obsession.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")

var status_label: Label
var build_label: Label
var prompt_label: Label
var toast_label: Label
var fight_label: Label
var pull_label: Label
var crave_bar: Control
var trigger_label: Label
var cuff_label: Label
var _crave_fill: ColorRect
var vices_panel: PanelContainer
var hymn_label: Label
var keepsake_label: Label
var relations_panel: PanelContainer
var relations_label: Label
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
	# Bottom right, small: where she is, what she's carrying; the titan build above it on runs.
	status_label = _label(14)
	status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	status_label.offset_left = -900
	status_label.offset_right = -20
	status_label.offset_top = -80
	status_label.offset_bottom = -20
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.98, 0.75))

	build_label = _label(14)
	build_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	build_label.offset_left = -520
	build_label.offset_right = -20
	build_label.offset_top = -220
	build_label.offset_bottom = -84
	build_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.98, 0.75))

	prompt_label = _centered(26, 60)
	toast_label = _centered(30, -220)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fight_label = _centered(24, -170)
	fight_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	fight_label.offset_left = -500
	fight_label.offset_right = 500
	fight_label.offset_top = -200

	# Top right: what's got a hold on her (only when something has): Marrow's pull
	# or withdrawal clock (hush_pull.gd writes it), the craving bar, the dose
	# cuff's countdown, Hymn in her and its gear, Ophelia's Keepsake.
	var vices_box := _corner(Control.PRESET_TOP_RIGHT, Color(0.72, 0.5, 1.0))
	vices_panel = vices_box[0]
	var col: VBoxContainer = vices_box[1]
	col.add_child(_small("HELD", 12, Color(0.85, 0.75, 1.0, 0.6)))
	pull_label = _small("", 17, Color(0.82, 0.6, 1.0))
	col.add_child(pull_label)
	crave_bar = Control.new()
	crave_bar.custom_minimum_size = Vector2(260, 16)
	crave_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(crave_bar)
	var back := ColorRect.new()
	back.color = Color(1, 1, 1, 0.08)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crave_bar.add_child(back)
	_crave_fill = ColorRect.new()
	_crave_fill.color = Color(0.7, 0.3, 1.0)
	crave_bar.add_child(_crave_fill)
	var word := Label.new()
	word.text = "CRAVING"
	word.add_theme_font_size_override("font_size", 11)
	word.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crave_bar.add_child(word)
	cuff_label = _small("", 15, Color(0.85, 0.95, 1.0))
	col.add_child(cuff_label)
	hymn_label = _small("", 15, Color(0.88, 0.94, 1.0))
	col.add_child(hymn_label)
	keepsake_label = _small("", 15, Color(1.0, 0.6, 0.75))
	col.add_child(keepsake_label)
	for l in [pull_label, crave_bar, cuff_label, hymn_label, keepsake_label]:
		l.visible = false

	# Top left: who she's with (run_manager.gd relations_text()).
	var rel_box := _corner(Control.PRESET_TOP_LEFT, Color(1.0, 0.6, 0.75))
	relations_panel = rel_box[0]
	(rel_box[1] as VBoxContainer).add_child(_small("HEART", 12, Color(1.0, 0.8, 0.85, 0.6)))
	relations_label = _small("", 15, Color(0.95, 0.93, 0.95))
	(rel_box[1] as VBoxContainer).add_child(relations_label)
	relations_panel.visible = false
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


## A dark rounded card in a corner of the screen, with a thin accent line on top:
## [the panel, the column inside it].
func _corner(corner: int, accent: Color) -> Array:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.06, 0.08, 0.62)
	box.border_color = Color(accent, 0.55)
	box.border_width_top = 2
	box.set_corner_radius_all(10)
	box.set_content_margin_all(12)
	box.content_margin_left = 16
	box.content_margin_right = 16
	p.add_theme_stylebox_override("panel", box)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_anchors_and_offsets_preset(corner)
	var right := corner == Control.PRESET_TOP_RIGHT
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	p.offset_left = -20 if right else 20
	p.offset_right = -20 if right else 20
	p.offset_top = 20
	add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(col)
	return [p, col]


func _small(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Who she's with, for the top left card ("" hides it).
func set_relations(text: String) -> void:
	relations_label.text = text
	relations_panel.visible = text != ""


func toast(text: String, seconds := 2.5) -> void:
	toast_label.text = text
	_toast_time = seconds


func _process(delta: float) -> void:
	_toast_time -= delta
	toast_label.visible = _toast_time > 0.0
	var crave := maxf(Vices.crave_level(), Obsession.crave)
	crave_bar.visible = crave > 0.01
	if crave_bar.visible:
		_crave_fill.size = Vector2(crave_bar.size.x * crave, crave_bar.size.y)
		# it throbs once it's bad
		_crave_fill.color = Color(0.95, 0.35, 0.6) if Obsession.crave > Vices.crave_level() else Color(0.7, 0.3, 1.0)
		_crave_fill.color.a = 1.0 if crave < 0.6 else 0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.8)
	# Hymn in her and the gear on her; Ophelia's Keepsake
	hymn_label.visible = Hymn.allowed() and (Hymn.level > 0.0 or not Hymn.gear.is_empty() or Hymn.hunted)
	if hymn_label.visible:
		var t := "HYMN  %d%%" % roundi(Hymn.level)
		if not Hymn.gear.is_empty():
			t += "   gear %d/%d" % [Hymn.gear.size(), Hymn.GEAR.size()]
		if Hymn.hunted:
			t += "   HUNTED"
		hymn_label.text = t
	keepsake_label.visible = Obsession.allowed() and Obsession.keepsake > 0.0
	if keepsake_label.visible:
		keepsake_label.text = "KEEPSAKE  %d%%" % roundi(Obsession.keepsake) + ("   pull home %d%%" % roundi(Obsession.crave * 100.0) if Obsession.crave > 0.01 else "")
	vices_panel.visible = visible and (pull_label.visible or crave_bar.visible or cuff_label.visible or hymn_label.visible or keepsake_label.visible)
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
