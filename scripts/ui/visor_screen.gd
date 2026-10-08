extends CanvasLayer
## The clarity visor's view (hymn.gd, the Shepherd's third piece of gear):
## her first-person view crowded with the colony's clutter. Orders flash up
## all over (OBEY, SUBMIT, TAKE YOUR DOSE...), white rings turn and pulse,
## spirals wind in from the edges, and false HUD crowds the corners: a
## compliance meter, a calm heart rate, a marker always pointing back to the
## dispensary, a threat count of zero, warnings about her thoughts, scanlines,
## glitches and the odd white flash. Worse while a trigger word has her. In
## third person it's quieter (THIRD_PERSON). Over the HUD, under the screens.
## Seen through the visor's glass (LENS): a curved inner screen that bends
## her view at the edges, splits its colours, rolls scanlines down it, darkens
## to a lit bezel, and tears in glitches. Behind the orders a hypnotic tunnel
## turns (the flipbook tools/hub/build_visor_fx.py renders in Blender), the
## colony's watching eye surfaces now and then, puppet strings hang from a
## control bar down to her hands, a pendulum swings, and a ring breathes for
## her. Low in the middle the inductions take turns (INDUCTIONS, INDUCTION s
## each): a countdown that takes her deeper, a staircase down, affirmations
## typed out for her, a counted breath, words that get heavier while her
## eyelids close, and lines she's made to repeat. Her name is overwritten
## with a citizen number, and her thoughts are counted down to zero.

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
const SPIRAL := preload("res://assets/textures/visor/spiral_sheet.png")
const EYE := preload("res://assets/textures/visor/eye.png")
## The glass she sees it all through.
const LENS := "shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 1.0;
uniform float tear = 0.0;
uniform float seed = 0.0;
uniform float t = 0.0;
// the inductions' alterations to what she sees (0 none .. 1 full)
uniform float drain = 0.0;
uniform float tunnel = 0.0;
uniform float ripple = 0.0;
uniform float echo = 0.0;
uniform float kaleido = 0.0;
uniform float split_view = 0.0;
float hash(float n) { return fract(sin(n) * 43758.5453); }
void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 cc = c * vec2(aspect, 1.0);
	float r2 = dot(cc, cc);
	// the curved inner screen: her view bends in toward its edges
	vec2 uv = c * (1.0 + 0.09 * strength * r2) + 0.5;
	// breathing walls: the view swells and shrinks, rings rolling out through it
	uv = (uv - 0.5) * (1.0 - 0.05 * ripple * sin(t * 1.5708)) + 0.5;
	uv += normalize(c + 0.0001) * sin(length(cc) * 34.0 - t * 5.0) * 0.007 * ripple;
	// kaleidoscope: her view folded into six mirrored slices round the middle
	if (kaleido > 0.0) {
		vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
		float seg = 6.2831853 / 6.0;
		float a = mod(atan(p.y, p.x) + t * 0.3, seg);
		a = abs(a - seg * 0.5);
		vec2 q = vec2(cos(a), sin(a)) * length(p) / vec2(aspect, 1.0) + 0.5;
		uv = mix(uv, q, kaleido);
	}
	// glitch tears: bands of it slide sideways
	float band = floor(uv.y * 26.0 + hash(seed) * 3.0);
	float torn = step(1.0 - 0.4 * tear, hash(band + seed * 13.1));
	uv.x += torn * (hash(band * 1.7 + seed) - 0.5) * 0.16 * tear;
	// colours split toward the edges, and wider in a tear
	vec2 split = c * 0.007 * strength * (0.4 + r2 * 3.0) + vec2(torn * 0.012 * tear, 0.0);
	vec3 col = vec3(texture(screen_tex, uv + split).r, texture(screen_tex, uv).g, texture(screen_tex, uv - split).b);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) col = vec3(0.0);
	// double vision: a second of everything, drifting off and back
	if (split_view > 0.0) {
		vec2 o = vec2(0.045, 0.012) * split_view;
		col = mix(col, 0.5 * (texture(screen_tex, uv + o).rgb + texture(screen_tex, uv - o).rgb), min(split_view * 2.0, 1.0));
	}
	// time slipping: everything trails behind itself
	if (echo > 0.0) {
		vec2 d = vec2(cos(t * 0.7), sin(t * 0.9)) * 0.014 * echo;
		vec3 trail = (texture(screen_tex, uv + d).rgb + texture(screen_tex, uv + d * 2.0).rgb + texture(screen_tex, uv + d * 3.0).rgb) / 3.0;
		col = mix(col, max(col, trail), 0.75 * echo);
	}
	// colour draining out of the world, toward the colony's white
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(lum) * vec3(0.92, 0.96, 1.04) + 0.1 * drain, drain);
	// tunnel vision: white closing in from the edges
	col = mix(col, vec3(0.95, 0.97, 1.0), smoothstep(0.62 - 0.4 * tunnel, 0.78 - 0.4 * tunnel, length(cc)) * tunnel);
	// scanlines, and a bright bar rolling down
	float px = SCREEN_UV.y / SCREEN_PIXEL_SIZE.y;
	col *= 1.0 - 0.12 * strength * (0.5 + 0.5 * sin(px * 1.5708));
	col += (1.0 - smoothstep(0.0, 0.06, abs(fract(SCREEN_UV.y - t * 0.11) - 0.5))) * 0.06 * strength;
	// the glass: a cold white tint
	col = mix(col, col * vec3(0.9, 0.97, 1.06) + 0.025, strength);
	// the lens edge: dark round the rim, a lit bezel just inside it
	float e = length(cc * vec2(0.8, 1.0));
	col *= 1.0 - smoothstep(0.5, 0.74, e) * 0.88 * strength;
	col += vec3(0.75, 0.9, 1.0) * exp(-pow((e - 0.6) / 0.01, 2.0)) * 0.3 * strength;
	COLOR = vec4(col, 1.0);
}"
## The tunnel's flipbook, played and turned, added over her view.
const FLIPBOOK := "shader_type canvas_item;
render_mode blend_add;
uniform float alpha = 0.4;
uniform float spin = 0.0;
uniform float fps = 16.0;
void fragment() {
	vec2 p = UV - 0.5;
	p = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * p + 0.5;
	float f = mod(floor(TIME * fps), 32.0);
	vec2 cell = vec2(mod(f, 8.0), floor(f / 8.0));
	vec4 s = texture(TEXTURE, (cell + clamp(p, 0.0, 1.0)) / vec2(8.0, 4.0));
	float fade = 1.0 - smoothstep(0.32, 0.5, length(UV - 0.5));
	COLOR = vec4(s.rgb * s.a * alpha * fade * vec3(0.85, 0.95, 1.0), 1.0);
}"
const COUNT_FROM := 10
const BREATH := 4.0
## The inductions, in turn, and how long each runs.
const INDUCTIONS := ["countdown", "stairs", "rewrite", "breath", "heavy", "repeat", "kaleido"]
const INDUCTION := 12.0
## Only in the hub: out on a run she has to be able to see to fight.
const HUB_ONLY := ["kaleido"]
## Her own thoughts, caught, struck out, and written over.
const REWRITE := [["I have to get out.", "I want to stay."], ["Mom needs me.", "Mom is happy here."],
	["Something is wrong.", "Everything is right."], ["This isn't me.", "This is who I am."]]
