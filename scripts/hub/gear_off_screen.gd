extends CanvasLayer
## Biggie's folding table in his tent (hymn.gd): he gets a piece of the
## Shepherd's gear off her, one try each time she's back in town. Pick a piece
## (1-6), then it's a steady-hand job: his hand (the marker) shakes along the
## bar, and Space while it's in the clear band backs out one pin, needle, cup,
## tube, seal or segment. HOLDS clean ones in a row and it's off her; one slip
## and it bites back (a shock of Hymn) and stays on. Opened like a workbench
## (pausing the hub), closed on F or Esc.
## Mom's and Ophelia's gear (hub_grip.gd) is on the list too: the same job on
## whoever sits down. Doc Imani does it at the Mercy Clinic (doc): for scrap,
## with a steadier hand (DOC_STEADY), her own one try a visit.

const Hymn := preload("res://scripts/hub/hymn.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
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
	"collar": "Biggie: \"Prison steel. Seen these on the transports. Chin up, I'm going in at the bolts.\"",
	"crown": "Biggie: \"Last one. This is the one that's been talking to all the others. Don't move. Don't even think.\"",
	"spine": "Biggie: \"Nine of these, right on your spine. Stand still. I'll go slow.\"",
}
const OFF := {
	"headphones": "He eases the pins out one at a time and the headphones come away in his big hands. Quiet. Real, ordinary quiet.",
	"cuff": "The cuff comes off. Four small red marks on her wrist. Biggie tapes them up without a word.",
	"visor": "The cups let go with a wet pop and the visor's off. The world's too bright, and it's hers.",
	"bridge": "He draws the tubes out slow. She sneezes for a full minute. Biggie laughs until she does too.",
	"gloves": "The gloves peel off like old paint. Her hands sting. She can feel them again.",
	"bell": "The collar falls open and the bell hits the floor with one last ring. Biggie stamps on it. Twice.",
	"collar": "The bolts give, the band opens, and the amber light goes out. Eco rubs her neck. Biggie throws it in the river.",
	"crown": "The Crown comes away in his hands and goes dark. Eco makes a sound she doesn't recognise. Then she's crying, and it's hers.",
	"spine": "The last segment comes away. Her back slumps the way it used to. It's hers again.",
}
const CROWN_LOCKED := "Biggie: \"Every wire on you runs into this thing. Pull it now and it takes the rest of you with it. Everything else first, kid.\""
const SLIPPED := "His hand slips. The %s bites back, a white jolt straight through her, and stays on. Biggie: \"Damn it. Not today. Next time.\""
## Seconds his hand takes to wander the bar, at no Hymn and at full.
const SHAKE_SLOW := 1.6
const SHAKE_FAST := 0.9

const DOC_HELLO := "Doc Imani snaps on gloves and pulls the lamp down. \"Colony hardware. I've seen worse come out of soldiers. Who's first?\""
const DOC_TIRED := "Doc Imani: \"One a visit. Nerves heal slower than you'd think. Come back after your next run.\""
const DOC_NONE := "Doc Imani: \"Nothing of theirs on any of you. Keep it that way.\""
## Scrap a try at the clinic, and how much steadier her hand is than Biggie's.
const DOC_COST := 40
const DOC_STEADY := 1.3
const OFF_THEM := "%s's %s comes off. %s sits very still for a moment, then lets out a breath like she's been holding it for days."
const SLIPPED_THEM := "The hand slips. %s's %s bites back, and %s cries out. It stays on."

var kind := "gear_off"
var unlocked: Array = []
var close_now := false
## Doc Imani's clinic instead of Biggie's table.
var doc := false
var armory  # the armory (armory.gd), for Doc Imani's fee
## What came off ("" none), and whether one slipped, for the toast and to re-dress her;
## who it was ("eco", "mom", "ophelia").
var removed := ""
var slipped := ""
var who := "eco"

var _status: Label
var _list: Label
var _bar: Control
var _piece := ""
## [[who, piece], ...] as listed.
var _rows: Array = []
var _holds := 0
var _t := 0.0
var _at := 0.5
var _close_in := -1.0
var _rng := RandomNumberGenerator.new()
## Who's here in the hub to sit down (Mom and Ophelia only when they are).
var _present: Array = []


func _init(p_doc := false, p_armory = null, present: Array = []) -> void:
	doc = p_doc
	armory = p_armory
	_present = present
	if doc:
		kind = "gear_off_doc"
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()


func _ready() -> void:
	_rows = _entries()
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
	box.bg_color = Color(0.12, 0.13, 0.09, 0.96) if not doc else Color(0.08, 0.12, 0.12, 0.96)
	box.border_color = OLIVE if not doc else Color(0.6, 0.9, 0.85)
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
	col.add_child(_text("MERCY CLINIC  -  DOC IMANI" if doc else "BIGGIE'S TABLE", 28, OLIVE if not doc else Color(0.6, 0.9, 0.85)))
	var line := DOC_HELLO if doc else HELLO
	if _rows.is_empty():
		line = DOC_NONE if doc else NONE
	elif _tried():
		line = DOC_TIRED if doc else TIRED
	elif doc:
		line += "  (%d scrap a try)" % DOC_COST
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
	col.add_child(_text("1-9 pick a piece   Space when the hand's in the clear   F or Esc leave", 14, DIM))


