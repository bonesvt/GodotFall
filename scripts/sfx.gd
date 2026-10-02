extends RefCounted
## Procedural sound effects. Every sound is synthesized from noise and simple
## oscillators the first time it plays, then cached, so the game ships no audio
## files. The palette is crunchy on purpose (22 kHz, light bit-crush) to sit
## with the PS2 look.
##
##   SFX.play(self, "pistol")                 # flat, follows the listener
##   SFX.play_at(parent, pos, "ricochet")     # positional, frees itself

const RATE := 22050

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


static func stream(id: String) -> AudioStreamWAV:
	if not _cache.has(id):
		_cache[id] = _to_wav(_synth(id))
	return _cache[id]


# --- Recipes ------------------------------------------------------------------

static func _synth(id: String) -> PackedFloat32Array:
	_rng.seed = hash(id)
	match id:
		# Eco's pistol: a sharp crack, a chesty thump, and the ring of a frame
		# that has been dropped, bent back and taped together more than once.
		"pistol":
			return _mix([
				_noise(0.05, 30.0, 0.9, 0.0),
				_sweep(0.14, 170.0, 48.0, 22.0, 0.9),
				_ring([2350.0, 3170.0, 4410.0], 0.32, 9.0, 0.16),
			])
		"pistol_last":  # empty-mag ping on the last round
			return _mix([_synth("pistol"), _ring([3900.0, 5200.0], 0.45, 7.0, 0.3)])
		"dry_click":
			return _mix([_noise(0.02, 160.0, 0.5, 0.6), _ring([1800.0], 0.04, 80.0, 0.3)])
		"spark":  # crackle from the dead smart-lock module
			return _crackle(0.22, 46, 0.6)
		"lock_err":  # the smart-lock trying, and failing, to lock
			return _mix([_square(0.06, 1320.0, 0.18), _square(0.09, 880.0, 0.18, 0.07), _square(0.12, 620.0, 0.16, 0.17)])
		"reload_out":
			return _mix([_noise(0.04, 90.0, 0.5, 0.3), _ring([620.0, 1240.0], 0.08, 40.0, 0.4)])
		"reload_in":
			return _mix([_noise(0.03, 120.0, 0.6, 0.4), _ring([980.0, 1470.0], 0.07, 45.0, 0.5)])
		"whack":  # palm smack on the slide to get the old thing running again
			return _mix([_sweep(0.09, 260.0, 90.0, 35.0, 0.8), _noise(0.03, 110.0, 0.5, 0.2), _ring([1650.0, 2480.0], 0.2, 16.0, 0.22)])
		"hit_body":
			return _mix([_sweep(0.06, 420.0, 160.0, 50.0, 0.6), _noise(0.03, 120.0, 0.35, 0.3)])
		"hit_head":
			return _mix([_ring([1760.0, 2640.0], 0.22, 14.0, 0.5), _noise(0.02, 200.0, 0.3, 0.5)])
		"kill":  # two-note sting, rising
			return _mix([_ring([1320.0, 1980.0], 0.12, 18.0, 0.35), _delay(_ring([1760.0, 2640.0], 0.3, 10.0, 0.4), 0.07)])
		"ricochet":
			return _mix([_noise(0.025, 120.0, 0.4, 0.5), _sweep(0.2, 3400.0, 1300.0, 12.0, 0.18)])
		"impact":
			return _mix([_noise(0.05, 70.0, 0.45, 0.15), _sweep(0.05, 300.0, 120.0, 60.0, 0.3)])
		"grunt_shot":  # enemy rifle: thinner and buzzier than Eco's pistol
			return _mix([_noise(0.08, 28.0, 0.6, 0.25), _square(0.07, 210.0, 0.25)])
		# Titan weapons
		"xo16":
			return _mix([_sweep(0.08, 140.0, 55.0, 30.0, 0.9), _noise(0.05, 55.0, 0.6, 0.1), _ring([720.0], 0.05, 60.0, 0.15)])
		"xo16_spin":
			return _spin(0.45)
		"tracker":
			return _mix([_sweep(0.45, 95.0, 28.0, 7.0, 1.0), _noise(0.25, 14.0, 0.8, 0.04), _ring([410.0, 615.0], 0.3, 10.0, 0.12)])
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


## Soft-clips, bit-crushes to ~10 bits and packs 16-bit mono PCM.
static func _to_wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		var v := tanh(s[i] * 1.2)
		v = roundf(v * 512.0) / 512.0
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
