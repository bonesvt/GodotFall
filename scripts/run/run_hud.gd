extends CanvasLayer
## Run HUD: prompts, toasts, the salvage choice and the summary, and three of
## the screen's corners (the fight is hud.gd's, bottom left): top left who Eco's
## with (relations_label), top right what's got a hold on her (the pull clock,
## craving, dose cuff, Hymn, Keepsake; hidden when nothing has), bottom right the
## run status and titan build, small.
## The run manager writes the text; this only lays it out, in the HUD's look
## (hud_style.gd): the corners are cards, the prompt a dark pill with its key
## in a box, the titan build a card of rows. The titan reticle is drawn per
## weapon (see titan_gun.gd) so each gun reads differently.

const Style := preload("res://scripts/ui/hud_style.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const Velvet := preload("res://scripts/hub/velvet.gd")
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
## A cutscene has the screen: the corner cards stay out of it.
var corners_hidden := false
var crosshair: Control
## The piloted titan, set on embark; the reticle reads its gun.
var titan: Node
var choice_panel: PanelContainer
var choice_label: Label
var summary_panel: PanelContainer
var summary_label: Label
var _toast_time := 0.0
var _build_card := Style.card(Style.CYAN)
var _pill := StyleBoxFlat.new()
## A prompt's key: "[F] Embark" -> F.
var _key := RegEx.create_from_string("^\\[([^\\]]{1,6})\\]\\s*")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Bottom right, small: where she is, what she's carrying; the titan build above it on runs.
	status_label = _label(16)
	status_label.add_theme_font_override("font", Style.numbers(false, 1))
	status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	status_label.offset_left = -900
	status_label.offset_right = -20
	status_label.offset_top = -80
	status_label.offset_bottom = -20
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))

	build_label = _label(14)
	build_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	build_label.offset_left = -520
	build_label.offset_right = -20
	build_label.offset_top = -220
	build_label.offset_bottom = -84
	# its text stays the record ("TITAN BUILD", then "Slot: part" rows); what
	# shows is the card _draw_build makes of it
	build_label.add_theme_color_override("font_color", Color.TRANSPARENT)
	build_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	build_label.draw.connect(_draw_build)

	# The prompt draws itself as a pill with its key boxed (_draw_prompt).
	prompt_label = _centered(21, 40)  # clear of Eco's whisper caption below it
	prompt_label.add_theme_color_override("font_color", Color.TRANSPARENT)
	prompt_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	prompt_label.draw.connect(_draw_prompt)
	_pill.bg_color = Color(Style.CARD, 0.62)
	_pill.set_corner_radius_all(4)
	toast_label = _centered(28, -220)
	toast_label.add_theme_font_override("font", Style.saira(700))
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.draw.connect(_draw_toast_rule)
	fight_label = _centered(22, -170)
	fight_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	fight_label.offset_left = -500
	fight_label.offset_right = 500
	fight_label.offset_top = -200

	# Top right: what's got a hold on her (only when something has): Marrow's pull
	# or withdrawal clock (hush_pull.gd writes it), the craving bar, the dose
	# cuff's countdown, Hymn in her and its gear, Ophelia's Keepsake.
	var vices_box := _corner(Control.PRESET_TOP_RIGHT, Style.VIOLET)
	vices_panel = vices_box[0]
	var col: VBoxContainer = vices_box[1]
	col.add_child(_caption("HELD"))
	pull_label = _small("", 17, Style.VIOLET)
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
	word.add_theme_font_override("font", Style.saira(700, false, 2))
	word.add_theme_font_size_override("font_size", 11)
	word.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crave_bar.add_child(word)
	cuff_label = _small("", 15, Color(0.85, 0.95, 1.0))
	col.add_child(cuff_label)
	hymn_label = _small("", 15, Color(0.86, 0.91, 1.0))
	col.add_child(hymn_label)
	keepsake_label = _small("", 15, Style.PINK)
	col.add_child(keepsake_label)
	for l in [pull_label, crave_bar, cuff_label, hymn_label, keepsake_label]:
		l.visible = false

	# Top left: who she's with (run_manager.gd relations_text()).
	var rel_box := _corner(Control.PRESET_TOP_LEFT, Style.PINK)
	relations_panel = rel_box[0]
	(rel_box[1] as VBoxContainer).add_child(_caption("HEART"))
	relations_label = _small("", 15, Style.INK)
	(rel_box[1] as VBoxContainer).add_child(relations_label)
	relations_panel.visible = false
	# One of Marrow's trigger words, big, and the taps to shake it (trigger_words.gd).
	trigger_label = _centered(40, 150)
	trigger_label.offset_top = 80
	trigger_label.offset_bottom = 220
	trigger_label.add_theme_font_override("font", Style.saira(800))
	trigger_label.add_theme_color_override("font_color", Style.VIOLET)
	trigger_label.visible = false

	crosshair = Control.new()
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(_draw_reticle)
	crosshair.visible = false
	add_child(crosshair)

	choice_label = Style.style(Label.new(), 21, Style.INK, Style.saira(500))
	choice_panel = _panel(choice_label)
	summary_label = Style.style(Label.new(), 25)
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_panel = _panel(summary_label)


