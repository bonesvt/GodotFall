#!/usr/bin/env python3
"""Synthesises the grunt's taunt sounds into assets/sounds/grunt/, all run
through a tinny helmet-speaker filter:
  wolf_whistle.wav   the two-note "wheet-wheeoo"
  laugh.wav          a braying "HA-HA-HA-ha"
  kiss.wav           a loud smooch
Needs numpy only.

    python3 tools/grunt/make_sounds.py"""
import wave
from pathlib import Path

import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / "assets/sounds/grunt"
rng = np.random.default_rng(3)


def t_axis(sec):
    return np.arange(int(sec * RATE)) / RATE


def env(n, attack=0.02, release=0.08):
    e = np.ones(n)
    a, r = int(attack * RATE), int(release * RATE)
    e[:a] = np.linspace(0, 1, a)
    e[n - r:] = np.linspace(1, 0, r)
    return e


def sweep(freqs, sec, vibrato=0.0):
    """Sine whose pitch follows the breakpoints in `freqs` over `sec` seconds."""
    t = t_axis(sec)
    f = np.interp(t, np.linspace(0, sec, len(freqs)), freqs)
    f = f * (1 + vibrato * np.sin(2 * np.pi * 6 * t))
    return np.sin(2 * np.pi * np.cumsum(f) / RATE)


def biquad_bandpass(x, f0, q):
    w = 2 * np.pi * f0 / RATE
    alpha = np.sin(w) / (2 * q)
    b = np.array([alpha, 0, -alpha]) / (1 + alpha)
    a = np.array([1, -2 * np.cos(w) / (1 + alpha), (1 - alpha) / (1 + alpha)])
    y = np.zeros_like(x)
    for i in range(len(x)):
        y[i] = b[0] * x[i] + b[1] * x[i - 1] + b[2] * x[i - 2] - a[1] * y[i - 1] - a[2] * y[i - 2]
    return y


def helmet(x):
    """Tinny speaker: band-limit, a touch of grit, soft clip."""
    y = biquad_bandpass(x, 1500, 0.6) * 3.0 + x * 0.25
    y = np.round(y * 48) / 48
    return np.tanh(y * 1.6) * 0.8


def wolf_whistle():
    a = sweep([900, 2700], 0.22) * env(int(0.22 * RATE), 0.03, 0.05)
    gap = np.zeros(int(0.12 * RATE))
    b = sweep([900, 2500, 2400, 900], 0.75, 0.01) * env(int(0.75 * RATE), 0.03, 0.2)
    x = np.concatenate([a, gap, b])
    return helmet(x * 0.8 + rng.normal(0, 0.03, len(x)))


def laugh():
    parts = []
    for i, (pitch, sec, loud) in enumerate(((150, 0.16, 1.0), (145, 0.15, 1.0), (140, 0.15, 0.95),
                                            (125, 0.24, 0.8))):
        t = t_axis(sec)
        f = pitch * (1.0 - 0.15 * t / sec)
        saw = (np.cumsum(f) / RATE) % 1.0 * 2 - 1
        voice = biquad_bandpass(saw, 750, 4) + 0.6 * biquad_bandpass(saw, 1150, 5)
        breath = biquad_bandpass(rng.normal(0, 1, len(t)), 1800, 1.5) * 0.3
        h = np.exp(-((t - 0.02) / 0.02) ** 2) * rng.normal(0, 1, len(t)) * 0.5  # the "h"
        parts.append((voice * 2.5 + breath + h) * env(len(t), 0.01, 0.06) * loud)
        parts.append(np.zeros(int(0.05 * RATE)))
    return helmet(np.concatenate(parts) * 0.7)


def kiss():
    t = t_axis(0.35)
    pop = np.exp(-((t - 0.05) / 0.006) ** 2) * 2.0
    squeak = sweep([1800, 3200, 2600], 0.35) * np.exp(-((t - 0.12) / 0.05) ** 2)
    return helmet(pop * rng.normal(0, 1, len(t)) * 0.5 + squeak * 0.6)


def save(name, x):
    OUT.mkdir(parents=True, exist_ok=True)
    x = np.clip(x / max(np.abs(x).max(), 1e-6) * 0.9, -1, 1)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print("wrote", OUT / name)


save("wolf_whistle.wav", wolf_whistle())
save("laugh.wav", laugh())
save("kiss.wav", kiss())
