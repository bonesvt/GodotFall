## The second sound pass (2026-10-07): footsteps on stone, water, mud and rugs,
## the war in the distance on a run, the home's quiet beds and chimes, workbench
## upgrades and other interactions, and Eco's suit brushing walls and itself.
## Writes more.json (one-shots) and more_ambience.json (stereo loops):
##   python3 tools/audio/more.py
##   python3 tools/audio/build.py tools/audio/more.json assets/audio/sfx
##   python3 tools/audio/build.py tools/audio/more_ambience.json assets/audio/ambience
## Sources are resolved under $SND like build.py's; a path starting with
## res:// is one of the game's own sounds (assets/audio/sfx).
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
def own(id):  # one of the game's own recordings as a layer source
    return os.path.join(REPO, "assets/audio/sfx", id + ".ogg")
e = {}

# --- Footsteps ----------------------------------------------------------------
for i, n in enumerate(["StoneL1", "StoneL2", "StoneL3", "StoneR1", "StoneR2", "StoneR3"]):
    e[f"step_stone_{i+1}"] = {"layers": [{"src": f"ogg/Fantozzi-{n}.ogg", "fadeout": 0.06}], "norm": -3}
WADE = [("water_splash-05.flac", 0, 0.18, 1.0), ("water_splash-02.flac", 0.02, 0.32, 1.05),
        ("water_splash-01.flac", 0.02, 0.36, 0.95), ("water_splash-04.flac", 0.02, 0.34, 1.12),
        ("splash2_0.wav", 0.62, 0.38, 1.0)]
for i, (src, start, dur, pitch) in enumerate(WADE):
    e[f"step_water_{i+1}"] = {"layers": [
        {"src": src, "start": start, "dur": dur, "pitch": pitch, "fadeout": 0.12},
        {"src": "x/mud02.ogg", "gain": -4, "lp": 1600},
    ], "norm": -3}
for i in range(4):
    e[f"step_mud_{i+1}"] = {"layers": [
        {"src": "x/mud02.ogg", "pitch": [1.0, 0.92, 1.08, 0.96][i]},
        {"src": f"footstep_snow_00{i}.ogg", "lp": 1800, "gain": -3, "fadeout": 0.06},
        {"src": "water_splash-03.flac", "dur": 0.2, "gain": -12, "pitch": 1.2, "fadeout": 0.08},
    ], "norm": -4}
for i in range(5):
    e[f"step_rug_{i+1}"] = {"layers": [{"src": f"footstep_carpet_00{i}.ogg", "fadeout": 0.05}], "norm": -4}

# --- The war in the distance (played through the Distant bus) -----------------
for i, (src, start, pitch) in enumerate([("gunfire_sfx.wav", 0, 1.0), ("gunfire_sfx.wav", 0, 0.88), ("22 Magnum.wav", 0.2, 1.0)]):
    e[f"far_shot_{i+1}"] = {"layers": [{"src": src, "start": start, "dur": 0.6, "pitch": pitch, "lp": 5000, "fadeout": 0.3}], "norm": -2}
e["far_shell"] = {"layers": [
    {"src": "cannon_hit_1.ogg", "dur": 1.5, "pitch": 0.82, "fadeout": 0.6},
    {"src": "low-rumbling-176033.mp3", "dur": 2.2, "gain": -6, "lp": 400, "fadeout": 1.2},
], "norm": -2}
e["far_dropship"] = {"layers": [
    {"src": "heli.ogg", "start": 2.0, "dur": 9.0, "pitch": 0.68, "fadein": 3.0, "fadeout": 3.5},
    {"src": "low-rumbling-176033.mp3", "start": 4.0, "dur": 9.0, "gain": -5, "lp": 300, "fadein": 3.0, "fadeout": 3.5},
], "norm": -3}
e["far_siren"] = {"layers": [{"src": "storm_3_siren.ogg", "start": 3.4, "dur": 12.0, "fadein": 1.2, "fadeout": 3.0}], "norm": -3}

# --- Home: chimes and birds -----------------------------------------------------
for i in range(4):
    e[f"chime_{i+1}"] = {"layers": [{"src": f"bell_ding{i+1}.wav", "pitch": [0.8, 0.9, 0.75, 1.0][i], "fadeout": 0.6}], "norm": -4}
for i, (start, dur) in enumerate([(1.6, 1.6), (6.3, 1.5), (8.9, 2.0), (19.0, 1.2), (57.4, 2.1)]):
    e[f"bird_{i+1}"] = {"layers": [{"src": "park_ambience_birds.wav", "start": start, "dur": dur, "hp": 1500, "fadein": 0.05, "fadeout": 0.3}], "norm": -3}

