# Titanfall Roguelike (Godot 4)

Pilot movement, first combat (a weak starter pistol and grunt enemies), and the Scrap Titan run loop.

## Run it
1. Install Godot 4.3 or newer (standard build, not .NET): https://godotengine.org/download
2. Open Godot, click **Import**, pick this folder's `project.godot`.
3. Press **F5** (or the Play button). The mouse is captured; Esc frees it, click to recapture.

## Controls
| Key | Action |
|---|---|
| WASD | Move (auto-sprints when moving forward) |
| Space | Jump, double jump, wall jump |
| C / Ctrl | Crouch; slide when running |
| Q / E / Right mouse | Grapple (hold to reel in, release or jump to let go) |
| Left mouse | Shoot (semi-auto, one click per shot) |
| R | Reload |
| T | Respawn |
| G | Reset the grunt arena |
| H | Toggle help |
| F9 | Toggle the PS2 look |

## Scrap Titan run loop
Pressing Play starts a run (`scenes/run.tscn`). The movement and grunt test level is
still at `scenes/test_level.tscn` (open it and press F6).

1. **Three zones.** Each is a seeded chain of platforms over a void, linked by gaps you
   clear with a sprint jump, a double-jump climb, a wallrun along a blue wall, or the grapple
   on an orange anchor. Grunt squads hold some platforms from behind cover (more of them in
   later zones), and every platform has low walls or blocks you can use as cover too.
   Falling, or getting gunned down, costs 25 pilot integrity and puts you back on the last
   platform you stood on. At 0 the run is over.
2. **Salvage.** Each zone has two caches on side platforms. One is guarded by a grunt squad
   dug in facing you; kill them all to unlock it. Opening a cache
   pauses and offers three titan parts; press 1, 2 or 3 to keep one, or X to leave it.
3. **Your titan is your build.** Four slots: chassis (armor, speed, dashes), weapon (damage),
   core (charged ability: laser burst, shield, overdrive) and kit (extra dash, plating,
   coolant). Empty slots stay scrap. Parts roll Mk I to III, and later zones roll higher.
4. **Titanfall.** Extract from zone 3 into the arena, press V to call your titan in, walk to
   it and press F to embark. Fight the enemy titan (a placeholder): hold left mouse on it to
   fire, Shift to dash out of its red slam circles, V when the core is ready.
5. Kill it and the run is complete. Lose the titan and the run is over. Enter starts a new run.

| Key | Action |
|---|---|
| F | Open salvage, embark |
| 1 / 2 / 3, X | Pick a part, leave it |
| V | Call in titan, fire core |
| Shift | Titan dash |
| Left mouse | Titan fire |
| Enter | New run (after a run ends) |

Run code lives in `scripts/run/`: `run_manager.gd` (the loop), `run_state.gd` (what a run
carries), `zone_builder.gd` (zone and arena generation), `titan_parts.gd` (part catalog and
stats), `titan.gd`, `boss.gd`, and the cache, guard squad and beacon scripts. The titan is its own
node holding the run's parts, so it can later travel with you as a walking base.

## PS2-style art
Everything is low-poly and textured in a classic PS2 style. **F9** toggles the look
on and off in game, to compare.

- **Look**: 3D renders at half resolution and is upscaled (Project Settings > Rendering >
  Scaling 3D), then `assets/shaders/ps2_screen.gdshader` reduces it to 16-bit colour with
  ordered dithering and faint interlace lines. The HUD stays sharp. Vertices snap to a
  coarse grid for a slight wobble (Project Settings > Shader Globals > `ps2_vertex_snap`,
  0 turns it off). Levels get a painted sky with mountains, distance fog, flat ambient
  light and low-res shadows.
- **Textures** (`assets/textures/`): 64 to 128 px, 16 colours each, nearest filtered.
  Painted by `tools/make_textures.py` (needs pillow and numpy); you can also paint over
  the PNGs by hand.
- **Materials** (`assets/materials/`) all use `assets/shaders/ps2_surface.gdshader`, which
  box-projects the texture so models need no UVs.
