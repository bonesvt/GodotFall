"""Voices every line in dialogue/npc/*.txt with Piper text-to-speech, one
.ogg per line in assets/audio/voice/npc/, named by the SHA-1 of "speaker|line"
(npc_talk.gd looks them up the same way, so edits only need this run again).

    python tools/npc/voices.py <en_US-libritts_r-medium.onnx> [repo root]

Needs `pip install piper-tts` and ffmpeg. The voice model is LibriTTS-R
(CC BY 4.0), fine-tuned by the Piper project; download it from
huggingface.co/rhasspy/piper-voices (en/en_US/libritts_r/medium). Each
character is one of its 904 speakers, picked by pitch, then shaped a little:
- mom: a warm, mid voice, unhurried
- ophelia: lower and flat (little pitch movement), slow
- biggie: the deepest speaker, pitched down further and slowed, a little gravel
- eco: brighter, quicker, more expressive
Lines already voiced are skipped; stale files (lines that no longer exist) are removed.
"""
import hashlib
import os
import re
import subprocess
import sys
import tempfile
import wave

import numpy as np
from piper import PiperVoice, SynthesisConfig

MODEL = sys.argv[1]
ROOT = sys.argv[2] if len(sys.argv) > 2 else os.getcwd()
OUT = os.path.join(ROOT, "assets", "audio", "voice", "npc")

# speaker id, length scale (higher = slower), noise (expressiveness), noise_w
# (rhythm variation), and an ffmpeg pitch factor (below 1 = deeper)
VOICES = {
    "mom": (366, 1.05, 0.62, 0.75, 1.0),
    "ophelia": (654, 1.12, 0.35, 0.35, 0.96),
    "biggie": (564, 1.15, 0.7, 0.9, 0.9),
    "eco": (450, 0.94, 0.75, 0.85, 1.0),
}


def lines():
    for path in sorted(os.listdir(os.path.join(ROOT, "dialogue", "npc"))):
        if not path.endswith(".txt"):
            continue
        for raw in open(os.path.join(ROOT, "dialogue", "npc", path), encoding="utf-8"):
            raw = raw.strip()
            m = re.match(r"^(\w+):\s*(.+)$", raw)
            if m and not raw.startswith("#"):
                yield m.group(1), m.group(2)


def key(speaker, text):
    return hashlib.sha1(("%s|%s" % (speaker, text)).encode("utf-8")).hexdigest()


def main():
    os.makedirs(OUT, exist_ok=True)
    voice = PiperVoice.load(MODEL)
    sr = voice.config.sample_rate
    wanted = set()
    for speaker, text in lines():
        if speaker not in VOICES:
            print("no voice for", speaker)
            continue
        k = key(speaker, text)
        wanted.add(k + ".ogg")
        dst = os.path.join(OUT, k + ".ogg")
        if os.path.exists(dst):
            continue
        sid, length, noise, noise_w, pitch = VOICES[speaker]
        cfg = SynthesisConfig(speaker_id=sid, length_scale=length, noise_scale=noise, noise_w_scale=noise_w)
        # the model reads "..." as a long pause; keep the hesitation, shorter
        spoken = text.replace("...", ", ")
        audio = np.concatenate([c.audio_float_array for c in voice.synthesize(spoken, syn_config=cfg)])
        pcm = (np.clip(audio, -1, 1) * 32767).astype(np.int16)
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            with wave.open(tmp.name, "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(sr)
                w.writeframes(pcm.tobytes())
        af = "asetrate=%d,aresample=%d,atempo=%.4f" % (sr * pitch, sr, 1.0 / pitch) if pitch != 1.0 else "anull"
        if speaker == "biggie":   # a little rasp: soft saturation and less top end
            af += ",lowpass=f=5200,acrusher=bits=12:mix=0.15"
        af += ",loudnorm=I=-18:TP=-2"
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", tmp.name, "-af", af, "-ar", "22050",
                        "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
        os.remove(tmp.name)
        print("%-8s %s" % (speaker, text))
    for f in os.listdir(OUT):
        if f.endswith(".ogg") and f not in wanted:
            os.remove(os.path.join(OUT, f))
            print("removed stale", f)


main()
