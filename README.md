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

### Workbenches and materials
Out on runs you collect three materials, and the hub's workbenches spend them:
- **Scrap**: grunts drop it when they die; small **supply crates** beside the routes hold
  more (press **F** to pry one open).
- **Alloy**: hold **F** at an **alloy node** (a titan wreck half sunk in the ground, glowing
  blue) to mine it.
- **Circuits**: rare, from crates and now and then a grunt.

Pickups fly to you when you get close. Extracting banks everything you carried (plus the
enemy titan's salvage when you win); a lost run banks half. The HUD shows what you have.

- **Gunsmith bench** (the workbench right of the door): **upgrades** for the gun in hand
  (Calibre, Action, Magazine; three small steps each, so the pistol stays skill-first; every
  step moves the gun's look tier from 0 to 5) and **attachments** (muzzle, mag, grip, each a
  trade-off: long barrel, compensator, extended mag, speed base, paracord wrap, skeleton
  grip) plus free paint **finishes**. Q/E switches guns.
- **Weapon rack** (on the wall past the bench): buy and pick your sidearm. Dad's smart
  pistol, the **Rivet Cannon** (five heavy shots off a titan's rivet driver) or the
  **Militia Machine Pistol** (full auto, hold the trigger).
- **Titan workshop** (gantry at the west edge of the titan yard): buy titan parts to start
  runs with (Mk I, instead of scrap; salvage can still replace them) and **refit** parts
  (+6% per level to every copy you install, salvaged ones and scrap included). The titan
  in the gantry is the one you'd start with.

On the screens: W/S pick a row, A/D browse, Space buy or fit, Tab or Q/E switch section,
F or Esc to leave. Progress saves to `user://armory.cfg` (`scripts/hub/armory.gd` has every
price and number). The sidearms and attachments are modelled by
`tools/pistol/build_sidearms.py`, the benches by `tools/hub/build_benches.py`, the crates,
nodes and pickups by `tools/run/build_loot.py` (all `blender -b --python <script>`).

Press **F** near anything to have Eco say something about it; press again for more.
Built in code by `scripts/hub/hub_builder.gd` and `hub_grounds.gd` (temple stone,
carvings, moss, wood, grass, dirt, canvas and bark textures come from `tools/make_textures.py`).
The trees, palms, bushes, ferns, grass, rocks, hills, tents and the idol are modelled in
Blender by `tools/hub/build_props.py` (`blender -b --python tools/hub/build_props.py`, writes
`assets/models/hub/*.glb`). Each mesh is named `<part>__<material>`, and
`scripts/hub/hub_props.gd` swaps in the game material for that suffix when it spawns or
scatters a prop.

## Scrap Titan run loop
The movement and grunt test level is still at `scenes/test_level.tscn` (open it and press F6).

1. **Zone 1: the Pinewoods.** A laid-out forest level. Follow the trail north from the
   drop clearing: a picket behind a fallen log, then the enemy's wall across the valley
   (closed gate under a watchtower; get in through the breach a falling pine made, or grapple
   over), their outpost behind it (huts, antenna, fuel tank, a squad in the yard), a ravine
   with the bridge blown (wallrun the hanging blast shield, grapple the crane, or hop the rock
   pillars; grunts watch from the far lip), a logging camp on the rise (sawmill, log piles,
   a second tower), and the extraction beacon in a clearing. One cache is guarded by the
   outpost's or the camp's squad, the other sits up a climb (a hut roof or the sawmill roof);
   the run seed picks which, and how many grunts hold each spot. Falling into the ravine
   costs integrity and puts you back at the last checkpoint on the trail.
   Three ways through: the **trail** (loud: gate or breach, the outpost yard, the crossings,
   the camp's front), the **creek** on the left (quiet: tall grass along the banks, the
   culvert under the wall, the tent row behind the outpost, a fallen pine over the ravine,
   and a hunting blind overlooking the camp), and the **ridge** on the right (high: jump
   from its end onto the wall top, across the roofs, the crane, the sawmill roof). Tall grass
   and camo nets mark hiding spots for stealth: each has an Area3D in the `stealth_cover`
   group, and dense patches also have an invisible `sight_blocker` body on collision layer 16
   (mask 0) that blocks grunt line of sight but not the player, grunts or the grapple.
   The routes are listed in `zone_info["routes"]`, and the map shot draws them.
   **Zones 2 and 3** are seeded chains of platforms over a void, linked by gaps you
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
4. **Titanfall at the forest's edge.** Extract from zone 3 and you step out of the treeline
   onto a meadow where the enemy was building a forward base. Press V to call your titan in,
   walk to it and press F to embark. Fight the enemy titan (a placeholder): hold left mouse
   on it to fire, Shift to dash out of its red slam circles, V when the core is ready.
5. **Extract.** Kill it and the evac dropship comes in over the pad past where it stood;
   walk your titan into the beam and the run is complete. Lose the titan and the run is over.
   Enter takes you back to the temple.

| Key | Action |
|---|---|
| F | Open salvage, embark |
| 1 / 2 / 3, X | Pick a part, leave it |
| V | Call in titan, fire core |
| Shift | Titan dash |
| Left mouse | Titan fire |
| Enter | Back to the temple (after a run ends) |

Run code lives in `scripts/run/`: `run_manager.gd` (the loop), `run_state.gd` (what a run
carries), `zone_builder.gd` (zone generation), `forest_builder.gd` (zone 1 and the forest's
edge arena), `forest_kit.gd` (forest props and the enemy outpost kit with their colliders),
`terrain.gd` (height-grid ground with matching collision), `titan_parts.gd` (part catalog and
stats), `titan.gd`, `boss.gd`, and the cache, guard squad and beacon scripts. The titan is its own
node holding the run's parts, so it can later travel with you as a walking base.

The forest's models (pines, snags, fallen logs, stumps, and the enemy's wall slabs, gate,
watchtower, huts, sandbags, crates, floodlights, antenna, fuel tank, log piles, sawmill, blown
bridge, crane pylon, wrecked truck, evac pad, dropship, log bridge, tall grass, barrels,
pallets, generator, camo net, hunting blind and culvert) are made in Blender by
`tools/forest/build_props.py` (`blender -b --python tools/forest/build_props.py`, writes
`assets/models/forest/*.glb`); it reuses the hub script's shape helpers, and the forest also
uses the hub's broadleaf trees, bushes, ferns, grass, rocks and hills. To look at the level,
`xvfb-run -a godot --path . -s res://tools/forest/shots.gd -- /some/dir` saves screenshots of
each section, plus `0-map.png`, a top-down map with the three routes.

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
- **Eco's build**: an integrated suppressor (a quiet "thup" and the crisp clack of the slide), vents that
  glow hotter the faster you shoot, LEDs on the slide that show the ammo left and race to the muzzle on
  each shot, a holo sight that pulses, her father's dog tag swinging off the rail, and a twirl on every
  reload and inspect (I). All feel; none of it changes the numbers above.

## Eco, the heroine
A young mechanic who went rogue after the army turned her down as a Pilot. She fights with her
late father's broken smart pistol and builds titans from scrap. Short white hair that shimmers in
technicolor waves, striking aqua eyes, and a makeshift mechanic's outfit in the Jak and Daxter style.

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
- Once alerted they hold around 12 m, strafe, and fire a single 8-damage round every ~1.5 s.
- **Their aim depends on how you move**: about 63% hit chance on a still pilot, ~14% at sprint speed, near zero while wallrunning.
- You have 100 HP that regenerates after 3 s without damage. Dying respawns you and resets the arena.

## Stealth
Grunts start **unaware** and have to notice you first.
- **Vision**: a 60° forward cone (each side) out to their sight range (40 m in the test level, 35-45 m in run zones). Unaware grunts slowly sweep their gaze around their post. Behind them or out of range they see nothing.
- **Cover** blocks sight. A crouched pilot behind a low wall is hidden; standing up shows your head.
- **Tall grass** (the forest's hiding spots): crouch in it and grunts can't see you past 4 m; standing in it halves how fast they notice you. Dense foliage blocks sight like a wall.
- **Detection meter**: fills while they can see you, fast up close (about half a second at 5 m), slowly far away (about 3 s near max range). Moving fast doubles it, crouching halves it, showing only part of yourself past cover cuts it, and the edge of their vision is slower. It drains again a couple of seconds after you break sight.
- **Hearing**: footsteps carry with speed (a sprint about 7 m, a crouch walk about 1 m; no footsteps in the air). The suppressed pistol is still heard out to 20 m, and within about 7 m it alerts outright. Bumping into a grunt always gets noticed.
- **Over each grunt**: a **?** that grows from yellow to orange as it notices you (half full, it turns to look), then a red **!** once alerted. Visible through cover.
- **Around the crosshair**: an arc points at every grunt noticing you, including ones behind you, and fills toward red.
- **Sneak attacks**: anything that hits a grunt that hasn't noticed you does double damage, so a pistol headshot on an unaware grunt kills outright.
- **Stiletto** (V or F): a quick stab from Eco's left hand, 2.4 m reach. On an unaware grunt it's a silent takedown that kills instantly; on one that knows you're there it does 30 damage and alerts it. The pistol can't fire mid-stab.
- **Alerted** grunts fight exactly as before, and call in every squadmate within 16 m. Getting shot always alerts. Out of sight for 10 s, they lose you and go back to searching.

## Enemy radio
Get within about 45 m of grunts and Eco picks up their squad net. A small **INTERCEPT** box
above your health shows who's talking (amber callsigns, militia HQ in red) as the lines type out
through static. She only listens; she never talks back.
- **Calm squads** trade banter, gossip about "the Pilot reject" (they don't know she's listening), and pass
  around salvage rumours naming real titan parts.
- **Squad state drives the calls**: "something moved" when one turns suspicious, a stand-down when it
  gives up, one contact call when she's spotted, fight taunts (and panic when she's wallrunning or
  sliding), cheers when they hit her, "lost her" when they lose track, man-down calls naming the dead,
  a terrified last man, and HQ calling into silence once the squad is gone.
- Bigger events cut off small talk; lines never repeat back to back, and every exchange plays before any repeats.
- Speakers near the edge of range break up: fewer signal bars and garbled characters.
- **Dialogue rating**: press **F8** to cycle E, T, M and AO (saved between sessions; default M).
  E and T have their own clean line banks; AO currently uses the M bank. `scripts/radio/content_rating.gd`
  holds the setting.
- Lines live in `scripts/radio/radio_lines.gd`, one exchange per string (`"a: ... | b: ... | hq: ..."`).
  `radio_chatter.gd` emits `line_started(callsign, text, category)` for voice-over later.

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
- `scripts/fx.gd` stylized combat effects: tracers, muzzle stars, smoke, debris, casings, blasts
- `tools/pistol/build_pistol.py` builds Eco's smart pistol in Blender
  (`blender --background --python tools/pistol/build_pistol.py -- assets/models/smart_pistol/smart_pistol.glb`);
  `tools/bake_models.gd -- smart_pistol` then puts it in her hand (`assets/models/smart_pistol.tscn`)
- `scripts/sfx.gd` procedural sound effects, synthesized at runtime; drop `<id>.wav` or `<id>.ogg`
  in `assets/audio/sfx/` (for example `pistol.wav`) to replace one with a recording
- `scripts/run/titan_gun.gd` titan weapon personalities (XO-16 spin-up, Tracker shells, Splitter beam, jamming scrap rifle)
- `scripts/hud.gd` crosshair, hitmarkers, health, ammo, speedometer, state and cooldown readout
- `scripts/radio/` enemy radio: `radio_chatter.gd` (listens to grunt awareness and deaths, picks lines),
  `radio_popup.gd` (the intercept box), `radio_lines.gd` (every line, by situation)
- `tests/radio_test.gd` headless radio test (range, squad states, kills, no repeats, popup):
  `godot --headless --path . -s res://tests/radio_test.gd`
- `tests/movement_test.gd` headless smoke test:
  `godot --headless --path . -s res://tests/movement_test.gd`
- `tests/combat_test.gd` headless combat smoke test:
  `godot --headless --path . -s res://tests/combat_test.gd`
- `tests/stealth_test.gd` headless stealth test (vision cone, sight range, cover, detection meter,
  gunshots, squad callouts, losing the pilot): `godot --headless --path . -s res://tests/stealth_test.gd`
- `tests/armory_test.gd` headless workbench test (prices, upgrades, attachments, titan parts and
  refits, saving, the bench screens changing your gun, crates, alloy nodes and grunt drops):
  `godot --headless --path . -s res://tests/armory_test.gd`
- `tools/hub/bench_shots.gd` screenshots of the benches, their screens, the guns and the loot
  (needs a renderer): `xvfb-run -a godot --path . -s res://tools/hub/bench_shots.gd -- out_dir`
- `tests/run_loop_test.gd` headless run loop test (generator limits, a bot pilot clearing the
  hardest gap of each kind and all three real ravine crossings and the culvert, log-bridge and ridge
  flanks in the forest, salvage,
  extraction, titanfall, the fight, evac, win and loss):
  `godot --headless --path . -s res://tests/run_loop_test.gd`
- `tests/titan_weapons_test.gd` checks every titan weapon still deals its damage per second:
  `godot --headless --path . -s res://tests/titan_weapons_test.gd`
- `scripts/hub/hub_builder.gd` builds the temple in code, `hub_grounds.gd` the grounds,
  `hub_kit.gd` shared shape helpers, `hub_props.gd` the Blender props; `practice_target.gd`, `titan_dummy.gd` and
  `ambient.gd` (fire flicker, swaying cloth, birds) are the hub's moving parts
- `tests/hub_test.gd` headless hub test (opens in the hub, walking the nave, every look-at
  spot, the climb to the gallery, the grounds are closed in, range targets, the course
  clock, the practice titan and dummies, map table starts a run, runs return to the hub):
  `godot --headless --path . -s res://tests/hub_test.gd`