- **Level boxes** keep being built by colour (`Kit.box`), and `scripts/ps2/ps2_assets.gd`
  picks the material: grey is concrete with steel-plate tops (small grey pieces become
  cover barriers and crates), blue is wallrun panels, orange is grapple-anchor hazard
  stripes, green is crates, red is lava.
- **Models** (`assets/models/*.tscn`): Eco (see below), her smart pistol held in her gloved hand, grunt (legs swing
  as it walks, visor glows on wind-up), four titan chassis (Atlas, Ogre, Stryder, Scrap)
  and four titan guns (XO-16, 40mm Tracker, Splitter, scrap rifle). Your titan is built
  from the chassis and weapon you salvaged. Plus the red enemy titan, salvage cache and
  extract beacon. They are plain scenes made of primitive meshes, so you can edit them
  in the editor or swap in Blender models later. `tools/bake_models.gd` regenerates them (run it without `--headless`).

From a fresh clone, import once before running the headless tests (opening the
project in the editor also does this): `godot --headless --import`

## Abilities
Movement is tuned to feel heavy rather than floaty: gravity is 28 m/s², falling is 35% faster
than rising, and hard landings dip the camera. A jump peaks at about 1.3 m and a double jump
at about 2.5 m.

- **Sprint** with fast acceleration.
- **Slide**: crouch while running for a speed boost (1.5 s cooldown). Speeds up down slopes. Hold crouch in the air to slide on landing.
- **Slide-hop**: jump out of a slide and keep your speed; landing gives a short window before friction.
- **Double jump**: one air jump that also redirects you toward the keys you hold.
- **Wallrun**: hit a wall at speed while in the air holding W. Lasts up to 1.8 s, slight lift then slow sink, camera tilts. Refreshes the double jump.
- **Wall jump**: Space during (or just after) a wallrun kicks you off the wall.
- **Grapple**: 45 m range, pulls you to the point, 2.5 s cooldown.
- **Air strafing**: you keep momentum in the air but can steer.

## Starter pistol (Eco's father's broken smart pistol)
The model is the smart pistol Eco took from her father: its auto-lock sensor is dead, cracked
and taped back on, so every shot is aimed by hand.
Weak on purpose, so skill decides fights.
- **Damage**: 20 to the body, 45 to the head. A grunt has 60 HP: three body shots, or a headshot plus a body shot.
- **Falloff**: full damage to 15 m, down to 60% at 35 m.
- **Semi-auto**: 8-round magazine, 1.5 s reload, max ~6 shots/s, but every click is one shot.
- **Bloom**: each shot widens the cone; it only starts recovering 0.25 s after your last shot.
  Paced shots land, spam doesn't. The crosshair gap shows the real cone.
- **Movement**: sprinting and jumping add spread. **Wallrunning and sliding don't**, so shooting off a wall is a pilot skill.
- Recoil kicks the view up and mostly settles back. Hitmarkers: white body, gold head, red kill.

## Eco, the heroine
A young mechanic who went rogue after the army turned her down as a Pilot. She fights with her
late father's broken smart pistol and builds titans from scrap. Short white hair that shimmers in
technicolor waves, striking aqua eyes, and a makeshift mechanic's outfit in the Jak and Daxter style:
cropped work jacket, racerback sports bra, olive cut-off shorts, knee pads, slouch socks and boots.

- **Model**: `assets/models/eco.tscn` (or `Art.model("eco")`), a rigged mesh about 1.7 m tall,
  facing -Z with its origin at her feet. Drop it under a CharacterBody3D and she picks her
  animation from it: idle, walk or run (sped up to match), and on the player also fall, crouch
  and slide from its movement state. `idle_motion` turns the idle off.
- **Physics**: spring bones swing her hair locks (fringe, sides, back) and the rag on her hip;
  `SPRINGS` in `scripts/ps2/eco_model.gd` tunes stiffness, drag, gravity and swing limits, and
  `springs_enabled` turns them off.
