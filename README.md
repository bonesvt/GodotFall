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
| F9 | Switch between the PS3 look and the old PS2 look |

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
Out on runs you collect four materials, and the hub's workbenches spend them:
- **Scrap**: grunts drop it when they die; small **supply crates** beside the routes hold
  more (press **F** to pry one open).
- **Alloy**: hold **F** at an **alloy node** (a titan wreck half sunk in the ground, glowing
  blue) to mine it.
- **Circuits**: rare, from crates and now and then a grunt.
- **Lock cores**: only from beating a boss (Eco pulls the enemy titan's targeting core).
  Kept even if the run is lost afterwards.

Pickups fly to you when you get close. Extracting banks everything you carried (plus the
enemy titan's salvage when you win); a lost run banks half. The HUD shows what you have.

- **Gunsmith bench** (the workbench right of the door): **upgrades** for the gun in hand,
  each gun its own. Dad's smart pistol has **Smart rounds**, 8 levels paid in lock cores:
  each makes another eighth of every mag smart. Smart rounds fire first (pink pips on the
  HUD); while one is chambered the lock works again, closing on the grunt nearest the
  crosshair, and the shot flies to its chest (never its head, so headshots stay yours).
  The other guns have Calibre, Action and Magazine (three small steps each). Every step
  moves the gun's look tier from 0 to 5. The bench also fits **attachments** (muzzle, mag, grip, each a
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
   **Zone 2: Blackwater.** A flooded fen at dusk in the rain, where the militia runs its
   fuel line. You start on the bank where Eco left her skiff and wade north through
   knee-deep water and swamp cypress: the roadblock on the old causeway, a stilt village the
   militia took from the fishers (lookouts on the porches, a squad dug in on the road), the
   channel where the causeway bridge was blown (wallrun the side of a grounded barge, grapple
   the crane, hop the old piers, or walk the back of a titan that drowned there in the war),
   the pump station (pump house, storage tanks, watchtower, a squad in the yard), and the
   beacon on a hummock past it. Three ways through: the **causeway** (loud, up the middle),
   the **reeds** on the left (quiet: cattail beds the whole way, crouch under the stilt huts,
   the drowned titan, the reed beds by the tanks), and the **pipeline** on the right (high:
   climb onto the fuel main and run along it, across the stilt huts' tin roofs, grapple the
   crane, then up the junk and the station's pipe onto the pump house roof). One cache is
   guarded by the village's or the station's squad; the other is on a hut roof or the pump
   house roof. Falling into the channel costs integrity like the ravine does.
   **Zone 3: the Boneyard.** The old front line where the titans died, a burnt valley of
   craters and wrecks under a smoky sky, where the militia strip the dead titans for parts.
   You start behind the war's front-line trench: no-man's land (wire, craters, a titan dead on
   its knees, the picket), the salvage yard (wall and gate, a gantry crane over a titan they're
   stripping, the strip shed, container stacks, a watchtower), the rift (wallrun a titan's
   tower shield wedged in it, grapple the crane, hop the precursor columns standing in it, or
   walk a fallen precursor obelisk), the ruins of the precursor's shrine where the militia set
   up a radio post (the god's eye still glows on the standing stone), and the beacon at the
   edge of the burn, where the living forest starts again. Three ways through: the **haul
   road** (loud), the **old trenches** (quiet: down the communication trench, out through a
   wall slab the crane knocked flat, round the back of the strip shed, over the obelisk, up
   the dead grass beside the ruins), and the **titan's back** (high: climb a dead titan lying
   face down by its hand and arm, run along its back, up the containers onto the yard wall
   and the stacks inside, grapple the crane, then a hut roof onto a ruin column). One cache
   is guarded by the yard's or the ruins' squad; the other is on a container stack or a column.
   Every zone has hiding spots (reed beds, dead grass, the trenches, the shadow under the stilt
   huts) on the same `stealth_cover` / `sight_blocker` hooks as the forest, checkpoints along
   each route, supply crates and alloy nodes beside the routes, and its own sky, haze and
   ambience. Getting gunned down costs 25 pilot integrity and puts you back at the last
   checkpoint. At 0 the run is over. (`ZoneBuilder.build_chain` still makes the old seeded
   platform chains, for any zone past the third.)
2. **Salvage.** Each zone has two caches. One is guarded by a grunt squad
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
carries), `zone_builder.gd` (picks each zone's builder), `forest_builder.gd` (zone 1 and the forest's
edge arena), `marsh_builder.gd` (zone 2), `boneyard_builder.gd` (zone 3), `laid_out.gd` (the
pieces those two share), `forest_kit.gd` (forest props and the enemy outpost kit with their colliders),
`zone_kit.gd` (zones 2 and 3's props and their colliders),
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

Zones 2 and 3's models (swamp cypress, cattails, lily pads, stilt huts, boardwalks, docks,
the pipeline, pump house, storage tanks, the grounded barge and Eco's skiff; the dead titans
lying, kneeling and in pieces, trench revetments, wire, shipping containers, the salvage
gantry and shed, scrap heaps, and the precursor's columns, fallen obelisk and eye shrine) are
made by `tools/zones/build_props.py` (`blender -b --python tools/zones/build_props.py`, writes
`assets/models/marsh/` and `assets/models/boneyard/`); it reuses the forest script's helpers,
and both zones reuse the forest's outpost kit. `xvfb-run -a godot --path . -s
res://tools/zones/shots.gd -- /some/dir [2|3]` saves screenshots and route maps of them.

## Art: PS3 look (with the old PS2 look on F9)
Everything is stylized in the spirit of Jak and Daxter and Shadow of the Colossus,
rendered at roughly PS3-era quality. **F9** flips back to the original PS2 look to compare.

- **PS3 look** (default): full resolution with 4x MSAA and 16x anisotropic filtering;
  normal-mapped textures with roughness and bare-metal masks; GGX highlights and sky
  reflections; sky-tinted ambient light with SSAO; soft 4-split sun shadows (4096 px);
  volumetric haze that catches the sun; ACES tone mapping, soft bloom and a gentle
  vignette. `scripts/ps2/look.gd` holds the Environment and sun settings for both looks.
- **PS2 look** (F9): 3D renders at half resolution, `assets/shaders/ps2_screen.gdshader`
  reduces it to 16-bit colour with ordered dithering and faint interlace lines, textures
  drop to a blurry 128 px mip, lighting goes back to banded two-tone, and vertices snap
  to a coarse grid if Project Settings > Shader Globals > `ps2_vertex_snap` is above 0.
  The `ps3_look` shader global (1 or 0) is what the surface shader reads.
- **Textures** (`assets/textures/`): 1024 px for big level surfaces (stone, steel, grass,
  dirt, temple, titan hull) and 512 px for props and characters, all tiling. Each comes
  as `<name>.png` (RGB albedo, A roughness) and `<name>_n.png` (RG normal, B 255 for
  paint/stone/cloth and 0 for bare metal). Painted from height fields by
  `tools/make_textures.py` (needs pillow and numpy; `--half` for a quick look). The
  titans' paint-wear mask is `tools/titans/make_wear.py` (1024 px).
- **Materials** (`assets/materials/`) all use `assets/shaders/ps2_surface.gdshader`, which
  box-projects the textures (cross-faded on curved models) so models need no UVs. Knobs:
  `normal_strength`, `roughness` (scales the texture's), `metallic` (metal everywhere:
  chrome, gold, gun steel), `metal_mask` (how much the texture's bare-metal mask counts),
  `translucency` (leaves, grass, canvas glow when backlit).
- `xvfb-run -a godot --path . -s res://tools/look_shots.gd -- /some/dir` renders the hub,
  the forest and the arena in both looks side by side.
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
A young mechanic who went rogue after the militia turned her down as a Pilot. She fights with
her late father's broken smart pistol and builds titans from scrap. Anime toon look: a short,
daring dark-red bob with a fringe swept over her right eye, a fierce face with mature makeup,
pilot goggles pushed up on her head, full hips and thighs, and a skin-tight pilot suit (halter
with a keyhole and side cutouts, open back, legs cut high front and back, gloves and thigh-high
boots with knee plates, teal glowing trims).

- **Model**: `assets/models/eco.tscn` (or `Art.model("eco")`), a rigged mesh 1.69 m tall,
  facing -Z with its origin at her feet. Drop it under a CharacterBody3D and she picks her
  animation from it: idle, walk or run (sped up to match), and on the player also fall, crouch
  and slide from its movement state. `idle_motion` turns the idle off.
- **Physics**: spring bones swing her hair (back, sides and fringe) and make her chest and
  glutes jiggle with her steps, jumps and landings (not with her speed, so they don't trail
  behind when she runs). `SPRINGS` in `scripts/ps2/eco_model.gd` tunes stiffness, drag,
  gravity, swing limits and how much of her movement each spring feels; `jiggle` scales the
  chest and glute bounce (0 turns it off) and `springs_enabled` turns them all off.
- **First person**: the player's `EcoBody` node (`scripts/eco_fp_body.gd`) shows her body when
  you look down (head and arms hidden, kept under the camera in every pose) and casts her full
  shadow. `camera_above_neck` and `camera_ahead` place it; `show_body` and `cast_shadow` toggle it.
- **Look at her**: open `scenes/eco_showcase.tscn` and press F6. Left/Right turn her, Space
  pauses the turntable, 1/2/3 switch between full body, face, and the first-person pistol.
- **Shading**: `assets/shaders/eco_toon.gdshaderinc` (used by `eco_toon`, `eco_toon_2side`
  and `eco_toon_overlay`): two flat tones with a tinted shadow side, a thin rim light, a thin
  sheen on the suit and boots, and glowing trims; `eco_outline.gdshader` draws the ink lines
  as each material's next pass. The materials are `assets/materials/eco/eco_v_*.tres`
  (`exposure`, `shade_tint`, `rim` and `sheen` are the main knobs).
- **How she's made** (`tools/eco/build_eco_vroid.py`): built in Blender from a VRoid preset
  (kept out of the repo; it's in the project files). The script removes the preset's fox ears,
  tail and clothes, cuts and dyes the hair, sets the face, paints the makeup, bakes the suit
  into her skin texture, adds the goggles and the glute spring bones, sets her proportions,
  animates her and exports `assets/models/eco/eco.glb` plus `assets/textures/eco/v_*.png`.
  Its import script (`eco_import.gd`) swaps the Blender materials for the toon ones and sets
  her fierce expression from the face's blend shapes. To rebuild (Blender 4):
  ```
  blender -b --factory-startup -P tools/eco/build_eco_vroid.py -- <preset Untitled.glb> . [--preview /tmp/eco]
  ```
  The first-person arm (`eco_fp_arm.glb`) still comes from the older code-sculpted Eco
  (`tools/eco/build_eco.py ... --fp`).
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
- **Stiletto** (Z or the mouse thumb button): tap for a quick stab from Eco's left hand, 2.4 m reach. **Hold** to draw it with a flip-spin and keep it out: the pistol drops, Eco runs 20% faster, left mouse swings alternating slashes (light trail off the tip), and I plays a knife inspect (edge glint, finger spins, toss and catch). Takedowns are always a straight thrust. Let go to put it away. Cobalt-steel model built in Blender by `tools/knife/build_stiletto.py`. On an unaware grunt it's a silent takedown that kills instantly; on one that knows you're there it does 30 damage and alerts it. The pistol can't fire mid-stab.
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
- **Dialogue rating**: press **O** to cycle E, T, M and AO (saved between sessions; default M). Not F8: that stops the game when it runs from the Godot editor.
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
- `tools/pistol/build_pistol.py` builds Eco's smart pistol in Blender (`--tier 1`..`5` builds her upgrades;
  `weapon.gd` `tier` / `set_tier()` and `ps2_assets.gd` `pistol_model(tier)` pick one)
  (`blender --background --python tools/pistol/build_pistol.py -- assets/models/smart_pistol/smart_pistol.glb`);
  `tools/bake_models.gd -- smart_pistol` then puts it in her hand (`assets/models/smart_pistol.tscn`)
- `scripts/sfx.gd` sound effects: plays the CC0 recording `assets/audio/sfx/<id>.ogg` when there is
  one and otherwise synthesizes the sound at runtime; `SFX.variant("step_grass")` picks a random
  numbered take. Sources and credits: `assets/audio/sfx/README.md`; rebuild specs in `tools/audio/`
- `scripts/ambience.gd` looping background beds from `assets/audio/ambience/` (forest, temple hub)
- `scripts/run/titan_gun.gd` titan weapon personalities (XO-16 spin-up, Tracker shells, Splitter beam, jamming scrap rifle)
- `scripts/hud.gd` crosshair, hitmarkers, health, ammo, speedometer, state and cooldown readout
- `scripts/radio/` enemy radio: `radio_chatter.gd` (listens to grunt awareness and deaths, picks lines),
  `radio_popup.gd` (the intercept box), `radio_lines.gd` (every line, by situation)
- Eco's whispers (`scripts/radio/`): she can't answer the militia on their net, so she talks back
  under her breath once an exchange ends, and mutters through kills, takedowns, getting hurt, quiet
  stretches and the run's beats. `eco_whispers.gd` (triggers, cooldowns, breath sound),
  `eco_whisper_lines.gd` (every line, by situation and rating; `keyword>` lines answer what the radio
  actually said), `whisper_caption.gd` (the caption under the crosshair). Voice acting can replace
  the breath: `assets/audio/voice/eco/<category>_<n>.ogg`
- `tests/whisper_test.gd` headless whisper test: `godot --headless --path . -s res://tests/whisper_test.gd`
- `tests/audio_test.gd` checks every recorded sound loads and the ambience beds loop:
  `godot --headless --path . -s res://tests/audio_test.gd`
- `tests/radio_test.gd` headless radio test (range, squad states, kills, no repeats, popup):
  `godot --headless --path . -s res://tests/radio_test.gd`
- `tests/movement_test.gd` headless smoke test:
  `godot --headless --path . -s res://tests/movement_test.gd`
- `tests/combat_test.gd` headless combat smoke test:
  `godot --headless --path . -s res://tests/combat_test.gd`
- `tests/stealth_test.gd` headless stealth test (vision cone, sight range, cover, detection meter,
  gunshots, squad callouts, losing the pilot): `godot --headless --path . -s res://tests/stealth_test.gd`
- `tests/eco_test.gd` Eco's model (toon materials, expression, animations, hair and jiggle
  springs bounce and settle): `godot --headless --path . -s res://tests/eco_test.gd`
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
