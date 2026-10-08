extends CanvasLayer
## The clarity visor's view (hymn.gd, the Shepherd's third piece of gear):
## her first-person view crowded with the colony's clutter. Orders flash up
## all over (OBEY, SUBMIT, TAKE YOUR DOSE...), white rings turn and pulse,
## spirals wind in from the edges, and false HUD crowds the corners: a
## compliance meter, a calm heart rate, a marker always pointing back to the
## dispensary, a threat count of zero, warnings about her thoughts, scanlines,
## glitches and the odd white flash. Worse while a trigger word has her. In
## third person it's quieter (THIRD_PERSON). Over the HUD, under the screens.

const Hymn := preload("res://scripts/hub/hymn.gd")
const Vices := preload("res://scripts/hub/vices.gd")

const WORDS := ["OBEY", "SUBMIT", "TAKE YOUR DOSE", "YOU ARE SAFE", "CONFORM", "SMILE", "NO THOUGHTS",
	"GOOD CITIZEN", "RETURN TO THE DISPENSARY", "STOP RUNNING", "LOWER YOUR WEAPON", "TRUST THE COLONY",
	"RELAX", "SLEEP", "COMPLY", "EVERYONE IS YOUR FRIEND", "BE STILL"]
const WARNINGS := ["UNAUTHORISED THOUGHT DETECTED", "DOSE OVERDUE", "NONCOMPLIANCE LOGGED", "MEMORY CORRECTION PENDING"]
## Words a second, and how long one stays.
const RATE := 2.2
const LIFE := 1.6
## How much of it shows in third person.
const THIRD_PERSON := 0.4
const WHITE := Color(0.95, 0.98, 1.0)

var rm: Node
var _draw_on: Control
var _words: Array = []
var _spawn := 0.0
var _t := 0.0
var _flash := 0.0
var _next_flash := 5.0
var _glitch := 0.0
var _strength := 0.0
var _font: Font
var rng := RandomNumberGenerator.new()


func _init(run_manager: Node = null) -> void:
	rm = run_manager
	layer = 3
	name = "VisorScreen"
	rng.randomize()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_draw_on = Control.new()
	_draw_on.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_on.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_on.draw.connect(_paint)
	add_child(_draw_on)


## How strongly it shows now, 0..1 (0: no visor, a screen open, Teen).
func strength() -> float:
	if not Hymn.has("visor"):
		return 0.0
	var fitting: Node = rm.get("fitting_scene") if rm != null else null
	if fitting != null and fitting.busy():
		return 1.0 if fitting.visor_flash else 0.0  # its first orders, at the end of its fitting
	if rm != null and (rm.get("bench") != null or not rm.hud.visible):
		return 0.0
	var s := 1.0
	var view: Node = rm.player.get_node_or_null("ViewCam") if rm != null else null
	if view != null and view.get("third_person") == true:
		s = THIRD_PERSON
	return s


func _process(delta: float) -> void:
	_strength = strength()
	_draw_on.visible = _strength > 0.0
	if not _draw_on.visible:
		_words.clear()
		return
	_t += delta
	if _words.is_empty():
		for i in 5:  # it comes on in a burst
			spawn_word()
	var gripped := Vices.entranced
	_spawn += delta * RATE * (2.5 if gripped else 1.0) * _strength
	while _spawn >= 1.0:
		_spawn -= 1.0
		spawn_word()
	for w in _words.duplicate():
		w["age"] += delta
		if w["age"] >= w["life"]:
			_words.erase(w)
	_next_flash -= delta
	if _next_flash <= 0.0:
		_flash = 1.0
		_next_flash = rng.randf_range(4.0, 9.0) * (0.5 if gripped else 1.0)
	_flash = maxf(_flash - delta * 3.0, 0.0)
	_glitch -= delta
	_draw_on.queue_redraw()


## One order, somewhere on screen, big or small.
func spawn_word() -> void:
	var size := _draw_on.size
	var big := rng.randf() < 0.25
	_words.append({
		"text": WORDS[rng.randi() % WORDS.size()],
		"pos": Vector2(rng.randf_range(0.05, 0.75) * size.x, rng.randf_range(0.12, 0.9) * size.y),
		"size": rng.randi_range(64, 110) if big else rng.randi_range(22, 40),
		"age": 0.0,
		"life": LIFE * rng.randf_range(0.7, 1.3),
	})
	if rng.randf() < 0.3:
		_glitch = 0.12


