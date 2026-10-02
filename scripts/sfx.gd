extends RefCounted
## Procedural sound effects. Every sound is synthesized from filtered noise
## and simple oscillators the first time it plays, then cached, so the game
## ships no audio files. Guns are built like real recordings: a sharp crack,
## a low-passed blast and sub thump, the action cycling, and a short room tail,
## pushed through soft saturation so they hit hard.
##
## Eco's pistol has an integrated suppressor, so its shot is a tight "thup"
## and a hiss of gas, and the crisp metal of the action is the loudest part,
## with a faint electric whine from the rail coil on top.
##
## To use a recorded sound instead, drop `<id>.wav` or `<id>.ogg` into
## res://assets/audio/sfx/ (for example pistol.wav); it replaces the recipe.
##
##   SFX.play(self, "pistol")                 # flat, follows the listener
##   SFX.play_at(parent, pos, "ricochet")     # positional, frees itself

const RATE := 44100
## Recorded overrides: <id>.wav or <id>.ogg in here replace the recipe.
const OVERRIDES := "res://assets/audio/sfx/"

static var _cache := {}
static var _rng := RandomNumberGenerator.new()


## Plays a non-positional sound (first-person weapons, UI ticks).
static func play(parent: Node, id: String, volume_db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	if parent == null or not parent.is_inside_tree():
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream(id)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Plays a sound at a world position.
static func play_at(parent: Node, pos: Vector3, id: String, volume_db := 0.0, pitch := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(id)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 12.0
	p.max_distance = 140.0
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


## A random pitch around 1.0, so repeated shots don't sound like a loop.
static func vary(amount := 0.06) -> float:
	return 1.0 + _rng.randf_range(-amount, amount)


static func stream(id: String) -> AudioStream:
	if not _cache.has(id):
		_cache[id] = _recorded(id)
		if _cache[id] == null:
			_cache[id] = _to_wav(_synth(id))
	return _cache[id]


static func _recorded(id: String) -> AudioStream:
	for ext in ["wav", "ogg"]:
		var path: String = OVERRIDES + id + "." + ext
		if ResourceLoader.exists(path):
			return load(path)
	return null


# --- Recipes ------------------------------------------------------------------

static func _synth(id: String) -> PackedFloat32Array:
	_rng.seed = hash(id)
	match id:
		# Eco's pistol, suppressed: a tight thup, the action clacking, and a
		# whisper of coil whine. Almost no room tail; the gun is quiet.
		"pistol":
			return _suppressed(false)
		"pistol_last":  # last round: the slide locks back and the screen chirps empty
			return _suppressed(true)
		"dry_click":  # trigger on an empty chamber
			return _master(_mix([
				_tick(4200.0, 0.6),
				_delay(_filter(_burst(0.03, 0.0005, 160.0, 0.25), "bp", 1700.0, 4.0), 0.004),
				_delay(_blips([880.0, 660.0], 0.03, 0.08), 0.02),
			]), 0.0)
		"spark":  # crackle from the dead smart-lock module
			return _filter(_crackle(0.22, 46, 0.6), "hp", 1800.0)
		"lock_err":  # the smart-lock trying, and failing, to lock: a glitchy chirp
			return _filter(_mix([_square(0.04, 1320.0, 0.12), _square(0.05, 990.0, 0.12, 0.05), _crackle(0.12, 10, 0.25)]), "lp", 4000.0)
		"reload_out":  # mag release, a pneumatic kick out, the screen blanks
			return _master(_mix([
				_tick(3800.0, 0.7),
				_delay(_tick(2400.0, 0.45), 0.012),
				_delay(_filter(_burst(0.14, 0.004, 26.0, 0.35), "bp", 3200.0, 0.8), 0.01),
				_delay(_blips([1320.0, 990.0, 740.0], 0.028, 0.07), 0.03),
			]), 0.04, 1.4)
		"reload_in":  # fresh mag seated: a solid clack and a magnetic snap
			return _master(_mix([
				_tick(2900.0, 0.8),
				_sweep(0.06, 260.0, 140.0, 55.0, 0.55),
				_delay(_sweep(0.05, 1800.0, 3600.0, 50.0, 0.12), 0.006),
				_delay(_tick(5200.0, 0.3), 0.016),
			]), 0.04, 1.4)
		"boot":  # the ammo screen booting back up: a quick rising arpeggio
			return _master(_blips([990.0, 1320.0, 1760.0, 2640.0], 0.03, 0.22), 0.05, 1.0)
		"twirl":  # air around the gun as she spins it
			return _master(_whoosh(0.34, 0.35), 0.0, 1.0)
		"flourish":  # a quick bright glint at the end of a trick
			return _master(_mix([_ring([3135.0, 4700.0, 6270.0], 0.35, 14.0, 0.18), _sweep(0.12, 2600.0, 5200.0, 25.0, 0.05)]), 0.12, 1.0)
		"whack":  # palm smack on the slide to wake the old thing up
			return _master(_mix([
				_filter(_burst(0.06, 0.0008, 60.0, 0.8), "lp", 900.0),
				_sweep(0.09, 140.0, 70.0, 40.0, 0.7),
				_filter(_burst(0.15, 0.0003, 30.0, 0.12), "bp", 2300.0, 8.0),
			]), 0.1)
		"hit_body":  # meaty thwack into armour and cloth
			return _master(_mix([
				_filter(_burst(0.05, 0.0005, 70.0, 0.9), "lp", 1400.0),
				_sweep(0.07, 170.0, 70.0, 45.0, 0.6),
			]), 0.0)
		"hit_head":  # helmet cracking: a hard, bright tick with weight under it
			return _master(_mix([
				_filter(_burst(0.03, 0.0002, 140.0, 0.9), "hp", 3000.0),
				_filter(_burst(0.07, 0.0002, 60.0, 0.35), "bp", 4600.0, 6.0),
				_sweep(0.08, 200.0, 80.0, 40.0, 0.6),
			]), 0.05)
		"kill":  # a heavy confirm: sub drop and a crunch
			return _master(_mix([
				_sweep(0.3, 95.0, 38.0, 12.0, 1.0),
				_filter(_burst(0.25, 0.001, 18.0, 0.6), "lp", 700.0),
				_filter(_burst(0.06, 0.0003, 70.0, 0.35), "bp", 1800.0, 2.0),
			]), 0.12)
		"ricochet":
			return _master(_mix([_filter(_burst(0.03, 0.0003, 120.0, 0.5), "bp", 2500.0, 2.0), _sweep(0.22, 3300.0, 1500.0, 12.0, 0.12)]), 0.1)
		"impact":  # round hitting concrete
			return _master(_mix([_filter(_burst(0.06, 0.0003, 70.0, 0.7), "bp", 1500.0, 1.2), _sweep(0.05, 140.0, 80.0, 60.0, 0.35)]), 0.06)
		"knife_swish":  # the stiletto snapping out: a thin metallic shing and air
			return _master(_mix([
				_sweep(0.12, 3800.0, 7200.0, 22.0, 0.08),
				_ring([4180.0, 6650.0], 0.18, 20.0, 0.08),
				_filter(_whoosh(0.16, 0.3), "hp", 900.0),
			]), 0.02, 1.0)
		"knife_draw":  # drawn with a flip: a bright ringing shing over a quick whirr
			return _master(_mix([
				_filter(_whoosh(0.22, 0.25), "hp", 1200.0),
				_delay(_sweep(0.16, 2600.0, 6800.0, 14.0, 0.07), 0.12),
				_delay(_ring([3520.0, 5280.0, 7040.0], 0.45, 9.0, 0.09), 0.16),
			]), 0.06, 1.0)
		"knife_spin":  # spun round her fingers: a fluttering whirr
			return _master(_mix([_filter(_spin(0.6), "bp", 1600.0, 0.8), _filter(_whoosh(0.6, 0.15), "hp", 1500.0)]), 0.02, 1.0)
		"knife_catch":  # caught by the grip: a leather slap and a small ring
			return _master(_mix([
				_filter(_burst(0.04, 0.0005, 80.0, 0.7), "lp", 1100.0),
				_delay(_ring([4180.0], 0.25, 16.0, 0.05), 0.005),
			]), 0.04)
		"knife_hit":  # blade punching through cloth and plate
			return _master(_mix([
				_filter(_burst(0.04, 0.0003, 90.0, 0.8), "bp", 2400.0, 1.5),
				_sweep(0.06, 190.0, 80.0, 50.0, 0.5),
				_delay(_filter(_burst(0.05, 0.001, 60.0, 0.3), "lp", 800.0), 0.02),
			]), 0.02)
		"grunt_shot":  # enemy rifle: thinner and drier than Eco's pistol
			return _master(_mix([
				_filter(_burst(0.03, 0.0003, 150.0, 0.8), "hp", 2200.0),
				_filter(_burst(0.1, 0.001, 45.0, 0.7), "bp", 1100.0, 0.9),
				_sweep(0.08, 150.0, 70.0, 40.0, 0.4),
			]), 0.15)
		# Titan weapons
		"xo16":
			return _mix([_sweep(0.08, 140.0, 55.0, 30.0, 0.9), _noise(0.05, 55.0, 0.6, 0.1), _ring([720.0], 0.05, 60.0, 0.15)])
		"xo16_spin":
			return _spin(0.45)
		"tracker":
			return _reverb(_mix([_sweep(0.45, 95.0, 28.0, 7.0, 1.0), _noise(0.25, 14.0, 0.8, 0.04), _ring([410.0, 615.0], 0.3, 10.0, 0.12)]), 0.2)
		"tracker_boom":
			return _mix([_noise(0.7, 6.0, 0.9, 0.02), _sweep(0.5, 70.0, 25.0, 6.0, 0.8)])
		"splitter":
			return _zap(0.11)
		"scrap":
			return _mix([_sweep(0.1, 120.0, 50.0, 26.0, 0.8), _noise(0.07, 40.0, 0.6, 0.12), _crackle(0.08, 6, 0.4), _ring([530.0, 870.0], 0.12, 22.0, 0.2)])
		"scrap_jam":
			return _mix([_ring([300.0, 470.0], 0.12, 30.0, 0.6), _delay(_noise(0.4, 6.0, 0.25, 0.7), 0.06), _delay(_crackle(0.25, 18, 0.5), 0.05)])
		"titan_hit":
			return _mix([_ring([480.0, 1130.0, 1720.0], 0.18, 18.0, 0.4), _noise(0.04, 90.0, 0.5, 0.2)])
	push_warning("SFX: no recipe for %s" % id)
	return PackedFloat32Array([0.0])


# --- Building blocks ----------------------------------------------------------

## The pistol shot. `weight` scales the low end.
static func _gunshot(weight: float) -> PackedFloat32Array:
	var dry := _mix([
		_filter(_burst(0.03, 0.0003, 170.0, 1.0), "hp", 1800.0),          # crack
		_filter(_burst(0.14, 0.0008, 34.0, 0.9), "lp", 2600.0),           # blast
		_filter(_burst(0.18, 0.001, 22.0, 0.9 * weight), "lp", 200.0),     # body
		_sweep(0.18, 115.0, 42.0, 24.0, 0.9 * weight),                     # sub thump
		_delay(_clack(3000.0, 260.0, 0.28), 0.04),                         # slide cycling
	])
	return _master(dry, 0.22)


## Eco's suppressed shot. The suppressor eats the crack and the boom, so what
## is left is a muffled pressure pop, gas hissing out of the baffles, and the
## slide: a crisp metal clack back and a clack home. `last` locks the slide
## open and adds the screen's empty chirp.
static func _suppressed(last: bool) -> PackedFloat32Array:
	var layers := [
		_filter(_filter(_burst(0.08, 0.0006, 62.0, 1.7), "lp", 1100.0), "hp", 150.0),  # thup
		_sweep(0.09, 190.0, 95.0, 40.0, 0.3),                                         # body
		_filter(_burst(0.13, 0.004, 34.0, 0.42), "bp", 1700.0, 0.8),                 # pfft
		_filter(_burst(0.05, 0.002, 60.0, 0.08), "hp", 6500.0),                      # gas air
		_delay(_tick(3600.0, 0.55), 0.004),                                          # slide back
		_delay(_ring([2960.0, 4430.0, 6180.0], 0.07, 75.0, 0.12), 0.004),            # steel ring
		_sweep(0.07, 5400.0, 2700.0, 50.0, 0.05),                                    # coil whine
	]
	if last:
		layers.append(_delay(_tick(2100.0, 0.75), 0.05))   # slide locks open, heavier
		layers.append(_delay(_sweep(0.05, 320.0, 180.0, 60.0, 0.2), 0.05))
		layers.append(_delay(_blips([1480.0, 990.0], 0.05, 0.09), 0.1))
	else:
		layers.append(_delay(_tick(2700.0, 0.42), 0.038))  # slide home
		layers.append(_delay(_sweep(0.04, 240.0, 150.0, 70.0, 0.12), 0.038))
	return _master(_mix(layers), 0.07, 1.3)


## A crisp, tight metal click centred on `freq`.
static func _tick(freq: float, amp: float) -> PackedFloat32Array:
	return _mix([
		_filter(_burst(0.025, 0.0001, 260.0, amp), "bp", freq, 5.0),
		_filter(_burst(0.008, 0.0001, 700.0, amp * 0.5), "hp", 6000.0),
	])


## Clean sine beeps one after another, like a small screen chirping.
static func _blips(freqs: Array, each: float, amp: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f in freqs:
		var n := int(each * RATE)
		for i in n:
			var t := float(i) / RATE
			var env := minf(t * 800.0, 1.0) * minf((each - t) * 400.0, 1.0)
			out.append(sin(TAU * f * t) * amp * env)
	return out


## Air rushing past: noise in a band that swells and fades, a few passes.
static func _whoosh(length: float, amp: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var raw := _burst(length, 0.0, 0.0, 1.0)
	var low := _filter(raw, "bp", 700.0, 0.9)
	var high := _filter(raw, "bp", 1900.0, 1.2)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / n
		var swell := pow(sin(PI * t), 2.0) * (0.6 + 0.4 * sin(TAU * 3.0 * t))
		out[i] = (low[i] * (1.0 - t) + high[i] * t) * swell * amp
	return out


## A short mechanical impact: a resonant click plus an optional low thunk.
static func _clack(freq: float, thunk: float, amp: float) -> PackedFloat32Array:
	var layers := [
		_filter(_burst(0.03, 0.0002, 180.0, amp), "bp", freq, 3.0),
		_filter(_burst(0.01, 0.0001, 500.0, amp * 0.6), "hp", 4000.0),
	]
	if thunk > 0.0:
		layers.append(_sweep(0.05, thunk, thunk * 0.6, 60.0, amp * 0.6))
	return _mix(layers)


## Saturates for punch, adds a short room tail, and normalizes.
static func _master(dry: PackedFloat32Array, room: float, drive := 1.8) -> PackedFloat32Array:
	var out := dry
	for i in out.size():
		out[i] = tanh(out[i] * drive) / tanh(drive)
	if room > 0.0:
		out = _reverb(out, room)
	var peak := 0.0
	for v in out:
		peak = maxf(peak, absf(v))
	if peak > 0.0:
		for i in out.size():
			out[i] *= 0.95 / peak
	return out


## Noise with a linear attack and exponential decay.
static func _burst(length: float, attack: float, decay: float, amp: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / maxf(attack, 0.00001), 1.0) * exp(-decay * t)
		out[i] = _rng.randf_range(-1.0, 1.0) * amp * env
	return out


## RBJ biquad: "lp", "hp" or "bp" (constant peak gain).
static func _filter(s: PackedFloat32Array, kind: String, freq: float, q := 0.707) -> PackedFloat32Array:
	var w := TAU * freq / RATE
	var cw := cos(w)
	var alpha := sin(w) / (2.0 * q)
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	match kind:
		"lp":
			b0 = (1.0 - cw) * 0.5
			b1 = 1.0 - cw
			b2 = b0
		"hp":
			b0 = (1.0 + cw) * 0.5
			b1 = -(1.0 + cw)
			b2 = b0
		_:
			b0 = alpha
			b2 = -alpha
	var a0 := 1.0 + alpha
	var a1 := -2.0 * cw
	var a2 := 1.0 - alpha
	var out := PackedFloat32Array()
	out.resize(s.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in s.size():
		var x := s[i]
		var y := (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[i] = y
	return out


## Small, dark room: four damped combs and two allpasses (Schroeder).
static func _reverb(s: PackedFloat32Array, mix: float) -> PackedFloat32Array:
	var tail := int(0.45 * RATE)
	var n := s.size() + tail
	var wet := PackedFloat32Array()
	wet.resize(n)
	for delay_ms in [29.7, 37.1, 41.1, 43.7]:
		var d := int(delay_ms * RATE / 1000.0)
		var buf := PackedFloat32Array()
		buf.resize(n)
		var low := 0.0
		for i in n:
			var x := s[i] if i < s.size() else 0.0
			var fb := buf[i - d] if i >= d else 0.0
			low += (fb - low) * 0.45
			buf[i] = x + low * 0.72
			wet[i] += buf[i] * 0.25
	for delay_ms in [5.0, 1.7]:
		var d := int(delay_ms * RATE / 1000.0)
		var buf := PackedFloat32Array()
		buf.resize(n)
		for i in n:
			var prev := buf[i - d] if i >= d else 0.0
			buf[i] = wet[i] + prev * 0.5
			wet[i] = prev - buf[i] * 0.5
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = (s[i] if i < s.size() else 0.0) + wet[i] * mix
	return out


## White noise with an exponential decay; `tone` 0 = full band, 1 = only highs.
static func _noise(length: float, decay: float, amp: float, tone: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	for i in n:
		var w := _rng.randf_range(-1.0, 1.0)
		low += (w - low) * 0.25
		var s := lerpf(low * 2.0, w - low, tone)
		out[i] = s * amp * exp(-decay * float(i) / RATE)
	return out


## A sine whose pitch slides from f0 to f1: the body of every gunshot.
static func _sweep(length: float, f0: float, f1: float, decay: float, amp: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(f0, f1, sqrt(t)) / RATE
		out[i] = sin(phase) * amp * exp(-decay * float(i) / RATE)
	return out


## Inharmonic partials decaying together: metal ringing.
static func _ring(freqs: Array, length: float, decay: float, amp: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for f in freqs:
			s += sin(TAU * f * t)
		out[i] = s / freqs.size() * amp * exp(-decay * t)
	return out


static func _square(length: float, freq: float, amp: float, start := 0.0) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0) * amp * minf(1.0, (length - t) * 60.0)
	return _delay(out, start)


## Sparse random clicks.
static func _crackle(length: float, count: int, amp: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for c in count:
		var at := _rng.randi_range(0, n - 40)
		var a := amp * _rng.randf_range(0.3, 1.0)
		for k in 30:
			out[at + k] += _rng.randf_range(-1.0, 1.0) * a * exp(-k * 0.2)
	return out


## Chaingun barrels winding up: a buzzy saw rising in pitch.
static func _spin(length: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += (40.0 + 180.0 * t * t) / RATE
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		out[i] = saw * 0.22 * minf(t * 6.0, 1.0) * minf((1.0 - t) * 12.0, 1.0)
	return out


## Splitter pulse: an FM chirp with a fast wobble.
static func _zap(length: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(1500.0, 520.0, t / length) + sin(TAU * 70.0 * t) * 160.0
		phase += TAU * f / RATE
		out[i] = (sin(phase) + 0.4 * sin(phase * 2.01)) * 0.4 * exp(-18.0 * t)
	return out


static func _delay(s: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var pad := PackedFloat32Array()
	pad.resize(int(seconds * RATE))
	pad.append_array(s)
	return pad


static func _mix(layers: Array) -> PackedFloat32Array:
	var n := 0
	for l in layers:
		n = maxi(n, l.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for l in layers:
		for i in l.size():
			out[i] += l[i]
	return out


## Soft-clips and packs 16-bit mono PCM.
static func _to_wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		var v := tanh(s[i] * 1.2)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