const CAPTIONS := {"countdown": "COLOUR IS A DISTRACTION", "stairs": "LOOK ONLY AHEAD", "rewrite": "THOUGHT CORRECTED",
	"breath": "THE WALLS BREATHE WITH YOU", "heavy": "TIME IS SLOWING DOWN", "repeat": "YOU ARE NOT ALONE IN THERE",
	"kaleido": "THERE IS NO OUTSIDE"}
const HEAVY := ["HEAVY", "HEAVIER", "SO HEAVY", "SINKING", "SINKING DEEPER"]
const REPEAT := [["WE ARE CALM", "we are calm"], ["WE ARE TOGETHER", "we are together"], ["THE DOSE IS GOOD", "the dose is good"], ["I WILL COME BACK", "i will come back"]]
const BREATH_BEATS := ["IN", "HOLD", "OUT", "HOLD"]
const CITIZEN := "CITIZEN 0471"

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
var _spiral: TextureRect
var _eye: TextureRect
var _lens: ColorRect
var _tear := 0.0
var _tear_seed := 0.0
var _next_tear := 3.0
var _eye_t := -1.0
var _next_eye := 6.0


func _init(run_manager: Node = null) -> void:
	rm = run_manager
	layer = 3
	name = "VisorScreen"
	rng.randomize()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_spiral = TextureRect.new()
	_spiral.texture = SPIRAL
	_spiral.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spiral.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spiral.material = _shader(FLIPBOOK)
	add_child(_spiral)
	_eye = TextureRect.new()
	_eye.texture = EYE
	_eye.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_eye.material = add
	add_child(_eye)
	_draw_on = Control.new()
	_draw_on.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_on.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_on.draw.connect(_paint)
	add_child(_draw_on)
	# the glass goes over everything she sees here, last
	_lens = ColorRect.new()
	_lens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lens.material = _shader(LENS)
	add_child(_lens)


