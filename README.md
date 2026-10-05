# Titanfall Roguelike (Godot 4)

Pilot movement, first combat (a weak starter pistol and grunt enemies), and the Scrap Titan run loop.

## Run it
1. Install Godot 4.3 or newer (standard build, not .NET): https://godotengine.org/download
2. Open Godot, click **Import**, pick this folder's `project.godot`.
3. Press **F5** (or the Play button). The title screen opens: **Continue**, **New game**,
   **Load game**, **Settings**, **Quit**. In game the mouse is captured; **Esc** pauses.

Or play the Windows build (no editor needed): `GodotFall.exe`, see **Windows build** below.

## Menus, settings and saves
- **Title screen** (`scenes/title.tscn`, the main scene; `scripts/ui/title_screen.gd`): Eco on
  the temple steps behind the menu. Continue loads the last slot played straight into the
  temple. New game asks before writing over a used slot.
- **Pause menu** (Esc; `scripts/ui/pause_menu.gd`): Resume, Settings, Abandon run (during a
  run: it ends like a loss, half the carried materials bank), Quit to title, Quit game. It
  stays shut over the workbenches, paint shop and salvage choice, where Esc closes those.
- **Settings** (`scripts/ui/settings_menu.gd`, saved by `scripts/game/prefs.gd` to
  `user://settings.cfg`): mouse sensitivity, invert Y, field of view; every key rebindable
  (primary and secondary); master / effects / ambience / voices volume (buses in
  `default_bus_layout.tres`); windowed / borderless / fullscreen, vsync, frame cap, look
  (Anime, PS3 or PS2; F9 remembers too) and film grain; dialogue rating, tutorial hints, start in third person,
  Eco's jiggle style (Classic, Smooth anime, Realistic).
