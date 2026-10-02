extends Control
## Radio popup: a small intercepted-transmission box above the health readout.
## Callsigns in amber (militia HQ in red), text types out with static, and
## words break up when the speaker is near the edge of radio range.
## radio_chatter.gd feeds it with show_line() and end_transmission().

const WIDTH := 500.0
const FONT_SIZE := 17
const HEADER_SIZE := 13
const ROW := 21.0
const HEADER := 24.0
const PAD := 10.0
const MAX_ROWS := 6
const KEEP_LINES := 3
const TYPE_SPEED := 45.0  # characters per second
const HOLD := 3.5  # seconds the box stays after the net goes quiet
const FADE := 0.6

const BG := Color(0.03, 0.07, 0.05, 0.8)
const EDGE := Color(0.35, 0.8, 0.5, 0.55)
const TEXT := Color(0.78, 1.0, 0.82)
const DIM := Color(0.5, 0.75, 0.55, 0.8)
const GRUNT := Color(1.0, 0.72, 0.25)
const HQ := Color(1.0, 0.38, 0.3)
const GARBLE := "~-=#/"

var entries: Array = []  # {"callsign", "text", "clarity", "hq", "shown", "seed"}
var on_air := false
var quiet_time := 99.0
var alpha := 0.0
var jitter := 0.0
var garble_timer := 0.0
var garble_seed := 0
var font: Font
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 24
	offset_right = 24 + WIDTH
	offset_bottom = -100
	offset_top = -100 - (HEADER + PAD * 2.0 + ROW * MAX_ROWS)
	modulate.a = 0.0


func show_line(callsign: String, text: String, clarity := 1.0, hq := false) -> void:
	entries.append({
		"callsign": callsign, "text": text, "clarity": clamp(clarity, 0.0, 1.0),
		"hq": hq, "shown": 0.0,
	})
	while entries.size() > KEEP_LINES:
		entries.pop_front()
	on_air = true
	quiet_time = 0.0
	jitter = 0.15


func end_transmission() -> void:
	on_air = false
	quiet_time = 0.0


## True while the box is on screen.
func is_showing() -> bool:
	return alpha > 0.01


## The line currently typing (or last typed), for tests.
func current_text() -> String:
	return "" if entries.is_empty() else "%s: %s" % [entries[-1]["callsign"], entries[-1]["text"]]


func _process(delta: float) -> void:
	if not on_air:
		quiet_time += delta
	var want := 1.0 if on_air or quiet_time < HOLD else 0.0
	alpha = move_toward(alpha, want, delta / FADE)
	modulate.a = alpha
	if alpha <= 0.0 and not on_air:
		entries.clear()
		return
	if not entries.is_empty():
		entries[-1]["shown"] += delta * TYPE_SPEED
	jitter = maxf(jitter - delta, 0.0)
	garble_timer -= delta
	if garble_timer <= 0.0:
		garble_timer = 0.08
		garble_seed += 1
	queue_redraw()


func _typing() -> bool:
	return not entries.is_empty() and entries[-1]["shown"] < entries[-1]["text"].length()