## A card in a corner of the screen (hud_style.gd), its accent along the top:
## [the panel, the column inside it].
func _corner(corner: int, accent: Color) -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Style.card(accent, 12.0))
	p.custom_minimum_size.x = 280
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_anchors_and_offsets_preset(corner)
	var right := corner == Control.PRESET_TOP_RIGHT
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	p.offset_left = -22 if right else 22
	p.offset_right = -22 if right else 22
	p.offset_top = 22
	add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(col)
	return [p, col]


func _small(text: String, size: int, col: Color) -> Label:
	var l := Style.style(Label.new(), size, col, Style.saira(500))
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A card's small spaced-out heading.
func _caption(text: String) -> Label:
	var l := _small(text, 11, Color(1, 1, 1, 0.75))
	l.add_theme_font_override("font", Style.saira(700, false, 2))
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
	var crave := maxf(maxf(Vices.crave_level(), Obsession.crave), Velvet.crave())
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
	relations_panel.visible = relations_label.text != "" and not corners_hidden
	vices_panel.visible = visible and not corners_hidden and (pull_label.visible or crave_bar.visible or cuff_label.visible or hymn_label.visible or keepsake_label.visible)
	if crosshair.visible:
		crosshair.queue_redraw()


func _label(size: int) -> Label:
	var l := Style.style(Label.new(), size)
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
	var style := Style.card(Style.YELLOW, 24.0)
	style.bg_color = Color(Style.CARD, 0.92)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(content)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.visible = false
	add_child(panel)
	return panel


## The prompt: a dark pill, the key boxed at its left ("[F] Embark").
func _draw_prompt() -> void:
	var t := prompt_label.text
	if t == "":
		return
	var k := ""
	var m := _key.search(t)
	if m != null:
		k = m.get_string(1)
		t = t.substr(m.get_end())
	var f := Style.saira(600)
	var size := 21
	var key_w := 0.0 if k == "" else maxf(Style.width(Style.saira(700), k, 15) + 12.0, 25.0) + 10.0
	var w := key_w + Style.width(f, t, size) + 40.0
	var c := prompt_label.size * 0.5
	var r := Rect2(c.x - w * 0.5, c.y - 20.0, w, 40.0)
	prompt_label.draw_style_box(_pill, r)
	var x := r.position.x + 20.0
	if k != "":
		x += Style.key(prompt_label, Vector2(x, c.y), k, 15) + 10.0
	Style.text(prompt_label, f, Vector2(x, c.y + size * 0.36), t, size)


## A thin rule under the toast that fades out at both ends.
func _draw_toast_rule() -> void:
	var f := toast_label.get_theme_font("font")
	var size := toast_label.get_theme_font_size("font_size")
	var lines := toast_label.get_line_count()
	var c := toast_label.size * 0.5
	var y := c.y + lines * (f.get_height(size) + toast_label.get_theme_constant("line_spacing")) * 0.5 + 6.0
	var w := 420.0 if lines > 1 else minf(Style.width(f, toast_label.text, size) + 60.0, 420.0)
	var clear := Color(1, 1, 1, 0.0)
	toast_label.draw_polyline_colors(PackedVector2Array([Vector2(c.x - w * 0.5, y), Vector2(c.x, y), Vector2(c.x + w * 0.5, y)]),
		PackedColorArray([clear, Color(1, 1, 1, 0.85), clear]), 2.0)


## The titan build, bottom right, from build_label's text: a card with the
## heading, then each slot and its part (dim while it's still the scrap one).
func _draw_build() -> void:
	var rows := build_label.text.split("\n", false)
	if rows.is_empty():
		return
	var w := 320.0
	var row_h := 21.0
	var h := Style.BAR + 34.0 + (rows.size() - 1) * row_h + 4.0
	var r := Rect2(build_label.size.x - w, build_label.size.y - h, w, h)
	build_label.draw_style_box(_build_card, r)
	var x := r.position.x + 16.0
	var y := r.position.y + Style.BAR + 20.0
	Style.text(build_label, Style.saira(700, false, 2), Vector2(x, y), rows[0], 11, Color(1, 1, 1, 0.75))
	var f := Style.saira(500)
	var b := Style.saira(600)
	for i in range(1, rows.size()):
		y += row_h
		var parts := rows[i].split(": ", true, 1)
		Style.text(build_label, f, Vector2(x, y), parts[0], 14)
		if parts.size() > 1:
			var stock := parts[1].ends_with("(scrap)")
			Style.text(build_label, b, Vector2(x, y), parts[1], 14, Style.DIM if stock else Style.CYAN, HORIZONTAL_ALIGNMENT_RIGHT, w - 32.0)


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
				var font := Style.saira(700)
				crosshair.draw_string(font, c + Vector2(-26, 44), "JAMMED", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.3, 0.2))
	# Hitmarker when a round lands on the enemy titan.
	if gun.since_hit < 0.12:
		var a: float = 1.0 - gun.since_hit / 0.12
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			crosshair.draw_line(c + d * 9.0, c + d * 17.0, Color(1, 1, 1, a), 3.0)