func _shader(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


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
	_spiral.visible = _draw_on.visible
	_lens.visible = _draw_on.visible
	_eye.visible = _draw_on.visible and _eye_t >= 0.0
	if not _draw_on.visible:
		_words.clear()
		return
	_t += delta
	_tick_imagery(delta)
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


## The tunnel, the eye and the glass, each frame.
func _tick_imagery(delta: float) -> void:
	var size := _draw_on.size
	var gripped := Vices.entranced
	# the tunnel turning behind the orders, breathing in and out
	var side := size.y * (0.92 + 0.05 * sin(_t * TAU / BREATH))
	_spiral.size = Vector2(side, side)
	_spiral.position = size * 0.5 - _spiral.size * 0.5
	var sm := _spiral.material as ShaderMaterial
	sm.set_shader_parameter("alpha", (0.55 if gripped else 0.3) * _strength)
	sm.set_shader_parameter("spin", -_t * 0.25)
	# the watching eye: now and then it opens over everything, then fades
	_next_eye -= delta * (2.0 if gripped else 1.0)
	if _next_eye <= 0.0 and _eye_t < 0.0:
		_eye_t = 0.0
		_next_eye = rng.randf_range(9.0, 15.0)
	if _eye_t >= 0.0:
		_eye_t += delta
		var k := smoothstep(0.0, 0.6, _eye_t) * (1.0 - smoothstep(2.4, 3.2, _eye_t))
		var w := size.y * (0.75 + 0.08 * _eye_t)
		_eye.size = Vector2(w, w)
		_eye.position = Vector2(size.x * 0.5, size.y * 0.42) - _eye.size * 0.5
		_eye.modulate = Color(1, 1, 1, 0.5 * k * _strength)
		if _eye_t > 3.2:
			_eye_t = -1.0
	# the glass, and its tears: with every glitch, and every few seconds anyway
	_next_tear -= delta * (2.5 if gripped else 1.0)
	if _glitch > 0.0 or _next_tear <= 0.0:
		_tear = 1.0
		_tear_seed = rng.randf() * 100.0
		if _next_tear <= 0.0:
			_next_tear = rng.randf_range(2.5, 6.0)
	_tear = maxf(_tear - delta * 6.0, 0.0)
	var lm := _lens.material as ShaderMaterial
	lm.set_shader_parameter("strength", _strength)
	lm.set_shader_parameter("tear", _tear)
	lm.set_shader_parameter("seed", _tear_seed)
	lm.set_shader_parameter("t", _t)
	var fx := alterations()
	for key in fx:
		lm.set_shader_parameter(key, float(fx[key]) * _strength)


## What the induction running now does to her view (the lens's uniforms):
## colour drains as the countdown goes deeper, the edges white out going down
## the stairs, the walls breathe with the counted breath, time trails while
## the words get heavy, she sees double while she repeats, and the view folds
## into a kaleidoscope.
func alterations() -> Dictionary:
	var lt := fmod(_t, INDUCTION)
	var fx := {"drain": 0.0, "tunnel": 0.0, "ripple": 0.0, "echo": 0.0, "split_view": 0.0, "kaleido": 0.0}
	var ease := smoothstep(0.0, 1.0, lt) * (1.0 - smoothstep(INDUCTION - 0.6, INDUCTION, lt))
	match which_induction():
		"countdown":
			fx["drain"] = clampf(lt / COUNT_FROM, 0.0, 1.0) * ease
		"stairs":
			fx["tunnel"] = clampf(lt / 10.0, 0.0, 1.0) * 0.85 * ease
		"rewrite":
			fx["drain"] = 0.25 * ease  # a moment of grey round every correction
		"breath":
			fx["ripple"] = ease
		"heavy":
			fx["echo"] = smoothstep(0.0, 8.0, lt) * ease
		"repeat":
			fx["split_view"] = (0.5 + 0.5 * sin(lt * 1.3)) * ease
		"kaleido":
			fx["kaleido"] = smoothstep(1.0, 4.0, lt) * (1.0 - smoothstep(9.0, 11.5, lt))
	if Vices.entranced:
		fx["echo"] = maxf(fx["echo"], 0.4)
		fx["drain"] = maxf(fx["drain"], 0.3)
	return fx


## One order, somewhere on screen, big or small.
func spawn_word() -> void:
	var size := _draw_on.size
	var big := rng.randf() < 0.25
	_words.append({
		"text": WORDS[rng.randi() % WORDS.size()],
		"pos": Vector2(rng.randf_range(0.05, 0.75) * size.x, rng.randf_range(0.12, 0.62) * size.y),  # the low third is the inductions'
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
	# turning, pulsing rings round the middle (Hymn's concentric circles)
	for i in 5:
		var r := 60.0 + i * 70.0 + 14.0 * sin(_t * 2.0 + i)
		var spin := _t * (0.6 + 0.25 * i) * (1.0 if i % 2 == 0 else -1.0)
		for k in 6:
			var from := spin + TAU * k / 6.0
			_draw_on.draw_arc(c, r, from, from + TAU / 9.0, 16, Color(WHITE, a * (0.5 - i * 0.07)), 2.0 + (1.0 if i == 0 else 0.0))
	_strings(size, s)
	_pendulum(size, s)
	_breath(c, s)
	_eyelids(size, s)  # the inductions' words float over her closing eyes
	_induction(size, s)
	_subject(size, s)
	_thoughts(size, s)
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


## The control bar of a marionette over her view, swaying, its strings running
## down to the bottom of the screen where her hands and gun are.
func _strings(size: Vector2, s: float) -> void:
	var sway := sin(_t * 0.9) * 0.08
	var bar_c := Vector2(size.x * 0.5 + sin(_t * 0.6) * 40.0, size.y * 0.15)
	var bar := Vector2(cos(sway), sin(sway)) * 150.0
	var cross := Vector2(-sin(sway), cos(sway)) * 46.0
	var col := Color(WHITE, 0.75 * s)
	_draw_on.draw_line(bar_c - bar, bar_c + bar, col, 5.0)
	_draw_on.draw_line(bar_c - cross, bar_c + cross, col, 5.0)
	var ends := [bar_c - bar, bar_c + bar, bar_c - cross, bar_c + cross]
	var to := [Vector2(size.x * 0.18, size.y * 1.02), Vector2(size.x * 0.82, size.y * 1.02), Vector2(size.x * 0.62, size.y * 0.86), Vector2(size.x * 0.4, size.y * 0.9)]
	for i in 4:
		var a: Vector2 = ends[i]
		var b: Vector2 = to[i] + Vector2(sin(_t * 1.3 + i) * 18.0, 0)
		var mid := (a + b) * 0.5 + Vector2(sin(_t * 1.1 + i * 2.0) * 22.0, 30.0)
		var pts := PackedVector2Array()
		for j in 17:
			var u := j / 16.0
			pts.append(a.lerp(mid, u).lerp(mid.lerp(b, u), u))
		_draw_on.draw_polyline(pts, Color(WHITE, 0.5 * s), 2.5)
	_text("WE HOLD THE STRINGS", bar_c + Vector2(-110, 78), 15, Color(WHITE, 0.45 * s))


## A pocket watch on a chain, swinging, high on the left.
func _pendulum(size: Vector2, s: float) -> void:
	var pivot := Vector2(size.x * 0.27, size.y * 0.08)
	var swing := sin(_t * TAU / 2.6) * 0.42
	var bob := pivot + Vector2(sin(swing), cos(swing)) * size.y * 0.24
	for j in 14:
		var p := pivot.lerp(bob, j / 14.0)
		_draw_on.draw_circle(p, 3.0, Color(WHITE, 0.5 * s))
	_draw_on.draw_circle(bob, 30.0, Color(0.05, 0.07, 0.1, 0.35 * s))
	_draw_on.draw_arc(bob, 30.0, 0.0, TAU, 40, Color(WHITE, 0.75 * s), 3.0)
	_draw_on.draw_arc(bob, 22.0, 0.0, TAU, 40, Color(WHITE, 0.35 * s), 1.5)
	var hand := Vector2(cos(-_t * 3.0), sin(-_t * 3.0)) * 18.0
	_draw_on.draw_line(bob, bob + hand, Color(WHITE, 0.8 * s), 2.0)
	_text("WATCH IT", bob + Vector2(-34, 52), 14, Color(WHITE, 0.4 * s))


## A ring that breathes for her, round the middle: in, then out.
func _breath(c: Vector2, s: float) -> void:
	var phase := fmod(_t, BREATH * 2.0) / BREATH
	var k := smoothstep(0.0, 1.0, phase) if phase < 1.0 else 1.0 - smoothstep(1.0, 2.0, phase)
	var r := 70.0 + 90.0 * k
	_draw_on.draw_arc(c, r, 0.0, TAU, 64, Color(WHITE, (0.25 + 0.2 * k) * s), 3.0)
	var word := "BREATHE IN" if phase < 1.0 else "BREATHE OUT"
	_text(word, c + Vector2(-62, r + 30), 18, Color(WHITE, 0.55 * s))


## The induction running now, low in the middle (they take turns; the
## HUB_ONLY ones sit out a run).
func which_induction() -> String:
	var list: Array = INDUCTIONS if in_hub() else INDUCTIONS.filter(func(i): return not i in HUB_ONLY)
	return list[int(_t / INDUCTION) % list.size()]


## In the hub (or with no run manager, as in the render tools), not on a run.
func in_hub() -> bool:
	if rm == null or rm.get("phase") == null:
		return true
	return rm.phase == rm.Phase.HUB


func _induction(size: Vector2, s: float) -> void:
	var lt := fmod(_t, INDUCTION)
	var cap: String = CAPTIONS.get(which_induction(), "")
	if cap != "":
		_text(cap, Vector2(size.x * 0.5 - cap.length() * 6.0, size.y * 0.93), 16, Color(WHITE, 0.55 * s))
	match which_induction():
		"countdown":
			_countdown(size, s, lt)
		"stairs":
			_stairs(size, s, lt)
		"rewrite":
			_rewrite(size, s, lt)
		"kaleido":
			pass
		"breath":
			_breath_count(size, s, lt)
		"heavy":
			_heavy(size, s, lt)
		"repeat":
			_repeat(size, s, lt)


## A staircase down into the middle of her view, a step a second, the one
## she's on lit.
func _stairs(size: Vector2, s: float, lt: float) -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.62)
	var on := mini(int(lt), 9)
	for i in 10:
		var k := 1.0 - i / 10.0
		var w := 560.0 * k
		var y := c.y + 200.0 * k * k
		var lit := i == on
		var step := Rect2(Vector2(c.x - w * 0.5, y), Vector2(w, 16.0 * k + 3.0))
		_draw_on.draw_rect(step, Color(0.03, 0.04, 0.06, 0.5 * s))
		_draw_on.draw_rect(step, Color(WHITE, (0.9 if lit else 0.45) * s), lit, 2.0 if not lit else -1.0)
	_text("STEP %d" % (on + 1), c + Vector2(-48, 230), 26, Color(WHITE, 0.8 * s))
	_text("ALL THE WAY DOWN" if on >= 9 else "...step down", c + Vector2(-80, 258), 18, Color(WHITE, 0.5 * s))


## Her own thought, typed as she has it, struck out, and written over with
## theirs, one every three seconds.
func _rewrite(size: Vector2, s: float, lt: float) -> void:
	var pair: Array = REWRITE[int(lt / 3.0) % REWRITE.size()]
	var k := fmod(lt, 3.0)
	var hers: String = pair[0]
	var theirs: String = pair[1]
	var at := Vector2(size.x * 0.5 - 200.0, size.y * 0.76)
	_text("YOUR THOUGHT:", at + Vector2(0, -34), 15, Color(1.0, 0.8, 0.8, 0.5 * s))
	var typed := hers.substr(0, int(ceil(hers.length() * clampf(k / 1.0, 0.0, 1.0))))
	_text(typed, at, 32, Color(1.0, 0.85, 0.85, (0.85 if k < 1.6 else 0.35) * s))
	if k > 1.1:  # struck through
		var w := hers.length() * 15.5 * clampf((k - 1.1) / 0.4, 0.0, 1.0)
		_draw_on.draw_line(at + Vector2(-6, -10), at + Vector2(w, -10), Color(1.0, 0.3, 0.3, 0.9 * s), 4.0)
	if k > 1.6:  # and written over
		var shown := theirs.substr(0, int(ceil(theirs.length() * clampf((k - 1.6) / 0.9, 0.0, 1.0))))
		_text(shown + ("_" if fmod(_t, 0.5) < 0.25 else ""), at + Vector2(0, 44), 34, Color(WHITE, 0.9 * s))


## A counted breath: in for four, hold for four, out for four, hold for four.
func _breath_count(size: Vector2, s: float, lt: float) -> void:
	var beat := int(lt) % 16
	var phase := beat / 4
	var at := Vector2(size.x * 0.5 - 150.0, size.y * 0.8)
	for i in 4:
		var col := Color(WHITE, (0.9 if i == phase else 0.25) * s)
		_text(BREATH_BEATS[i], at + Vector2(i * 84.0, 0), 24, col)
	_text(str(beat % 4 + 1), Vector2(size.x * 0.5 - 12.0, size.y * 0.8 + 52.0), 44, Color(WHITE, 0.8 * s))


## Words that get heavier and sink, a word every 2.4 s, while her eyelids
## close (_eyelids).
func _heavy(size: Vector2, s: float, lt: float) -> void:
	var i := mini(int(lt / 2.4), HEAVY.size() - 1)
	var k := fmod(lt, 2.4) / 2.4
	var word: String = HEAVY[i]
	var spaced := ""  # the letters drifting apart
	for ch in word:
		spaced += ch + " "
	var at := Vector2(size.x * 0.5 - spaced.length() * 9.0, size.y * (0.72 + 0.04 * i) + k * 26.0)
	_text(spaced, at, 30 + i * 3, Color(WHITE, (1.0 - k * 0.5) * 0.8 * s))


## Lines she's made to say back: theirs, then hers under it, a beat late.
func _repeat(size: Vector2, s: float, lt: float) -> void:
	var pair: Array = REPEAT[int(lt / 3.0) % REPEAT.size()]
	var k := fmod(lt, 3.0)
	var at := Vector2(size.x * 0.5 - 170.0, size.y * 0.76)
	_text("REPEAT AFTER US:", at + Vector2(0, -32), 16, Color(WHITE, 0.45 * s))
	_text(pair[0], at, 32, Color(WHITE, 0.85 * s))
	_text(pair[0], at + Vector2(9, 4), 32, Color(WHITE, 0.3 * s))  # seen twice
	if k > 1.0:
		var hers: String = pair[1]
		var shown := hers.substr(0, int(ceil(hers.length() * clampf((k - 1.0) / 1.2, 0.0, 1.0))))
		_text("\"" + shown + "\"", at + Vector2(20, 40), 26, Color(0.75, 0.9, 1.0, 0.8 * s))


## Her name, overwritten: ECO scrambles and comes back a citizen number.
func _subject(size: Vector2, s: float) -> void:
	var k := fmod(_t, 10.0)
	var name := "ECO"
	if k > 6.0:
		name = CITIZEN
	elif k > 4.0:
		name = ""
		var glyphs := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#%"
		for i in CITIZEN.length():
			name += glyphs[rng.randi() % glyphs.length()]
	var at := Vector2(24, size.y * 0.32 + 120.0)
	_text("SUBJECT:", at, 14, Color(WHITE, 0.5 * s))
	_text(name, at + Vector2(84, 0), 18, Color(WHITE, 0.85 * s) if name != "ECO" else Color(1.0, 0.8, 0.8, 0.85 * s))
	if k > 6.0:
		_text("NAME UPDATED", at + Vector2(0, 22), 13, Color(0.6, 1.0, 0.7, 0.6 * s))


## Her thoughts, counted down to none.
func _thoughts(size: Vector2, s: float) -> void:
	var n := maxi(3 - int(fmod(_t, 16.0) / 4.0), 0)
	var at := Vector2(size.x - 330, size.y * 0.32 + 104.0)
	_box(at, "THOUGHTS  %d" % n, n / 3.0, s)
	if n == 0:
		_text("THINKING IS NOT REQUIRED", at + Vector2(0, 64), 15, Color(WHITE, 0.6 * s))


## Her eyelids, heavy: dark closing in from above and below while the heavy
## words run, or a trigger word has her; snapping open again.
func _eyelids(size: Vector2, s: float) -> void:
	var k := 0.0
	if which_induction() == "heavy":
		var lt := fmod(_t, INDUCTION)
		k = smoothstep(0.0, 10.0, lt) * (1.0 - smoothstep(11.4, 11.8, lt))
	if Vices.entranced:
		k = maxf(k, 0.35 + 0.15 * sin(_t * 1.3))
	if k <= 0.0:
		return
	var h := size.y * 0.5 * 0.82 * k
	var lid := Color(0.02, 0.02, 0.04, 0.92 * s)
	_draw_on.draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, h)), lid)
	_draw_on.draw_rect(Rect2(Vector2(0, size.y - h), Vector2(size.x, h)), lid)


