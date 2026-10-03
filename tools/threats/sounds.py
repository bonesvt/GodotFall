"""Synthesizes the sounds of the Choir and the wildlife past the border into
assets/audio/sfx/<id>.wav (scripts/sfx.gd plays a file there in place of its
built-in recipes). Plain Python, no libraries:

    python3 tools/threats/sounds.py

The Choir never speaks: everything they do is a chord. Their tell is a rising
chord, the Hush's needle rifle a glassy whip, a hit a porcelain crack, the
Cantor's blast a sub boom under the chord, the Seraph's song two high voices.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parents[2] / "assets/audio/sfx"
rnd = random.Random(7)


def n(sec):
    return int(sec * RATE)


def silence(sec):
    return [0.0] * n(sec)


def mix(*layers):
    out = [0.0] * max(len(l) for l in layers)
    for l in layers:
        for i, v in enumerate(l):
            out[i] += v
    return out


def env(s, attack, release, curve=1.0):
    a, r, L = n(attack), n(release), len(s)
    out = []
    for i, v in enumerate(s):
        g = 1.0
        if a and i < a:
            g = i / a
        if r and i > L - r:
            g *= max(0.0, (L - i) / r) ** curve
        out.append(v * g)
    return out


def decay(s, rate):
    return [v * math.exp(-rate * i / RATE) for i, v in enumerate(s)]


def tone(sec, f0, f1=None, amp=1.0, shape="sine", vib=0.0, vib_rate=5.0, harm=(1.0,)):
    """A voice gliding from f0 to f1 (exponentially), with vibrato and harmonics."""
    f1 = f1 or f0
    L = n(sec)
    out, ph = [], 0.0
    for i in range(L):
        t = i / L
        f = f0 * (f1 / f0) ** t
        f *= 1.0 + vib * math.sin(2 * math.pi * vib_rate * i / RATE)
        ph += 2 * math.pi * f / RATE
        if shape == "saw":
            v = sum(h / (k + 1) * math.sin(ph * (k + 1)) for k, h in enumerate(harm))
        else:
            v = sum(h * math.sin(ph * (k + 1)) for k, h in enumerate(harm))
        out.append(v * amp)
    return out


def noise(sec, amp=1.0):
    return [rnd.uniform(-1, 1) * amp for _ in range(n(sec))]


def lowpass(s, f):
    a = 1 - math.exp(-2 * math.pi * f / RATE)
    y, out = 0.0, []
    for v in s:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(s, f):
    lp = lowpass(s, f)
    return [v - l for v, l in zip(s, lp)]


def bandpass(s, f):
    return lowpass(highpass(s, f * 0.7), f * 1.4)


def ring(sec, freqs, rate, amp=1.0):
    return decay(mix(*[tone(sec, f, amp=amp / len(freqs)) for f in freqs]), rate)


def chord(sec, root, rise=1.0, amp=0.3, voices=(1.0, 1.1892, 1.4983, 2.0), vib=0.006):
    """A minor-ish choral chord gliding up by `rise` (ratio)."""
    layers = []
    for k, r in enumerate(voices):
        for det in (0.997, 1.003):
            layers.append(tone(sec, root * r * det, root * r * det * rise, amp=amp / len(voices) / 2,
                               shape="saw", vib=vib, vib_rate=4.5 + k * 0.7, harm=(1, 0.5, 0.25, 0.12)))
    return lowpass(mix(*layers), 2600)


def reverb(s, mix_amt=0.3, taps=((0.031, 0.5), (0.047, 0.4), (0.071, 0.3), (0.113, 0.22), (0.167, 0.15))):
    L = len(s) + n(0.6)
    out = s + [0.0] * (L - len(s))
    wet = [0.0] * L
    for d, g in taps:
        k = n(d)
        for i in range(len(s)):
            wet[i + k] += s[i] * g
    wet = lowpass(wet, 3000)
    return [o + w * mix_amt for o, w in zip(out, wet)]


def normalize(s, peak=0.9):
    m = max(abs(v) for v in s) or 1.0
    return [math.tanh(v / m * 1.2) * peak for v in s]


def save(name, s):
    s = normalize(s)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in s))
    print("wrote", name, round(len(s) / RATE, 2), "s")


def crack(sec=0.12):
    return mix(decay(highpass(noise(sec), 2500), 40), ring(sec * 3, [2130, 3410, 5230, 6870], 18, 0.6))


def main():
    # The Choir's tell: a chord swelling and rising a fourth.
    save("choir_chord", reverb(env(chord(1.4, 196, rise=1.335), 0.5, 0.15, 0.5), 0.35))
    # Hush needle rifle: glassy whip and a ring.
    whip = decay(tone(0.18, 3800, 900, amp=0.6), 18)
    click = decay(highpass(noise(0.03), 4000), 120)
    save("choir_needle", reverb(mix(click, whip, ring(0.5, [1760, 2637, 3520], 9, 0.4),
                                    decay(lowpass(noise(0.12, 0.6), 800), 30)), 0.25))
    # Hit: porcelain crack and a breath of the chord.
    for k, root in enumerate((220, 247, 196)):
        save(f"choir_hurt_{k + 1}", reverb(mix(crack(), env(chord(0.45, root, rise=0.94, amp=0.18), 0.02, 0.3)), 0.3))
    # Death: crack, then the chord falling away.
    save("choir_die", reverb(mix(crack(0.2), env(chord(1.4, 233, rise=0.6, amp=0.3), 0.05, 1.0, 1.5)), 0.4))
    # Seraph song: two high voices with a tremolo, swelling.
    song = mix(tone(2.0, 880, 990, amp=0.3, vib=0.012, vib_rate=6.5, harm=(1, 0.3, 0.1)),
               tone(2.0, 1318, 1480, amp=0.25, vib=0.015, vib_rate=7.1, harm=(1, 0.2)),
               chord(2.0, 440, rise=1.12, amp=0.15))
    trem = [v * (0.75 + 0.25 * math.sin(2 * math.pi * 9 * i / RATE)) for i, v in enumerate(song)]
    save("seraph_song", reverb(env(trem, 0.25, 0.7), 0.45))
    # Cantor blast: sub boom, pressure crack, the chord torn off.
    boom = decay(tone(1.0, 110, 38, amp=1.0), 4)
    save("cantor_blast", reverb(mix(boom, decay(lowpass(noise(0.6, 0.8), 600), 6),
                                    env(chord(0.5, 98, rise=0.8, amp=0.4), 0.0, 0.4)), 0.3))
    # Hound pounce: a metallic screech.
    fm = []
    ph = mph = 0.0
    L = n(0.5)
    for i in range(L):
        t = i / L
        mph += 2 * math.pi * 310 * (1 + t) / RATE
        ph += 2 * math.pi * (900 + 1400 * t + 600 * math.sin(mph)) / RATE
        fm.append(math.sin(ph) * 0.6)
    save("hound_screech", reverb(env(mix(fm, bandpass(noise(0.5, 0.4), 3000)), 0.02, 0.25), 0.25))
    # Glassback: a deep whale-like moan, and the bellow when it bolts.
    moan = tone(2.4, 92, 74, amp=0.7, vib=0.02, vib_rate=2.5, harm=(1, 0.6, 0.45, 0.3, 0.2))
    save("glassback_low", reverb(env(lowpass(moan, 900), 0.6, 1.0), 0.4))
    bellow = tone(1.4, 120, 160, amp=0.8, vib=0.03, vib_rate=7, harm=(1, 0.7, 0.5, 0.35, 0.25, 0.15), shape="saw")
    save("glassback_stampede", reverb(env(mix(lowpass(bellow, 1200), lowpass(noise(1.4, 0.5), 200)), 0.08, 0.6), 0.35))
    # Lampjaw: a wet snap.
    save("lampjaw_snap", reverb(mix(decay(bandpass(noise(0.25), 1800), 22), decay(tone(0.3, 140, 60), 14),
                                    decay(highpass(noise(0.05), 3000), 90)), 0.2))
    # Quillcat: rattling hiss before the pounce, a yowl when the pack rouses.
    hiss = highpass(noise(0.7, 0.8), 3000)
    hiss = [v * (0.6 + 0.4 * math.sin(2 * math.pi * 32 * i / RATE)) for i, v in enumerate(hiss)]
    save("quillcat_hiss", env(hiss, 0.05, 0.3))
    yowl = []
    ph = 0.0
    L = n(1.0)
    for i in range(L):
        t = i / L
        f = 380 + 380 * math.sin(math.pi * t) - 60 * t
        f *= 1 + 0.03 * math.sin(2 * math.pi * 6 * i / RATE)
        ph += 2 * math.pi * f / RATE
        yowl.append(sum(h * math.sin(ph * (k + 1)) for k, h in enumerate((1, 0.6, 0.4, 0.25, 0.15))) * 0.5)
    save("quillcat_yowl", reverb(env(bandpass(yowl, 1100), 0.05, 0.4), 0.3))
    # Bonepickers: a burst of clicks.
    chit = silence(0.4)
    for k in range(14):
        at = n(rnd.uniform(0.0, 0.35))
        c = decay(bandpass(noise(0.02), rnd.uniform(2500, 4500)), 200)
        for i, v in enumerate(c):
            if at + i < len(chit):
                chit[at + i] += v
    save("picker_chitter", chit)
    # Veil Ray: a soft rising whistle.
    save("veilray_call", reverb(env(tone(1.2, 760, 1180, amp=0.5, vib=0.01, vib_rate=4, harm=(1, 0.15)), 0.3, 0.6), 0.5))


main()