func _paint() -> void:
	var size := _draw_on.size
	var c := size * 0.5
	var s := _strength
	var a := 0.55 * s
	# scanlines
	for y in range(0, int(size.y), 4):
		_draw_on.draw_line(Vector2(0, y), Vector2(size.x, y), Color(WHITE, 0.035 * s), 1.0)
	# turning, pulsing rings round the middle (Hymn's concentric circles)
	for i in 5:
		var r := 60.0 + i * 70.0 + 14.0 * sin(_t * 2.0 + i)
		var spin := _t * (0.6 + 0.25 * i) * (1.0 if i % 2 == 0 else -1.0)
		for k in 6:
			var from := spin + TAU * k / 6.0
			_draw_on.draw_arc(c, r, from, from + TAU / 9.0, 16, Color(WHITE, a * (0.5 - i * 0.07)), 2.0 + (1.0 if i == 0 else 0.0))
	# spirals winding in from the corners
	for corner in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), Vector2(size.x, size.y)]:
		var pts := PackedVector2Array()
		for j in 60:
			var u := j / 60.0
			var ang := _t * 1.4 + u * TAU * 2.5
			pts.append(corner + Vector2(cos(ang), sin(ang)) * (1.0 - u) * 260.0)
		_draw_on.draw_polyline(pts, Color(WHITE, a * 0.45), 2.0)
	# false HUD: compliance, heart rate, threats
	var comp := 0.82 + 0.15 * sin(_t * 0.7)
	_box(Vector2(24, size.y * 0.32), "COMPLIANCE  %d%%" % roundi(comp * 100.0), comp, s)
	_box(Vector2(24, size.y * 0.32 + 58), "HEART RATE  CALM  %d BPM" % (60 + int(_t * 3.0) % 5), 0.6, s)
	_box(Vector2(size.x - 330, size.y * 0.32), "THREATS NEARBY  0", 0.0, s)
	_text("EVERYONE IS YOUR FRIEND", Vector2(size.x - 330, size.y * 0.32 + 62), 16, Color(0.6, 1.0, 0.7, a + 0.2))
	# the marker that always points back to the dispensary
	var m := c + Vector2(sin(_t * 0.5) * 140.0, -120.0 + cos(_t * 0.7) * 30.0)
	var d := PackedVector2Array([m + Vector2(0, -14), m + Vector2(12, 0), m + Vector2(0, 14), m + Vector2(-12, 0)])
	_draw_on.draw_colored_polygon(d, Color(WHITE, 0.8 * s))
	_text("DISPENSARY  %dm" % (40 + int(_t * 7.0) % 9), m + Vector2(20, 6), 18, Color(WHITE, 0.85 * s))
	# warnings, blinking
	if fmod(_t, 1.2) < 0.7:
		var wtext: String = WARNINGS[int(_t / 1.2) % WARNINGS.size()]
		var wpos := Vector2(c.x - 260, size.y * 0.16)
		_draw_on.draw_rect(Rect2(wpos - Vector2(12, 28), Vector2(540, 40)), Color(1.0, 0.3, 0.3, 0.25 * s))
		_text("! " + wtext, wpos, 22, Color(1.0, 0.85, 0.85, 0.9 * s))
	# the orders themselves
	for w in _words:
		var life: float = w["life"]
		var age: float = w["age"]
		var fade := 1.0 - age / life
		var flick := 1.0 if age > 0.3 or fmod(age, 0.1) < 0.06 else 0.0
		var grow := 1.0 + 0.15 * (1.0 - fade)
		_text(w["text"], w["pos"], int(float(w["size"]) * grow), Color(WHITE, fade * flick * s * 0.9))
	# glitch blocks
	if _glitch > 0.0:
		for i in 6:
			var g := Rect2(rng.randf() * size.x, rng.randf() * size.y, rng.randf_range(60, 300), rng.randf_range(4, 18))
			_draw_on.draw_rect(g, Color(WHITE, 0.35 * s))
	# on a run, every grunt wearing a friend's face (visor_friends.gd) gets its tag
	var friends: Node = rm.get("visor_friends") if rm != null else null
	if friends != null and friends.on():
		var cam := get_viewport().get_camera_3d()
		for pair in friends.disguised():
			var grunt: Node3D = pair[0]
			var head := grunt.global_position + Vector3(0, 2.05, 0)
			if cam == null or cam.is_position_behind(head):
				continue
			var at := cam.unproject_position(head)
			_text("FRIEND", at + Vector2(-34, 0), 20, Color(0.55, 1.0, 0.65, 0.95))
			_text(String(pair[1]).to_upper(), at + Vector2(-30, 18), 13, Color(0.75, 1.0, 0.8, 0.8))
	# the odd white flash
	if _flash > 0.0:
		_draw_on.draw_rect(Rect2(Vector2.ZERO, size), Color(WHITE, 0.3 * _flash * s))


func _box(at: Vector2, label: String, fill: float, s: float) -> void:
	_draw_on.draw_rect(Rect2(at, Vector2(300, 44)), Color(0.05, 0.07, 0.1, 0.45 * s))
	_draw_on.draw_rect(Rect2(at, Vector2(300, 44)), Color(WHITE, 0.6 * s), false, 1.5)
	_text(label, at + Vector2(10, 20), 16, Color(WHITE, 0.9 * s))
	if fill > 0.0:
		_draw_on.draw_rect(Rect2(at + Vector2(10, 28), Vector2(280 * fill, 8)), Color(WHITE, 0.75 * s))


func _text(t: String, at: Vector2, size: int, col: Color) -> void:
	_draw_on.draw_string_outline(_font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, col.a * 0.5))
	_draw_on.draw_string(_font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