## Counting her down, a number a second, each one smaller and further down.
func _countdown(size: Vector2, s: float, lt: float) -> void:
	var n := COUNT_FROM - mini(int(lt), COUNT_FROM)
	var k := fmod(lt, 1.0)
	var depth := float(COUNT_FROM - n) / COUNT_FROM
	var at := Vector2(size.x * 0.5 - 20.0, size.y * (0.7 + 0.12 * depth) + k * 14.0)
	var big := int(lerpf(64.0, 26.0, depth))
	if n == 0:
		_text("DEEPER", at + Vector2(-50, 0), 40, Color(WHITE, (1.0 - k) * 0.8 * s))
	else:
		_text(str(n), at, big, Color(WHITE, (1.0 - k * 0.7) * 0.7 * s))
		_text("...deeper", at + Vector2(big * 0.7, 0), 16, Color(WHITE, 0.4 * s))


func _box(at: Vector2, label: String, fill: float, s: float) -> void:
	_draw_on.draw_rect(Rect2(at, Vector2(300, 44)), Color(0.05, 0.07, 0.1, 0.45 * s))
	_draw_on.draw_rect(Rect2(at, Vector2(300, 44)), Color(WHITE, 0.6 * s), false, 1.5)
	_text(label, at + Vector2(10, 20), 16, Color(WHITE, 0.9 * s))
	if fill > 0.0:
		_draw_on.draw_rect(Rect2(at + Vector2(10, 28), Vector2(280 * fill, 8)), Color(WHITE, 0.75 * s))


func _text(t: String, at: Vector2, size: int, col: Color) -> void:
	_draw_on.draw_string_outline(_font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, col.a * 0.5))
	_draw_on.draw_string(_font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