## Everything on Eco, then on Mom and Ophelia if they're here: [who, piece].
func _entries() -> Array:
	var out := []
	for g in Hymn.gear:
		out.append(["eco", g])
	for w in HubGrip.WHO:
		if w in _present:
			for g in HubGrip.gear_of(w):
				out.append([w, g])
	return out


func _tried() -> bool:
	return Hymn.doc_tried if doc else Hymn.biggie_tried


func can_try() -> bool:
	return not _rows.is_empty() and not _tried()


func _list_text() -> String:
	if not can_try():
		return ""
	var rows := []
	for i in _rows.size():
		var w: String = _rows[i][0]
		var g: String = _rows[i][1]
		var room := _steady(g)
		var tag: String = "" if w == "eco" else String(HubGrip.NAMES[w]) + ": "
		if w == "eco" and g == "crown" and Hymn.crown_locked():
			rows.append("%d   The Crown   (locked: everything else comes off first)" % (i + 1))
			continue
		rows.append("%d   %sThe %s   (%s)" % [i + 1, tag, Hymn.GEAR_NAMES[g], "fiddly" if room >= 0.18 else ("delicate" if room >= 0.12 else "very delicate")])
	return "\n".join(rows)


func _steady(piece: String) -> float:
	return Hymn.steady(piece) * (DOC_STEADY if doc else 1.0)


func _process(delta: float) -> void:
	if _close_in >= 0.0:
		_close_in -= delta
		if _close_in < 0.0:
			close_now = true
		return
	if _piece == "":
		return
	# the hand: a wander of a few slow waves, quicker the more Hymn's in her
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
	if _piece == "" and can_try() and i >= 0 and i < _rows.size():
		var w: String = _rows[i][0]
		var g: String = _rows[i][1]
		if w == "eco" and g == "crown" and Hymn.crown_locked():
			_status.text = CROWN_LOCKED
		else:
			pick(g, w)
		get_viewport().set_input_as_handled()


func pick(piece: String, p_who := "eco") -> void:
	if doc and armory != null:
		if not armory._spend({"scrap": DOC_COST}):
			_status.text = "Doc Imani: \"%d scrap, love. I don't do this for free.\"" % DOC_COST
			return
		armory.save()
	_piece = piece
	who = p_who
	_holds = 0
	_t = _rng.randf() * 10.0
	_bar.visible = true
	_list.text = ("The %s." if who == "eco" else HubGrip.NAMES[who] + "'s %s.") % Hymn.GEAR_NAMES[piece]
	_status.text = START.get(piece, "") if (who == "eco" and not doc) else "%s sits down. %s" % [HubGrip.NAMES.get(who, "Eco"), "Doc Imani: \"Breathe out, slow.\"" if doc else "Biggie: \"Easy now.\""]


## Whether the hand's in the clear band now (`at` 0..1 along the bar).
func clear_at(at: float) -> bool:
	return absf(at - 0.5) <= _steady(_piece) * 0.5


## Space: one pin out if the hand's steady, a slip if not.
func hold_now() -> void:
	if clear_at(_at):
		_holds += 1
		SFX.play(self, "dry_click", -6.0, 1.3)
		if _holds >= Hymn.HOLDS:
			_try(true)
			removed = _piece
			var them: String = HubGrip.NAMES.get(who, "")
			_finish(OFF.get(_piece, "") if who == "eco" else OFF_THEM % [them, Hymn.GEAR_NAMES[_piece], them], false)
		else:
			_bar.queue_redraw()
	else:
		_try(false)
		slipped = _piece
		SFX.play(self, "spark", -4.0)
		var them: String = HubGrip.NAMES.get(who, "")
		_finish(SLIPPED % Hymn.GEAR_NAMES[_piece] if who == "eco" else SLIPPED_THEM % [them, Hymn.GEAR_NAMES[_piece], them], true)


func _try(clean: bool) -> void:
	if who == "eco":
		Hymn.biggie_try(_piece, clean)
	elif clean:
		HubGrip.remove(who, _piece)
	if doc:
		Hymn.doc_tried = true
	else:
		Hymn.biggie_tried = true
	Hymn.save()


func _finish(line: String, bad: bool) -> void:
	_status.text = line
	_status.add_theme_color_override("font_color", RED if bad else GREEN)
	_close_in = 2.4


func _draw_bar() -> void:
	var w := _bar.size.x
	var h := _bar.size.y
	_bar.draw_rect(Rect2(0, 10, w, h - 20), Color(0.2, 0.2, 0.16))
	var band := _steady(_piece) if _piece != "" else 0.2
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