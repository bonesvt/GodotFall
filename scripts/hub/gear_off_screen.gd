extends CanvasLayer
## Biggie's folding table in his tent (hymn.gd): he gets a piece of the
## Shepherd's gear off her, one try each time she's back in town. Pick a piece
## (1-6), then it's a steady-hand job: his hand (the marker) shakes along the
## bar, and Space while it's in the clear band backs out one pin, needle, cup,
## tube, seal or segment. HOLDS clean ones in a row and it's off her; one slip
## and it bites back (a shock of Hymn) and stays on. Opened like a workbench
## (pausing the hub), closed on F or Esc.

const Hymn := preload("res://scripts/hub/hymn.gd")
const SFX := preload("res://scripts/sfx.gd")

const OLIVE := Color(0.62, 0.66, 0.44)
const INK := Color(0.95, 0.93, 0.88)
const DIM := Color(0.95, 0.93, 0.88, 0.55)
const GREEN := Color(0.5, 1.0, 0.6)
const RED := Color(1.0, 0.4, 0.35)

const HELLO := "Biggie clears the tea things off the table and lays out pliers, tweezers and a roll of tape. \"Sit down, kid. Show me what they put on you.\""
const NONE := "Biggie: \"Nothing on you I need to cut off. Good. Keep it that way.\""
const TIRED := "Biggie: \"Not again today. My hands need to stop shaking, and so do yours. Come back after your next run.\""
const START := {
	"headphones": "Biggie: \"Pins in your ears. Hold still, kid. Real still.\"",
	"cuff": "Biggie: \"Four needles. I'll back 'em out the way they went in.\"",
	"visor": "Biggie: \"These cups are right on your eyes. Don't you dare blink.\"",
	"bridge": "Biggie: \"Tubes up your nose. This is gonna sting.\"",
	"gloves": "Biggie: \"They've grown into your skin. I'm gonna have to peel 'em.\"",
	"bell": "Biggie: \"Collar's welded shut. Hold your chin up, I'm cutting it off you.\"",
	"spine": "Biggie: \"Nine of these, right on your spine. Stand still. I'll go slow.\"",
}
const OFF := {
	"headphones": "He eases the pins out one at a time and the headphones come away in his big hands. Quiet. Real, ordinary quiet.",
	"cuff": "The cuff comes off. Four small red marks on her wrist. Biggie tapes them up without a word.",
	"visor": "The cups let go with a wet pop and the visor's off. The world's too bright, and it's hers.",
	"bridge": "He draws the tubes out slow. She sneezes for a full minute. Biggie laughs until she does too.",
	"gloves": "The gloves peel off like old paint. Her hands sting. She can feel them again.",
	"bell": "The collar falls open and the bell hits the floor with one last ring. Biggie stamps on it. Twice.",
	"spine": "The last segment comes away. Her back slumps the way it used to. It's hers again.",
}
const SLIPPED := "His hand slips. The %s bites back, a white jolt straight through her, and stays on. Biggie: \"Damn it. Not today. Next time.\""
## Seconds his hand takes to wander the bar, at no Hymn and at full.
const SHAKE_SLOW := 1.6
const SHAKE_FAST := 0.9

var kind := "gear_off"
var unlocked: Array = []
var close_now := false
## What came off ("" none), and whether one slipped, for the toast and to re-dress her.
var removed := ""
var slipped := ""

var _status: Label
var _list: Label
var _bar: Control
var _piece := ""
var _holds := 0
var _t := 0.0
var _at := 0.5
var _close_in := -1.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var back := ColorRect.new()
	back.color = Color(0.04, 0.04, 0.03, 0.7)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.13, 0.09, 0.96)
	box.border_color = OLIVE
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", box)
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size = Vector2(620, 0)
	screen.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(_text("BIGGIE'S TABLE", 28, OLIVE))
	var line := HELLO
	if Hymn.gear.is_empty():
		line = NONE
	elif Hymn.biggie_tried:
		line = TIRED
	_status = _text(line, 16, INK)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(570, 0)
	col.add_child(_status)
	_list = _text(_list_text(), 17, INK)
	col.add_child(_list)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(570, 40)
	_bar.draw.connect(_draw_bar)
	_bar.visible = false
	col.add_child(_bar)
	col.add_child(_text("1-6 pick a piece   Space when his hand's in the clear   F or Esc leave", 14, DIM))


