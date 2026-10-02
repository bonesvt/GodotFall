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

## The temple (hub)
Pressing Play (`scenes/run.tscn`) opens in the hub: the small abandoned temple Eco hides
out in. A lost civilization built it for their precursor god; she has made it her secret
base since the militia turned her away. Walk around, warm up the movement kit, and
press **F** at the map table ("HEAD OUT") to start a run. When a run ends, won or lost,
**Enter** brings you back here.

- **The hall**: two rows of pillars down a nave, the roof fallen in over the middle so a
  shaft of sun lands on the idol. Carved eye glyphs run along the walls.
- **The idol**: the precursor god, seated on a stepped dais with its hands open on its
  knees and one great eye still glowing in its brow. Fire bowls either side.
- **Eco's corner** (left of the door): her bedroll and lantern, and the militia's letter
  turning down her pilot application, pinned to the wall.
- **Workbench** (right of the door): her father's smart pistol stripped down, its burnt
  auto-lock board on the bench. An `EcoSpot` marker beside it is where her character
  model will stand.
- **Her father's titan** (right aisle): the wreck sitting slumped against the wall, left
  arm torn off and lying beside it, core dark, wired to a bank of salvaged batteries.
- **The gallery**: a ledge 4.5 m up the left wall. Run up the fallen pillar from the nave,
  or double-jump up the rubble by the door. Her stash of scrap is up there.
- **The grounds** (`scripts/hub/hub_grounds.gd`): a big grassy clearing round the temple,
  closed in by a ruined boundary wall, thick jungle and green hills, so there is no void.
  - **Plaza** in front of the door, with the god's eye on a plinth and lamp posts.
  - **Eco's camp** (east, also out through the breach): tents, a campfire with smoke,
    laundry and banners in the breeze, a salvage tarp over titan scrap, a pond.
  - **Shooting range** (west): a covered firing line and nine pop-up targets from 8 to
    40 m. Shoot one and it drops, then springs back up; the board counts hits and headshots.
  - **Movement course** (behind the temple): three jumps, a wallrun, a climb, a grapple to
    the finish tower and a long slide back down. Stand on the start pad, leave it and the
    clock runs until the finish; touch the grass and it resets. Your best time shows on
    the HUD.
  - **Titan yard** (past the plaza): press **V** in the yard to drop a practice titan
    (built from your last run's parts, scrap if none), **F** to climb in and out. Walk it
    round titan-sized cover, dash, and shoot the four scrap titan dummies; they topple
    and get propped back up.

Press **F** near anything to have Eco say something about it; press again for more.
Built in code by `scripts/hub/hub_builder.gd` and `hub_grounds.gd` (temple stone,
carvings, moss, wood, grass, dirt and canvas textures come from `tools/make_textures.py`).

## Scrap Titan run loop
The movement and grunt test level is still at `scenes/test_level.tscn` (open it and press F6).

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
5. Kill it and the run is complete. Lose the titan and the run is over. Enter takes you back to the temple.

| Key | Action |
|---|---|
| F | Open salvage, embark |
| 1 / 2 / 3, X | Pick a part, leave it |
| V | Call in titan, fire core |
| Shift | Titan dash |
| Left mouse | Titan fire |
| Enter | Back to the temple (after a run ends) |

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
- **Models** (`assets/models/*.tscn`): P-08 pistol with a gloved hand, grunt (legs swing
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

## Starter pistol (P-08 placeholder)
Weak on purpose, so skill decides fights.
- **Damage**: 20 to the body, 45 to the head. A grunt has 60 HP: three body shots, or a headshot plus a body shot.
- **Falloff**: full damage to 15 m, down to 60% at 35 m.
- **Semi-auto**: 8-round magazine, 1.5 s reload, max ~6 shots/s, but every click is one shot.
- **Bloom**: each shot widens the cone; it only starts recovering 0.25 s after your last shot.
  Paced shots land, spam doesn't. The crosshair gap shows the real cone.
- **Movement**: sprinting and jumping add spread. **Wallrunning and sliding don't**, so shooting off a wall is a pilot skill.
- Recoil kicks the view up and mostly settles back. Hitmarkers: white body, gold head, red kill.

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
- `scripts/hub/hub_builder.gd` builds the temple in code, `hub_grounds.gd` the grounds,
  `hub_kit.gd` shared shape helpers; `practice_target.gd`, `titan_dummy.gd` and
  `ambient.gd` (fire flicker, swaying cloth, birds) are the hub's moving parts
- `tests/hub_test.gd` headless hub test (opens in the hub, walking the nave, every look-at
  spot, the climb to the gallery, the grounds are closed in, range targets, the course
  clock, the practice titan and dummies, map table starts a run, runs return to the hub):
  `godot --headless --path . -s res://tests/hub_test.gd`