# --- Workbenches and upgrades -------------------------------------------------
e["bench_open"] = {"layers": [
    {"src": "metalLatch.ogg"},
    {"src": "workshop - tool rummaging.wav", "dur": 0.7, "delay": 0.12, "gain": -7, "fadeout": 0.3},
], "norm": -3}
e["bench_close"] = {"layers": [
    {"src": "workshop - clink thud.wav", "dur": 0.5, "gain": -4, "fadeout": 0.2},
    {"src": "metalLatch.ogg", "pitch": 0.9, "delay": 0.15},
], "norm": -3}
e["upgrade_gun"] = {"layers": [
    {"src": "workshop - drill short 1.wav", "dur": 0.55, "fadeout": 0.15},
    {"src": "workshop - ratchet1.wav", "dur": 0.7, "delay": 0.5, "gain": -2, "fadeout": 0.1},
    {"src": own("reload_in"), "delay": 1.05, "gain": -3},
], "norm": -2}
e["upgrade_rack"] = {"layers": [
    {"src": "metalLatch.ogg"},
    {"src": "workshop - clink thud.wav", "delay": 0.2, "gain": -4, "dur": 0.6, "fadeout": 0.2},
    {"src": own("reload_in"), "delay": 0.6},
], "norm": -2}
e["upgrade_knife"] = {"layers": [
    {"src": "workshop - scrape1.wav", "dur": 0.6, "hp": 1200, "fadeout": 0.2},
    {"src": "workshop - scrape2.wav", "dur": 0.5, "hp": 1200, "delay": 0.45, "fadeout": 0.2},
    {"src": "workshop - ping.wav", "delay": 0.95, "gain": -6, "fadeout": 0.4},
], "norm": -2}
e["upgrade_titan"] = {"layers": [
    {"src": "forger.ogg", "dur": 1.3, "fadeout": 0.4},
    {"src": "workshop - ratchet2.wav", "dur": 1.2, "delay": 0.55, "gain": 4, "fadeout": 0.1},
    {"src": own("titan_hiss_short"), "delay": 1.1, "gain": -8},
], "norm": -2}
e["upgrade_suit"] = {"layers": [
    {"src": "zipper-1.wav", "fadeout": 0.1},
    {"src": "Audio/cloth1.ogg", "delay": 0.55, "gain": -2},
    {"src": "metalClick.ogg", "delay": 0.95, "gain": 2},
], "norm": -2}
e["level_up"] = {"layers": [
    {"src": "bell_ding2.wav", "fadeout": 0.5},
    {"src": "bell_ding2.wav", "pitch": 1.5, "delay": 0.14, "gain": -5, "fadeout": 0.5},
], "norm": -3}

# --- Home interactions --------------------------------------------------------
e["outfit_change"] = {"layers": [
    {"src": "rustling.ogg", "start": 2.35, "dur": 0.9, "fadein": 0.05, "fadeout": 0.3},
    {"src": "zipper-1.wav", "pitch": 1.1, "delay": 0.7, "gain": -3},
], "norm": -3}
e["haircut"] = {"layers": [{"src": "scissors/scissors.ogg", "fadeout": 0.1}], "norm": -4}
e["coins"] = {"layers": [{"src": "handleCoins.ogg", "fadeout": 0.1}], "norm": -4}
e["map_open"] = {"layers": [{"src": "snd_use_map.wav", "fadeout": 0.2}], "norm": -4}
e["map_close"] = {"layers": [{"src": "snd_close_map.wav", "fadeout": 0.2}], "norm": -4}
for i in range(3):
    e[f"paper_{i+1}"] = {"layers": [{"src": f"WAV/Paper Sound - {i+1}.wav", "fadeout": 0.15}], "norm": -5}
e["wardrobe_open"] = {"layers": [{"src": "doorOpen_1.ogg", "fadeout": 0.15}, {"src": "Audio/cloth2.ogg", "delay": 0.25, "gain": -6}], "norm": -5}
e["wardrobe_close"] = {"layers": [{"src": "doorClose_1.ogg", "fadeout": 0.15}], "norm": -5}
e["shop_bell"] = {"layers": [{"src": "bell_ding1.wav", "pitch": 1.6, "fadeout": 0.5}, {"src": "bell_ding1.wav", "pitch": 1.9, "delay": 0.09, "gain": -4, "fadeout": 0.5}], "norm": -6}
e["sit_down"] = {"layers": [{"src": "Audio/cloth1.ogg"}, {"src": "creak3.ogg", "gain": -8, "delay": 0.12}], "norm": -4}
e["bed_creak"] = {"layers": [{"src": "creak2.ogg", "fadeout": 0.15}, {"src": "Audio/cloth2.ogg", "gain": -4}], "norm": -5}

# --- Eco's suit touching walls and itself (body contact) -------------------------
RUSTLE = [1.12, 2.4, 3.64, 5.26, 6.57, 7.98, 10.52, 11.5, 13.7, 16.66]
for i in range(4):
    e[f"contact_wall_{i+1}"] = {"layers": [
        {"src": "rustling.ogg", "start": RUSTLE[i], "dur": 0.28, "hp": 300, "fadein": 0.01, "fadeout": 0.12},
        {"src": f"thwack-0{i+1}.wav", "lp": 900, "gain": -9, "pitch": 0.8},
    ], "norm": -4}
for i in range(4):
    e[f"contact_self_{i+1}"] = {"layers": [
        {"src": "rustling.ogg", "start": RUSTLE[i + 4], "dur": 0.22, "hp": 600, "lp": 7000, "fadein": 0.02, "fadeout": 0.12},
    ], "norm": -6}

amb = {}
def bed(src, start, dur, rms, **kw):
    layer = {"src": src, "start": start, "dur": dur, "fadein": 0.01, "fadeout": 0.001}
    layer.update(kw)
    return {"stereo": True, "loop": True, "xfade": 2.0, "rms": rms, "q": 0, "layers": [layer]}
amb["park_river"] = bed("park_ambience_river.wav", 30, 30.0, -22)
amb["park_birds"] = bed("park_ambience_birds.wav", 60, 40.0, -26)
amb["fireplace"] = bed("fireplace-sound-loop/fire.wav", 0, 28.0, -22)
amb["town_murmur"] = bed("crowd_shouting.ogg", 0.5, 26.0, -30, lp=900)

json.dump(e, open(os.path.join(HERE, "more.json"), "w"), indent=1)
json.dump(amb, open(os.path.join(HERE, "more_ambience.json"), "w"), indent=1)
print(len(e), "sounds,", len(amb), "beds")