func can_try() -> bool:
	return not Hymn.gear.is_empty() and not Hymn.biggie_tried


func _list_text() -> String:
	if not can_try():
		return ""
	var rows := []
	for i in Hymn.gear.size():
		var g: String = Hymn.gear[i]
		var room := Hymn.steady(g)
		rows.append("%d   The %s   (%s)" % [i + 1, Hymn.GEAR_NAMES[g], "fiddly" if room >= 0.18 else ("delicate" if room >= 0.12 else "very delicate")])
	return "\n".join(rows)


func _process(delta: float) -> void:
	if _close_in >= 0.0:
		_close_in -= delta
		if _close_in < 0.0:
			close_now = true
		return
	if _piece == "":
		return
	# his hand: a wander of a few slow waves, quicker the more Hymn's in her
	_t += delta / lerpf(SHAKE_SLOW, SHAKE_FAST, Hymn.level / Hymn.MAX)
	_at = 0.5 + 0.28 * sin(_t * 2.1) + 0.12 * sin(_t * 5.3 + 1.0) + 0.06 * sin(_t * 11.0 + 2.0)
	_bar.queue_redraw()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or _close_in >= 0.0:
		return
	if _piece != "" and event.keycode == KEY_SPACE:
		hold_now()
		get_viewport().set_input_as_handled()
		return
	var i: int = event.keycode - KEY_1
	if _piece == "" and can_try() and i >= 0 and i < Hymn.gear.size():
		pick(Hymn.gear[i])
		get_viewport().set_input_as_handled()


func pick(piece: String) -> void:
	_piece = piece
	_holds = 0
	_t = _rng.randf() * 10.0
	_bar.visible = true
	_list.text = "The %s." % Hymn.GEAR_NAMES[piece]
	_status.text = START.get(piece, "")


## Whether his hand's in the clear band now (`at` 0..1 along the bar).
func clear_at(at: float) -> bool:
	return absf(at - 0.5) <= Hymn.steady(_piece) * 0.5


## Space: one pin out if he's steady, a slip if not.
func hold_now() -> void:
	if clear_at(_at):
		_holds += 1
		SFX.play(self, "dry_click", -6.0, 1.3)
		if _holds >= Hymn.HOLDS:
			Hymn.biggie_try(_piece, true)
			removed = _piece
			_finish(OFF.get(_piece, ""), false)
		else:
			_bar.queue_redraw()
	else:
		Hymn.biggie_try(_piece, false)
		slipped = _piece
		SFX.play(self, "spark", -4.0)
		_finish(SLIPPED % Hymn.GEAR_NAMES[_piece], true)


func _finish(line: String, bad: bool) -> void:
	_status.text = line
	_status.add_theme_color_override("font_color", RED if bad else GREEN)
	_close_in = 2.4


func _draw_bar() -> void:
	var w := _bar.size.x
	var h := _bar.size.y
	_bar.draw_rect(Rect2(0, 10, w, h - 20), Color(0.2, 0.2, 0.16))
	var band := Hymn.steady(_piece) if _piece != "" else 0.2
	_bar.draw_rect(Rect2(w * (0.5 - band * 0.5), 10, w * band, h - 20), Color(GREEN, 0.7))
	_bar.draw_rect(Rect2(w * clampf(_at, 0.0, 1.0) - 3, 0, 6, h), Color.WHITE if clear_at(_at) else RED)
	for i in Hymn.HOLDS:
		var c := Vector2(w - 14 - i * 22, 5)
		_bar.draw_circle(c, 6, GREEN if i < _holds else Color(INK, 0.3))


func _text(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