- **First person**: the player's `EcoBody` node (`scripts/eco_fp_body.gd`) shows her body when
  you look down (head and arms hidden, kept under the camera in every pose) and casts her full
  shadow. `camera_above_neck` and `camera_ahead` place it; `show_body` and `cast_shadow` toggle it.
- **Look at her**: open `scenes/eco_showcase.tscn` and press F6. Left/Right turn her, Space
  pauses the turntable, 1/2/3 switch between full body, face, and the first-person pistol.
- **Shading**: the build bakes ambient occlusion into each vertex colour so creases read, and
  her materials use `vertex_ao`, `gloss` and a tighter `light_wrap`/`light_softness` in
  `ps2_surface.gdshader`.
- **Hair**: `assets/shaders/eco_hair.gdshader`. `iridescence`, `wave_scale`, `wave_speed`
  and `sway` on `assets/materials/eco/eco_hair.tres` tune the colour waves and the tip sway.
- **How she's made** (`tools/eco/`): she is sculpted in code from signed distance fields,
  then decimated, UV'd, rigged and animated in Blender, and exported to
  `assets/models/eco/eco.glb`. Its import script swaps the Blender materials for the PS2
  ones in `assets/materials/eco/`. To rebuild (needs numpy, scikit-image, pillow, Blender 4):
  ```
  python3 tools/eco/paint_eco.py                     # face, eyes, fabrics
  python3 tools/eco/sculpt.py /tmp/eco               # all parts (or name some)
  blender -b --factory-startup -P tools/eco/build_eco.py -- /tmp/eco assets/models/eco/eco.glb
  python3 tools/eco/sculpt.py /tmp/eco --fp          # first-person arm
  blender -b --factory-startup -P tools/eco/build_eco.py -- /tmp/eco assets/models/eco/eco_fp_arm.glb --fp
  ```
  Shapes and joints live in `sculpt.py` and `rig.py`; add `--preview <prefix>` to the
  Blender step for quick workbench renders.
- **Reference sheet renders**: `godot res://scenes/eco_showcase.tscn -- --shots=<folder> [--clean]`.

## Grunts
- 60 HP, headshots count above the shoulders. Visor glows red during a 0.4 s wind-up before each shot.
- Spot you by line of sight (40 m), hold around 12 m, strafe, and fire a single 8-damage round every ~1.5 s.
- **Their aim depends on how you move**: about 63% hit chance on a still pilot, ~14% at sprint speed, near zero while wallrunning.
- You have 100 HP that regenerates after 3 s without damage. Dying respawns you and resets the arena.

## Test level
- Ahead: **wallrun corridor** (two long parallel walls).
- Right: **wall-jump course**, zig-zag panels over red "lava" between two platforms.
- Left: **slide ramp**, walk up, turn around, crouch and slide down.
- Behind: **grapple towers** with floating platforms.
- Far right (about 60 m): **grunt arena** with six grunts, cover, and wallrun walls on both sides.

## Tuning
Every number lives in `scripts/player.gd`, `scripts/weapon.gd` and `scripts/grunt.gd` as an exported variable. Open `scenes/player.tscn`,
select the Player node and tweak values in the Inspector, or change the defaults in the script.

## Files
- `scripts/player.gd` movement controller (state machine: GROUND, AIR, SLIDE, WALLRUN, GRAPPLE)
- `scripts/test_level.gd` builds the test level in code
- `scripts/weapon.gd` starter pistol (hitscan, bloom, falloff, recoil, viewmodel)
- `scripts/grunt.gd` grunt AI and hitbox
- `scripts/fx.gd` tracers and impact sparks
- `scripts/hud.gd` crosshair, hitmarkers, health, ammo, speedometer, state and cooldown readout
- `tests/movement_test.gd` headless smoke test:
  `godot --headless --path . -s res://tests/movement_test.gd`
- `tests/combat_test.gd` headless combat smoke test:
  `godot --headless --path . -s res://tests/combat_test.gd`
- `tests/run_loop_test.gd` headless run loop test (generator limits, a bot pilot clearing the
  hardest gap of each kind, salvage, extraction, titanfall, the fight, win and loss):
  `godot --headless --path . -s res://tests/run_loop_test.gd`