- **Save slots** (`scripts/game/saves.gd`): three, in `user://saves/slot1..3/`. Each holds the
  files the game already saved on its own (armory, hub conversations, titan paint, tutorial
  hints seen) plus runs / wins / time played. A run in progress isn't saved; Continue puts you
  back in the temple. A save from before slots moves into slot 1 on first launch.
  `user://` is `%APPDATA%\Godot\app_userdata\Titanfall Roguelike - Movement Prototype\` on
  Windows (the project keeps that name so old saves carry over; the window says GodotFall).

## Windows build
`export_presets.cfg` has a **Windows Desktop** preset that writes one self-contained
`build/windows/GodotFall.exe` (the game data is embedded). In the editor: **Project > Export >
Windows Desktop > Export Project** (install the export templates first if Godot asks:
**Editor > Manage Export Templates > Download and Install**). From a terminal:
`godot --headless --path . --export-release "Windows Desktop" build/windows/GodotFall.exe`.
The preset keeps `dialogue/*` (plain text the hub people read at runtime) and leaves out
`tests/` and `tools/`.

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
| Esc | Pause menu (settings, quit) |
| H | Toggle help |
| F9 | Change look: Anime (default), PS3, old PS2 |

## The temple (hub)
Pressing Play (`scenes/run.tscn`) opens in the hub: the small abandoned temple Eco hides
out in. The Precursors, a lost civilization, built it for their god; she has made it her
secret base since the recruiters turned her away. Walk around, warm up the movement kit,
and press **F** at the poster outside (the Pinewoods run, the tutorial; a gold marker turns
over it until you've won it once) or at the mission table in the hall (the real levels and
the uncharted long way) to start a run. When a run ends, won or lost, **Enter** brings you
back here.

Off duty (in the hub and the town, but not on the range, the movement course or the titan
yard) Eco doesn't run: she struts at a stroll (`player.gd` `stroll_speed`, hold **Shift**
for a brisker one), hips swaying over each step, one foot landing in front of the other,
shoulders back, and stands with her weight on one hip. The strut is layered over her walk in
`scripts/ps2/eco_model.gd` (`_strut`); the training grounds are `TRAINING_AREAS` in
`hub_grounds.gd`. `xvfb-run -a godot --path . --fixed-fps 30 -s res://tools/eco/strut_shots.gd
-- out_dir --view=front|side|back` renders it next to her plain walk.

- **The hall**: an old hardwood temple, two rows of timber pillars down a nave and the
  roof fallen in over the middle so a shaft of sun lands on the idol. Carved, painted eye
  glyphs run along the walls. Eco has made it home: plank floors, rugs, string lights
  zigzagging across the nave, paper lanterns in the aisles, potted ferns, a porch with
  lanterns over the door and a tarp over half the roof hole. (`HubBuilder.home_style`
  can build it in the precursors' pale alloy instead, `"alloy"`.)
- **Kitchen** (under the loft): a barrel stove, a counter and shelf of jars, herbs
  drying, a little table with two stools.
- **Couch** (by the bench): a pilot seat from a scrapped Ogre on a crate base, with a
  crate table and a spotlight floor lamp.
- **The idol**: the Precursors' god, seated on a stepped dais with its hands open on its
  knees and one great eye still glowing in its brow. Fire bowls either side.
- **Precursor lore**: two carved reliefs on the back wall either side of the idol (the
  builders holding up their eyes; the great eye over the world), grooves still glowing,
  and a stand of tablets Eco dug out of the rubble. F on each for what she's worked out.
- **Mission table** (in the nave): the map of the real levels (Level 1 opens once the
  Pinewoods run is won) with the uncharted long way at its far end.
- **Armour bench** (left wall, under the loft): the scavenged locker and her spare suit on
  a pipe stand; F opens the suit screen (upgrades and changes).
- **Workbench and weapon rack** (right of the door): the gunsmith's bench with the gun in
  her hand on the mat, and the rack of the sidearms she owns. An `EcoSpot` marker beside
  the bench is where her character model stands. Between the bench and the door, a
  glass-topped **knife case** shows her three knives on velvet.
- **Her father's titan** (right aisle): the wreck sitting slumped against the wall, left
  arm torn off and lying beside it, core dark, wired to a bank of salvaged batteries.
- **Eco's loft** (up the stairs left of the door): a timber floor 4.5 m up over the left
  aisle with a rail between the pillars, made into her bedroom: the bed she built (F to lie
  down), a lantern and the photo of her and her dad, a desk under her drawings with the
  recruiters' refusal pinned up, the wardrobe at the top of the stairs, a rug, a beanbag,
  fairy lights along the rail and her stash of scrap at the back.
- **The grounds** (`scripts/hub/hub_grounds.gd`): a big grassy clearing round the temple,
  closed in by a ruined boundary wall, thick jungle and green hills, so there is no void.
  - **Plaza** in front of the door, with the god's eye on a plinth and lamp posts.
  - **The camp** (east, also out through the breach): Mom's, Ophelia's and Biggie's tents
    (`scripts/hub/hub_rooms.gd`), big canvas wall tents on raised timber decks with
    porches, lanterns and guy ropes, round a campfire with smoke; Eco's old little tent,
    laundry and banners in the breeze, a salvage tarp over titan scrap, a pond.
  - **Tutorial poster** (left edge of the plaza): a notice board with Eco's poster for the
    Pinewoods run.
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

- **Gunsmith bench** (the workbench right of the door): click a gun in the list on the left
  and it appears in 3D in the middle. Drag to spin it, scroll to zoom, and click the **+**
  markers on its parts (barrel, slide, mag, grip, frame...) to see that part's
  upgrades and attachments on the right. A locked attachment shows on the gun on the first
  click and is bought on the second. **Upgrades** are per gun. Dad's smart pistol has **Smart rounds**, 8 levels paid in lock cores:
  each makes another eighth of every mag smart. Smart rounds fire first (pink pips on the
  HUD); while one is chambered the lock works again, closing on the grunt nearest the
  crosshair, and the shot flies to its chest (never its head, so headshots stay yours).
  The **Hand Cannon** gets Rivet heads (damage and headshots), Punch-through (rounds
  carry on into the body behind), Stagger coils (hits knock a grunt off their aim) and a
  Speed mag (faster reloads). The **Auto Handgun** gets Drum feed (more rounds), Recoil buffer, Overclock
  (faster fire) and Hot streak (every hit in a row hits harder; a miss or a pause resets
  it, and the tracers run orange as it heats). Three levels each. Every step
  moves the gun's look tier from 0 to 5. The bench also fits **attachments** (muzzle, mag, grip, each a
  trade-off: long barrel, compensator, extended mag, speed base, paracord wrap, skeleton
  grip) plus free paint **finishes** (on the shell or frame). Q/E switches guns, Tab parts.
- **Weapon rack** (on the wall past the bench): pick your starting sidearm. Dad's smart
  pistol from the start; the **Hand Cannon** (a chrome Desert Eagle-style semi-auto,
  seven big rounds, a long engraved barrel) at **level 3**; the **Auto Handgun** (a colony machine pistol, full auto,
  fifteen rounds a second) at **level 6**.
- **Knife case** (against the right wall by the door): pick which of her three knives she
  carries, free: the **Needle** (the stiletto refined: diamond needle blade, swept guard lit
  cyan, ring pommel; the default), the **Plate Kunai** (a tanto cut from colony armour plate,
  its power trace still glowing, cobalt paracord) or the **Butterfly** (a balisong held open,
  handles shut round the tang; the bite handle flips open as she spins it). They fight the
  same. The case tags the one she carries.
- **Eco's level** is 1 plus every upgrade she has bought: weapon upgrades, titan refits and
  suit upgrades. It shows in the hub HUD and on every bench, which also says what unlocks
  next.
- **Titan workshop** (gantry at the west edge of the titan yard): buy titan parts to start
  runs with (Mk I, instead of scrap; salvage can still replace them) and **refit** parts
  (+6% per level to every copy you install, salvaged ones and scrap included). The titan
  in the gantry is the one you'd start with.
- **Suit locker** (left wall, past the rubble): upgrade Eco's suit, five tiers bought in
  order. Each tier adds **armour** (a second bar over her health: it takes hits first and
  comes back after the same pause, once health is full), one **passive**, and armour you
  can see on her:

  | Tier | Armour | Passive | Looks |
  | --- | --- | --- | --- |
  | 1 Scav Rig | 20 | Magnet pouches: materials fly to you from twice as far | forearm bracers, belt with hip pouches |
  | 2 Seal Weave | 40 | Auto-seal: health and armour come back after 2 s, not 3 | layered shoulder plates, seal injector on her thigh |
  | 3 Dampers | 60 | Hush dampers: grunts notice you 30% slower (sight and footsteps) | shin guards, knee cops, hip plates |
  | 4 Jump Kit | 80 | Wallruns last 40% longer, grapple recharges 30% faster | jump pack low on her back, armoured collar |
  | 5 Dad's Colours | 100 | Second wind: once per zone a downing hit leaves you on 1 HP, untouchable 1.5 s | plates in Dad's colours, shoulder crests, every trim gold |

  Once she has a tier, the locker's **Weight** row refits the suit (free, any time):

  | Weight | Armour | Bonus | Looks |
  | --- | --- | --- | --- |
  | Light | half | 10% faster on the ground, grunts notice you 15% slower, wallruns 15% longer | cloth and leather: a wrap that supports her chest and covers her sides, choker with Dad's tag, a nose ring, wrapped arms and shins, a leather shoulder guard and knee pads, her stiletto on a thigh garter |
  | Medium | as listed | armour refills twice as fast | a mechanic's jumpsuit (unzipped in a wide V down past her belly button, a heart window over the top of her glutes, left arm bare with Dad's cog tattoo, right sleeve rolled), a knotted scarf, a cheek plaster, a tool pouch, a canvas yoke, rubber knee caps, a cargo pocket, a wrist computer |
  | Heavy | +60% | every hit lands 15% softer, but 10% slower on the ground | a quilted padded undersuit under titan-hull armour: a breastplate (Dad's titan's core light from tier 4), a comm earpiece, bracers, pauldrons, shin guards, knee cops, hip, elbow, upper-arm and thigh plates, a back plate, an armoured collar |

  Tier 5 also costs a lock core. The armour pieces are part of `eco.glb` (`suit_t<tier>_*`
  meshes, modelled by `suit_armor()`, `light_suit()` and `medium_suit()`, `heavy_extras()` in
  `tools/eco/build_eco_vroid.py`; each weight also bakes its own bodysuit cut,
  `v_body*_light.png`, `v_body*_medium.png` and `v_body*_heavy.png`); `eco_model.gd` `suit_tier` and
  `suit_weight` show them.

On the screens: W/S pick a row, A/D browse, Space buy or fit, Tab or Q/E switch section,
F or Esc to leave. Progress saves to `user://armory.cfg` (`scripts/hub/armory.gd` has every
price and number). The sidearms and attachments are modelled by
`tools/pistol/build_sidearms.py`, the benches by `tools/hub/build_benches.py`, the crates,
nodes and pickups by `tools/run/build_loot.py` (all `blender -b --python <script>`).

Press **F** near anything to have Eco say something about it; press again for more.
Built in code by `scripts/hub/hub_builder.gd` and `hub_grounds.gd` (temple stone,
carvings, timber, alloy, moss, wood, grass, dirt, canvas and bark textures come from
`tools/make_textures.py`).
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
   **Zone 2: Blackwater.** A flooded fen at dusk in the rain, where the colony runs its
   fuel line. You start on the bank where Eco left her skiff and wade north through
   knee-deep water and swamp cypress: the roadblock on the old causeway, a stilt village the
   colony took from the fishers (lookouts on the porches, a squad dug in on the road), the
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
   craters and wrecks under a smoky sky, where the colony strips the dead titans for parts.
   You start behind the war's front-line trench: no-man's land (wire, craters, a titan dead on
   its knees, the picket), the salvage yard (wall and gate, a gantry crane over a titan they're
   stripping, the strip shed, container stacks, a watchtower), the rift (wallrun a titan's
   tower shield wedged in it, grapple the crane, hop the precursor columns standing in it, or
   walk a fallen precursor obelisk), the ruins of the precursor's shrine where the colony set
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
   checkpoint. At 0 the run is over.

   **Uncharted zones (the long way).** At the far end of the hub's mission table is a second
   sheet, UNCHARTED: press F there and the run goes through the three zones above and then
   two more that are generated from the run's seed, before the titan fight. See
   *Generated zones* below.
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
`zone_kit.gd` (zones 2 and 3's props and their colliders), `procgen/` (generated zones),
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

## Generated zones

`scripts/run/procgen/` builds a zone from a seed. `level_plan.gd` plans it as plain data,
`zone_generator.gd` builds it, `biome.gd` dresses it, and `nav.gd` bakes its navmesh.
- **Lanes.** The valley has 3 to 5 lanes running up it side by side, about 22 m apart, with
  woods (or reeds, or wreckage) between them. **Loud**: the road up the middle, through the
  yards, gates and bridges, where the squads are dug in. **Quiet**: a sunken gully with tall
  grass on its banks (crouch in the bed and you're hidden). It goes under walls through
  culverts and over chasms on a fallen log, a dead titan or an obelisk. **High**: a rock
  ridge 4 m up that turns into a row of rooftops through the yards, a catwalk over the
  walls, and stepping-stone pillars over the chasms. Crate steps climb onto each ridge from
  the road side. A fourth and fifth lane add another quiet or high lane on the far side.
- **Sections** cross every lane in turn: start, field (open wilds with a grunt patrol), picket,
  wall (a breach on the road, a gate, culverts, catwalks, a watchtower), outpost and camp
  (yards with buildings, a dug-in squad, a watchtower, tents and grass on the quiet side, a
  sentry walking the yard, and one salvage cache each: one guarded by the squad, one on the
  rooftops), resource (a titan wreck between two lanes with alloy to mine and two grunts
  picking it over), ruins (a bombed-out hamlet: house shells along the road with their tall
  walls to it, a sniper upstairs in a shell, a sentry in the street, wrecks and tank traps,
  a water tower or silo to one side), chasm (the Pinewoods' bridge crossing on the road, so it stays inside
  the movement limits) and the extraction beacon. There's always an outpost, a camp, a
  wall and a chasm. The rest, their order, the lane count, the biome (forest, marsh or
  boneyard, using the handmade zones' props) and the zone's name come from the seed. Zones
  further into the run are longer and more heavily guarded.
- **Set pieces.** On top of the handmade zones' props, generated zones have their own kit
  (`set_pieces.gd`, models in `assets/models/procgen/`), mixed in by the seed so no two
  zones are built the same. Buildings: bunker, two-storey blockhouse (stairs to the roof),
  garage, warehouse, silo, water tower, scaffold, two bombed-out house shells, tower crane.
  Movement: billboards to wallrun (6, 10 and 16 m), blast-wall lines, a kick slot (two
  walls 3.4 m apart to wall-jump up between, a deck at the top), a leaning slab, grapple
  masts (13 and 9 m) and a hook bracket. Props: jersey barriers, tank traps, tyres, cable
  reels, burnt-out jeeps, fire barrels, concrete pipes, supply pods, warning signs and a
  sandbag MG nest. Blue trim means run or kick off it; an orange block is a grapple hook.
  Round two adds a cabin, quonset hut, radio hut (hook up its mast) and low blockhouse;
  plywood, container and titan-hull walls (12 m) to wallrun; a corner kick (wallrun into a
  corner, kick and double jump over onto a deck), a pillar ledge (hop a pillar onto a
  block), a scaffold roost (grapple up onto a deck 7 m up), a hook pole planted behind a
  wall, and a chasm's blast shield hung between lattice towers; and props: ammo crates,
  comms dish, lamp post, tarp shelter, field table, plus the biome's own (lumber and
  woodpiles in the forest; rowboats, net racks and buoys in the marsh; titan ribs, hull
  plates and engine blocks in the Boneyard). Each zone draws its own mix (`biome.gd`
  `kit()`): 7-9 props, three kinds of building, two kinds of wall, two climbs, a pier or
  towers over the chasm, a hook bracket or pole on the wall. A supply crate waits on top of
  every climb, roost and water tower.
  Yards pick their barracks (hut, bunker, blockhouse, garage), centrepiece (the biome's own
  or the warehouse) and landmark (fuel tank, silo, water tower, crane); a rooftop run is
  huts, scaffolds or bunkers; a chasm's grapple is the crane pylon or a tower crane; walls
  get a hook to grapple straight over. Open stretches get a wall to run beside the road, a
  kick slot or scaffold up beside each ridge, a mast between the road and the next lane,
  and slabs fallen against the gullies' banks. Each piece's colliders, hooks and tops come
  from `prop_shapes.gd`, which `tools/procgen/build_props.py` writes with the models
  (`blender -b --python tools/procgen/build_props.py`, or `python3` with the `bpy` module).
  `xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/procgen/kit_shots.gd
  -- /some/dir forest` saves a picture of each piece and a sheet of them all.
- **Pathing.** Each zone bakes a navmesh from its own colliders on a thread once it's
  loaded. Grunts with a `patrol` (grunt.gd) walk their loop on it, pausing at each point to
  look round. A patrol that loses sight of the pilot hunts toward where they were last seen
  along it. Anyone else who needs to walk the zone can use `Nav.path()`.
- **Loot.** Supply crates go on the lanes' verges, banks and ridge tops (never over a chasm),
  and alloy nodes go round the wrecks first (`info["loot_spots"]`, `info["loot_counts"]`).
- **Maps.** `zone_map.gd` draws a top-down map of a plan, or of a built zone with its grunts,
  patrols, caches, loot, walls to run (blue) and grapple hooks (orange). `xvfb-run -a godot --path . --rendering-driver opengl3 -s
  res://tools/procgen/maps.gd -- /some/dir 101 202 303` saves one per seed (`--plan` skips
  building, `--lanes=N`, `--biome=marsh`). `godot --path . -s res://tools/procgen/shots.gd --
  /some/dir 101` saves screenshots of one generated zone.
- **Tests.** `godot --headless --path . -s res://tests/procgen_test.gd` plans 60 seeds and
  builds six zones. It checks the crossings and rooftop gaps against the movement limits,
  that grunts and caches stand on something, that the patrols can walk their loops on the
  navmesh, that loot settles, that every grapple hook can be reached from a lane, and that a
  long run reaches the uncharted zones. `tests/set_pieces_test.gd` loads every set piece and
  has the real player controller kick up a kick slot, run a billboard, grapple a mast, climb
  a corner kick and a pillar ledge, and grapple up onto a scaffold roost.

## Level 1: The Deepwood

The first real level after the tutorial run (`scripts/run/levels.gd`). It opens from the
**mission table** in the temple's nave once you've won the Pinewoods run (bring
a titan home once; older saves that have banked a lock core count). A level run is one long
generated forest valley, laid out fresh from the run's seed every time, built to the level's
own spec:

- **Harder than the tutorial.** Generated at difficulty 4: three extra sections, sometimes a
  second chasm, bigger squads, grunts that hit harder and see further. Grunts only: the Choir
  and wildlife stay past the border.
- **The salvage depot** (section `depot`): a yard like the outpost with the titan part the
  colony crated up on a flatbed, the scrapped titan it came off, containers and a second
  watchtower. Its squad is bigger and the crate stays locked until every guard is down. Its
  offer is always top grade (tier 3). The outpost's and camp's caches are there too.
- **The clearing** (section `finale`, in place of the extraction beacon): the valley opens
  into a wide flat clearing with their titan parked on the road and the evac pad behind it,
  blast walls and wrecks for titan cover, two grunts dug in where the road comes out. Walk
  out into it and it's titanfall right there, no separate arena: call yours, fight, walk it
  to the evac. Winning marks the level cleared in the armory save (`[progress] cleared`).
- Hint cards for the level (intro, the depot, the clearing) come from `tutorial.gd`.
- **Maps.** `xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/procgen/maps.gd
  -- /some/dir 5150 2024 --level=level1` draws the level for those seeds.
- **Tests.** `godot --headless --path . -s res://tests/level1_test.gd` plans 40 seeds (depot,
  flat clearing last), then plays one: the board locked and unlocked, the depot locked behind
  its squad with a top grade offer, the clearing starting the fight, the titan dropping inside
  it, and the evac completing and saving the level.

## Art: Anime look (with the PS3 and old PS2 looks on F9)
Everything is stylized in the spirit of Jak and Daxter and Shadow of the Colossus. The
default **Anime look** paints the world to match the toon-shaded characters, with a
late-90s anime finish. **F9** cycles Anime, PS3 and PS2 to compare.

- **Anime look** (default): the PS3 look's lighting and haze, but `ps2_surface` (the
  `anime_look` shader global) reads textures from a blurrier mip, squashes their grain
  toward their broad colour and posterises brightness into a few flat tones; no normal
  maps or highlights; cel lighting with lavender shadows and hard-edged lamp pools.
  `assets/shaders/anime_post.gdshader` (a full-screen quad the PS2 autoload keeps on the
  current camera) paints the set with a Kuwahara filter (characters stay crisp: the set
  writes roughness 0.5, the toon characters 1.0), draws ink lines from depth and normal
  breaks, and grades it: warm highlights, cool shadows, halation, vignette, film grain
  (Settings > Video > Film grain). Concepts: `tools/art/style_shots.gd`.
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
A 21-year-old mechanic and weaponsmith from Solace. When her father, the village's only Pilot, was killed in the war against the off-world colony, the recruiters turned her away for crying, so she fights the colony on her own from a Precursor temple outside town. She fights with
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
  `jiggle_style` picks a tuning from `JIGGLE_STYLES`: classic, anime (slower, floatier, eases
  into its limit) or realistic (firm, quick, mostly vertical). Left unset she follows
  Settings > Game > Jiggle style, live. `tools/eco/jiggle_clips.gd` renders the three side by
  side through a run, jump, landing and turn.
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
- **Reference sheet renders**: `godot res://scenes/eco_showcase.tscn -- --shots=<folder> [--clean] [--suit=<tier>] [--weight=light|medium|heavy] [--only=front,back]`.
  In the showcase, S cycles her suit upgrade tiers and W the suit weight.

## Grunts
- 60 HP, headshots count above the shoulders. Visor glows red during a 0.4 s wind-up before each shot.
- Once alerted they hold around 12 m, strafe, and fire a single 8-damage round every ~1.5 s.
- **Their aim depends on how you move**: about 63% hit chance on a still pilot, ~14% at sprint speed, near zero while wallrunning.
- You have 100 HP that regenerates after 3 s without damage. Dying respawns you and resets the arena.

## Stealth
Grunts start **unaware** and have to notice you first.
- **Vision**: a 50° forward cone (each side). Unaware grunts only notice you within 70% of their sight range (about 28 m in the test level, 25-32 m in run zones); once alerted they track you out to the full range (40 m, 35-45 m). Unaware grunts slowly sweep their gaze around their post. Behind them or out of range they see nothing.
- **Cover** blocks sight. A crouched pilot behind a low wall is hidden; standing up shows your head.
- **Tall grass** (the forest's hiding spots): crouch in it and grunts can't see you past 3 m; standing in it cuts how fast they notice you to 30%. Dense foliage blocks sight like a wall.
- **Detection meter**: fills while they can see you, fast up close (under a second at 5 m), slowly far away (6 s or more near the edge of their notice range). Moving fast doubles it, crouching cuts it to about a third, showing only part of yourself past cover cuts it to 40%, and the edge of their vision is much slower. It starts draining 1.5 s after you break sight.
- **Hearing**: footsteps carry with speed (a sprint about 5 m, a crouch walk well under 1 m; no footsteps in the air). The suppressed pistol is still heard out to 20 m, and within about 7 m it alerts outright. Bumping into a grunt always gets noticed.
- **Over each grunt**: a **?** that grows from yellow to orange as it notices you (half full, it turns to look), then a red **!** once alerted. Visible through cover.
- **Around the crosshair**: an arc points at every grunt noticing you, including ones behind you, and fills toward red.
- **Sneak attacks**: anything that hits a grunt that hasn't noticed you does double damage, so a pistol headshot on an unaware grunt kills outright.
- **Knife** (Z or the mouse thumb button): **tap** for a quick strike from Eco's left hand, 2.4 m reach, with the gun still in the other. **Hold for about a second** to draw the knife as her weapon: the gun goes away (it can't fire), Eco runs 20% faster, left mouse attacks (two alternating moves, light trail off the tip) and I plays the knife's inspect. Tap Z again, press R or roll the mouse wheel (`swap_weapon`, rebindable) to put it away; the gun comes back up with its draw. Each knife moves its own way (`scripts/knife_moves.gd`): the **Needle** is held like a foil (a finger-roll draw off its ring pommel, quick straight thrusts, a ring-spin inspect), the **Plate Kunai** in reverse grip (flipped into it on the draw, hooking and hammer slashes, a twirl round her finger in its ring), and the **Butterfly** comes out closed and flips open (snappy wrist flicks, rollovers and an aerial on the inspect). Every knife hits on the same beat. On an unaware grunt any strike becomes that knife's takedown thrust. She carries the knife picked at the hub's knife case (Needle, Plate Kunai or Butterfly), all three built in Blender by `tools/knife/build_knives.py`. On an unaware grunt it's a silent takedown that kills instantly; on one that knows you're there it does 30 damage and alerts it. The pistol can't fire mid-stab.
- **Alerted** grunts fight exactly as before, and call in every squadmate within 16 m. Getting shot always alerts. Out of sight for 10 s, they lose you and go back to searching.

## Enemy radio
Get within about 45 m of grunts and Eco picks up their squad net. A small **INTERCEPT** box
above your health shows who's talking (amber callsigns, colony command in red) as the lines type out
through static. She only listens; she never talks back.
- **Calm squads** trade banter, gossip about "the Pilot reject" (they don't know she's listening), and pass
  around salvage rumours naming real titan parts.
- **Squad state drives the calls**: "something moved" when one turns suspicious, a stand-down when it
  gives up, one contact call when she's spotted, fight taunts (and panic when she's wallrunning or
  sliding), cheers when they hit her, "lost her" when they lose track, man-down calls naming the dead,
  a terrified last man, and HQ calling into silence once the squad is gone.
- Bigger events cut off small talk; lines never repeat back to back, and every exchange plays before any repeats.
- Speakers near the edge of range break up: fewer signal bars and garbled characters.
- **Dialogue rating**: press **O** to switch between Teen and Mature (saved between sessions; default M). Not F8: that stops the game when it runs from the Godot editor.
  Each rating has its own line files in `dialogue/`. `scripts/radio/content_rating.gd`
  holds the setting.
- Lines live in `scripts/radio/radio_lines.gd`, one exchange per string (`"a: ... | b: ... | hq: ..."`).
  `radio_chatter.gd` emits `line_started(callsign, text, category)` for voice-over later.

## Test level
- Ahead: **wallrun corridor** (two long parallel walls).
- Right: **wall-jump course**, zig-zag panels over red "lava" between two platforms.
- Left: **slide ramp**, walk up, turn around, crouch and slide down.
- Behind: **grapple towers** with floating platforms.
- Far right (about 60 m): **grunt arena** with six grunts, cover, and wallrun walls on both sides.

## Movement feel
Running on foot is tight: full sprint in about a tenth of a second, and letting go or switching
direction stops you almost dead. Speed above a sprint (from a slide, wallrun or grapple) is kept
for a moment after landing, then bleeds back to a run unless you slide. Hold or tap crouch in the
air just before touching down to land straight into a slide that keeps your speed; landing from a
big drop into a slide also turns part of the fall into forward speed. A slide started by a tap
keeps going on its own until you jump, slow down or tap crouch again.

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
- `dialogue/` every radio and whisper line as plain text, one file per rating; edit and press O in
  game to reload. Format and situation names: `dialogue/README.md`
- Eco's whispers (`scripts/radio/`): she can't answer the colony grunts on their net, so she talks back
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
- `tests/ground_feel_test.gd` running feel (quick starts, stops, reversals and turns; landing
  speed bleeds unless you slide; slide pressed just before landing; drop-into-slide boost):
  `godot --headless --path . -s res://tests/ground_feel_test.gd`
- `tests/combat_test.gd` headless combat smoke test:
  `godot --headless --path . -s res://tests/combat_test.gd`
- `tests/stealth_test.gd` headless stealth test (vision cone, sight range, cover, detection meter,
  gunshots, squad callouts, losing the pilot): `godot --headless --path . -s res://tests/stealth_test.gd`
- `tests/eco_test.gd` Eco's model (toon materials, expression, animations, hair and jiggle
  springs bounce and settle): `godot --headless --path . -s res://tests/eco_test.gd`
- `tests/armory_test.gd` headless workbench test (prices, upgrades, attachments, titan parts and
  refits, saving, the bench screens changing your gun, crates, alloy nodes and grunt drops):
  `godot --headless --path . -s res://tests/armory_test.gd`
- `tests/suit_test.gd` Eco's suit upgrades (tiers bought in order, armour soaking hits and
  coming back, each passive, the second wind, armour pieces per tier, the suit locker):
  `godot --headless --path . -s res://tests/suit_test.gd`
- `tools/hub/bench_shots.gd` screenshots of the benches, their screens, the guns and the loot
  (needs a renderer): `xvfb-run -a godot --path . -s res://tools/hub/bench_shots.gd -- out_dir`
  (add `knives` for just the knife case, its screen and each knife in her hand)
- `tools/knife/knife_shots.gd` quick stills of each knife's moves in her hand and the knife
  case screen, no level loaded: `xvfb-run -a godot --path . -s res://tools/knife/knife_shots.gd -- out_dir [frames|clips]`
  (`clips` writes 30 fps frames per knife for ffmpeg)
- `tools/hub/base_shots.gd` screenshots of the temple base: the hall, the stairs and loft
  bedroom, the lore, mission table and armour bench, the poster and its marker, and the tents
  inside and out: `xvfb-run -a godot --path . -s res://tools/hub/base_shots.gd -- out_dir [--only=hall,loft]`
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
  spot, the stairs up to the loft, the bed, letter and wardrobe upstairs, the tents outside,
  the poster and its marker, the grounds are closed in, range targets, the course
  clock, the practice titan and dummies, the poster starts a run, runs return to the hub):
  `godot --headless --path . -s res://tests/hub_test.gd`
