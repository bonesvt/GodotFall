extends RefCounted
## Animal Crossing-style babble for the people in the hub: no words, one
## quick sung syllable per letter of the line, each at a pitch picked from the
## letter (so the same line always sounds the same), in that speaker's voice.
## Built on the fly as a short AudioStreamWAV; npc_talk.gd plays it and types
## the caption out in time with it.

const RATE := 16000

## speaker: base pitch (Hz), how far pitches wander (semitones), syllables a
## second, brightness (upper harmonics), breathiness (noise), loudness
const VOICES := {
	"mom": {"pitch": 300.0, "spread": 5.0, "rate": 15.0, "bright": 0.35, "breath": 0.05, "gain": 0.5},
	"ophelia": {"pitch": 235.0, "spread": 2.0, "rate": 12.0, "bright": 0.2, "breath": 0.12, "gain": 0.42},
	"biggie": {"pitch": 125.0, "spread": 4.0, "rate": 12.5, "bright": 0.55, "breath": 0.08, "gain": 0.55},
	"pip": {"pitch": 265.0, "spread": 3.0, "rate": 14.0, "bright": 0.25, "breath": 0.1, "gain": 0.46},
	"eco": {"pitch": 370.0, "spread": 7.0, "rate": 17.0, "bright": 0.3, "breath": 0.04, "gain": 0.45},
	# the people of Solace (townsfolk.gd)
	"town_pell": {"pitch": 270.0, "spread": 6.0, "rate": 15.5, "bright": 0.4, "breath": 0.05, "gain": 0.5},
	"town_kit": {"pitch": 330.0, "spread": 7.0, "rate": 18.5, "bright": 0.3, "breath": 0.03, "gain": 0.45},
	"town_wren": {"pitch": 290.0, "spread": 4.0, "rate": 14.0, "bright": 0.25, "breath": 0.08, "gain": 0.45},
	"town_mira": {"pitch": 250.0, "spread": 3.5, "rate": 13.5, "bright": 0.3, "breath": 0.06, "gain": 0.48},
	"town_rosa": {"pitch": 320.0, "spread": 5.0, "rate": 13.0, "bright": 0.3, "breath": 0.1, "gain": 0.45},
	"town_tobin": {"pitch": 115.0, "spread": 4.0, "rate": 11.0, "bright": 0.45, "breath": 0.14, "gain": 0.55},
	"town_dez": {"pitch": 140.0, "spread": 5.0, "rate": 15.0, "bright": 0.5, "breath": 0.06, "gain": 0.52},
	"town_harl": {"pitch": 105.0, "spread": 3.0, "rate": 12.5, "bright": 0.6, "breath": 0.07, "gain": 0.58},
	"town_jun": {"pitch": 160.0, "spread": 6.0, "rate": 17.0, "bright": 0.4, "breath": 0.05, "gain": 0.5},
	"town_bram": {"pitch": 98.0, "spread": 4.0, "rate": 13.5, "bright": 0.55, "breath": 0.05, "gain": 0.58},
}
## A pentatonic scale (semitones), so runs of syllables sound sung, not random.
const SCALE := [0, 2, 4, 7, 9, 12, -3, -5]
## Vowel colour per vowel: [second harmonic, third harmonic].
const VOWELS := {"a": [0.7, 0.45], "e": [0.45, 0.6], "i": [0.25, 0.7], "o": [0.8, 0.2], "u": [0.6, 0.1], "y": [0.3, 0.6]}


## The babble for `text` in `speaker`'s voice, and how long each character of
## the text takes (for typing the caption out in time): {"stream", "times"}.
static func make(speaker: String, text: String) -> Dictionary:
	var v: Dictionary = VOICES.get(speaker, VOICES["mom"])
	var syl := 1.0 / float(v["rate"])
	var data := PackedByteArray()
	var times := PackedFloat32Array()
	var t := 0.0
	var rising := text.strip_edges().ends_with("?")
	var word_start := true
	var letters := 0
	for c in text:
		times.append(t)
		var low := c.to_lower()
		if low >= "a" and low <= "z":
			var semis: float = SCALE[(low.unicode_at(0) * 7 + letters * 3) % SCALE.size()] * float(v["spread"]) / 7.0
			if word_start:
				semis += 1.0   # a little lift at the start of each word
			if rising and t > 0.0:
				semis += 2.0 * clampf(float(letters) / maxf(1.0, float(text.length())), 0.0, 1.0)
			var f: float = float(v["pitch"]) * pow(2.0, semis / 12.0)
			var vowel: Array = VOWELS.get(low, VOWELS.get(_nearest_vowel(text, letters), [0.5, 0.3]))
			var dur := syl * (1.15 if VOWELS.has(low) else 0.85)
			data.append_array(_syllable(f, dur, vowel, v, not VOWELS.has(low)))
			t += dur
			letters += 1
			word_start = false
		elif c == " ":
			data.append_array(_silence(syl * 0.35))
			t += syl * 0.35
			word_start = true
		elif c in ".!?":
			data.append_array(_silence(syl * 2.2))
			t += syl * 2.2
			word_start = true
		elif c in ",;:-":
			data.append_array(_silence(syl * 1.2))
			t += syl * 1.2
			word_start = true
	times.append(t)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return {"stream": wav, "times": times, "length": t}


static func _nearest_vowel(text: String, i: int) -> String:
	var s := text.to_lower()
	for k in range(i, s.length()):
		if VOWELS.has(s[k]):
			return s[k]
	return "a"


## One syllable: a quick swell and fall of a buzzy tone with the vowel's
## harmonics, a tick of noise at the front for consonants, pitch bending up
## into it like a sung blip.
static func _syllable(f: float, dur: float, vowel: Array, v: Dictionary, consonant: bool) -> PackedByteArray:
	var n := int(dur * RATE)
	var out := PackedByteArray()
	out.resize(n * 2)
	var phase := 0.0
	var rnd := int(f * 13.0) ^ n
	var bright: float = v["bright"]
	var breath: float = v["breath"]
	var gain: float = v["gain"]
	for i in n:
		var x := float(i) / float(n)
		var env := minf(1.0, x / 0.12) * pow(1.0 - x, 1.6)
		var bend := 1.0 + 0.06 * (1.0 - minf(1.0, x / 0.3))   # starts a touch sharp, settles
		phase += TAU * f * bend / RATE
		var s: float = sin(phase) + vowel[0] * sin(phase * 2.0) * (0.5 + bright) + vowel[1] * sin(phase * 3.0) * bright
		s += bright * 0.25 * sin(phase * 4.0)
		rnd = (rnd * 1103515245 + 12345) & 0x7fffffff
		var noise := float(rnd) / float(0x7fffffff) * 2.0 - 1.0
		s += noise * (breath + (0.6 * maxf(0.0, 1.0 - x / 0.15) if consonant else 0.0))
		out.encode_s16(i * 2, int(clampf(s * env * gain * 0.7, -1.0, 1.0) * 32767.0))
	return out


static func _silence(dur: float) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(int(dur * RATE) * 2)   # zeroed
	return out
