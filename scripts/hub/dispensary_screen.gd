extends CanvasLayer
## The colony dispensary on Lantern Row (hymn.gd), opened like a workbench
## (pausing the hub), closed on F or Esc.
##   1   take the dose
##   2   palm it: a marker sweeps the bar; press Space (or 2 again) while it's
##       in the slice where the officer's looking away
##   3   refuse
## A missed palm or a refusal closes the screen and the Shepherd comes
## (run_manager.gd close_bench reads `hunt`).

const Hymn := preload("res://scripts/hub/hymn.gd")
const SFX := preload("res://scripts/sfx.gd")

const WHITE := Color(0.92, 0.95, 1.0)
const DIM := Color(0.92, 0.95, 1.0, 0.55)
const GREEN := Color(0.5, 1.0, 0.6)
const RED := Color(1.0, 0.4, 0.35)
## Seconds for the marker to cross the bar.
const SWEEP := 1.4

const OFFICER := [
	"Officer: \"Citizen. Your dose. Swallow it where I can see you.\"",
	"Officer: \"Morning, Eco. Hymn keeps you calm. Calm keeps you safe.\"",
	"Officer: \"Hand out, eyes on me. Good.\"",
]
const TOOK := "Eco swallows it. A clean white hush fills her head, like snow. Everything's fine. Everything's fine."
const PALMED := "The officer turns to the next citizen. Eco's fist is shut round the pill. It goes in the gutter on the way out."
const CAUGHT := "Officer: \"Open your hand.\" She runs. Behind her, something tall unfolds from the dispensary's back door."
const REFUSED := "Eco: \"No.\" The officer just nods and taps her earpiece. \"Shepherd. Lantern Row.\""
const DONE := "Officer: \"You've had today's, citizen. Come back after your next shift.\""

var kind := "dispensary"
var unlocked: Array = []
var close_now := false
## How it went, for the toast after: "", "took", "palmed", "caught", "refused".
var result := ""
## The Shepherd's coming.
var hunt := false

var _status: Label
var _bar: Control
var _palming := false
var _t := 0.0
var _at := 0.0
var _start := 0.3
var _close_in := -1.0


func _init() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_start = Hymn.window_start(Time.get_ticks_msec())
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.06, 0.08, 0.72)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.9, 0.92, 0.95, 0.97)
	box.border_color = Color(0.55, 0.62, 0.72)
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", box)
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size = Vector2(600, 0)
	screen.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var ink := Color(0.12, 0.14, 0.18)
	col.add_child(_text("COLONY DISPENSARY  -  HYMN", 28, ink))
	col.add_child(_text("Hymn in her: %d%%   Gear: %s" % [roundi(Hymn.level), ", ".join(Hymn.gear.map(func(g): return Hymn.GEAR_NAMES[g])) if not Hymn.gear.is_empty() else "none"], 15, Color(ink, 0.6)))
	_status = _text(DONE if Hymn.dosed_today else OFFICER[Hymn.captures % OFFICER.size()], 17, ink)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(550, 0)
	col.add_child(_status)
	if not Hymn.dosed_today:
		col.add_child(_text("1   Take the dose", 18, ink))
		col.add_child(_text("2   Palm it (Space when the officer looks away)", 18, ink))
		col.add_child(_text("3   Refuse", 18, ink))
		_bar = Control.new()
		_bar.custom_minimum_size = Vector2(550, 34)
		_bar.draw.connect(_draw_bar)
		_bar.visible = false
		col.add_child(_bar)
	col.add_child(_text("F or Esc leave", 14, Color(ink, 0.5)))


func _process(delta: float) -> void:
	if _close_in >= 0.0:
		_close_in -= delta
		if _close_in < 0.0:
			close_now = true
		return
	if _palming:
		_t += delta
		_at = pingpong(_t / SWEEP, 1.0)
		_bar.queue_redraw()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or _close_in >= 0.0 or Hymn.dosed_today:
		return
	match event.keycode:
		KEY_1, KEY_KP_1:
			if not _palming:
				take()
		KEY_2, KEY_KP_2, KEY_SPACE:
			if _palming:
				palm_now()
			elif event.keycode != KEY_SPACE:
				start_palm()
		KEY_3, KEY_KP_3:
			if not _palming:
				refuse()
		_:
			return
	get_viewport().set_input_as_handled()


func take() -> void:
	Hymn.take_dose()
	_finish("took", TOOK, false)


func start_palm() -> void:
	_palming = true
	_t = 0.0
	_bar.visible = true


## Palms it where the marker is now.
func palm_now() -> void:
	_palming = false
	if Hymn.palm(_at, _start):
		_finish("palmed", PALMED, false)
	else:
		_finish("caught", CAUGHT, true)


func refuse() -> void:
	Hymn.refuse()
	_finish("refused", REFUSED, true)


func _finish(how: String, line: String, hunted: bool) -> void:
	result = how
	hunt = hunted
	_status.text = line
	_status.add_theme_color_override("font_color", RED if hunted else Color(0.12, 0.14, 0.18))
	SFX.play(self, "ui_error" if hunted else "ui_confirm", -6.0)
	_close_in = 1.6


func _draw_bar() -> void:
	var w := _bar.size.x
	var h := _bar.size.y
	_bar.draw_rect(Rect2(0, 8, w, h - 16), Color(0.2, 0.22, 0.26))
	_bar.draw_rect(Rect2(w * _start, 8, w * Hymn.window(), h - 16), GREEN)
	_bar.draw_rect(Rect2(w * _at - 3, 0, 6, h), RED if not (_at >= _start and _at <= _start + Hymn.window()) else Color.WHITE)


func _text(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