func _draw() -> void:
	if entries.is_empty():
		return
	# Lay out rows bottom-up so the newest line sits at the bottom.
	var rows: Array = []  # [callsign or "", text, colour of callsign]
	for e in entries:
		var shown_text := _garbled(e)
		var lead: String = e["callsign"] + ": "
		var wrapped := _wrap(lead + e["text"], WIDTH - PAD * 2.0)
		var visible_chars := lead.length() + shown_text.length()
		var used := 0
		for i in wrapped.size():
			var row: String = wrapped[i]
			var start := used
			used += row.length() + 1  # the space the wrap ate
			if start >= visible_chars:
				break
			var full := lead + shown_text
			var piece := full.substr(start, mini(row.length(), visible_chars - start))
			rows.append([e, piece, i == 0])
	while rows.size() > MAX_ROWS:
		rows.pop_front()

	var h := HEADER + PAD * 2.0 + ROW * rows.size()
	var top := size.y - h
	var shake := Vector2(rng.randf_range(-3.0, 3.0), 0.0) if jitter > 0.0 else Vector2.ZERO
	var box := Rect2(Vector2(0, top) + shake, Vector2(WIDTH, h))
	draw_rect(box, BG)
	draw_rect(box, EDGE, false, 1.5)

	# Header: channel, listening light, signal bars.
	var hx := box.position.x + PAD
	var hy := box.position.y + PAD + HEADER_SIZE
	var blink := on_air and int(Time.get_ticks_msec() / 400) % 2 == 0
	draw_circle(Vector2(hx + 5, hy - 5), 4.0, Color(1, 0.2, 0.15) if blink else Color(0.4, 0.1, 0.1))
	draw_string(font, Vector2(hx + 16, hy), "INTERCEPT  //  MILITIA NET  CH 7", HORIZONTAL_ALIGNMENT_LEFT, -1, HEADER_SIZE, DIM)
	var clarity: float = entries[-1]["clarity"]
	for b in 4:
		var lit := clarity >= (b + 0.5) / 4.0
		var bh := 4.0 + b * 3.0
		var bx := box.end.x - PAD - (4 - b) * 7.0
		draw_rect(Rect2(bx, hy - bh, 5, bh), TEXT if lit else Color(TEXT, 0.2))
	draw_line(Vector2(box.position.x + PAD, hy + 6), Vector2(box.end.x - PAD, hy + 6), Color(EDGE, 0.35), 1.0)

	# Lines.
	var y := box.position.y + PAD + HEADER + FONT_SIZE
	for r in rows:
		var e: Dictionary = r[0]
		var piece: String = r[1]
		var x := box.position.x + PAD
		var fade := 1.0 if e == entries[-1] else 0.6
		if r[2]:
			var lead: String = e["callsign"] + ": "
			var sign_part := piece.substr(0, mini(lead.length(), piece.length()))
			draw_string(font, Vector2(x, y), sign_part, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(HQ if e["hq"] else GRUNT, fade))
			x += font.get_string_size(sign_part, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			piece = piece.substr(sign_part.length())
		draw_string(font, Vector2(x, y), piece, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(TEXT, fade))
		y += ROW

	# Static: scanlines, plus noise bands while someone is talking.
	var sy := box.position.y
	while sy < box.end.y:
		draw_line(Vector2(box.position.x, sy), Vector2(box.end.x, sy), Color(0, 0, 0, 0.12), 1.0)
		sy += 3.0
	if _typing() or jitter > 0.0:
		var bands := 2 + int((1.0 - clarity) * 6.0)
		for i in bands:
			var by := rng.randf_range(box.position.y, box.end.y)
			draw_line(Vector2(box.position.x, by), Vector2(box.end.x, by), Color(TEXT, rng.randf_range(0.04, 0.16)), rng.randf_range(1.0, 3.0))


## The typed-so-far text with weak-signal characters swapped for static.
func _garbled(e: Dictionary) -> String:
	var text: String = e["text"]
	var out := text.substr(0, int(e["shown"]))
	var chance: float = (1.0 - e["clarity"]) * 0.45
	if chance <= 0.0:
		return out
	var noise := RandomNumberGenerator.new()
	noise.seed = hash(text) + garble_seed
	var chars := out.to_utf8_buffer()
	for i in chars.size():
		if chars[i] != 32 and noise.randf() < chance:
			chars[i] = GARBLE.unicode_at(noise.randi() % GARBLE.length())
	return chars.get_string_from_utf8()


func _wrap(text: String, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var row := ""
	for word in text.split(" "):
		var test := word if row == "" else row + " " + word
		if row != "" and font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x > width:
			out.append(row)
			row = word
		else:
			row = test
	if row != "":
		out.append(row)
	return out
