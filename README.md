# Titanfall Roguelike (Godot 4)

A pilot movement controller, a movement test level, and the Scrap Titan run loop.

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
| R | Respawn |
| H | Toggle help |

## Scrap Titan run loop
Pressing Play starts a run (`scenes/run.tscn`). The movement test level is still at
`scenes/test_level.tscn` (open it and press F6).

1. **Three zones.** Each is a seeded chain of platforms over a void, linked by gaps you
   clear with a sprint jump, a double-jump climb, a wallrun along a blue wall, or the grapple
   on an orange anchor. Falling costs 25 pilot integrity and puts you back on the last
   platform you stood on. At 0 the run is over.
2. **Salvage.** Each zone has two caches on side platforms. One is guarded: stand in the red
   uplink ring until it completes (a placeholder until real enemies land). Opening a cache
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
stats), `titan.gd`, `boss.gd`, and the cache, uplink and beacon scripts. The titan is its own
node holding the run's parts, so it can later travel with you as a walking base.

## Abilities
- **Sprint** with fast acceleration.
- **Slide**: crouch while running for a speed boost (1.5 s cooldown). Speeds up down slopes. Hold crouch in the air to slide on landing.
- **Slide-hop**: jump out of a slide and keep your speed; landing gives a short window before friction.
- **Double jump**: one air jump that also redirects you toward the keys you hold.
- **Wallrun**: hit a wall at speed while in the air holding W. Lasts up to 1.8 s, slight lift then slow sink, camera tilts. Refreshes the double jump.
- **Wall jump**: Space during (or just after) a wallrun kicks you off the wall.
- **Grapple**: 45 m range, pulls you to the point, 2.5 s cooldown.
- **Air strafing**: you keep momentum in the air but can steer.

## Test level
- Ahead: **wallrun corridor** (two long parallel walls).
- Right: **wall-jump course**, zig-zag panels over red "lava" between two platforms.
- Left: **slide ramp**, walk up, turn around, crouch and slide down.
- Behind: **grapple towers** with floating platforms.

## Tuning
Every number lives in `scripts/player.gd` as an exported variable. Open `scenes/player.tscn`,
select the Player node and tweak values in the Inspector, or change the defaults in the script.

## Files
- `scripts/player.gd` movement controller (state machine: GROUND, AIR, SLIDE, WALLRUN, GRAPPLE)
- `scripts/test_level.gd` builds the test level in code
- `scripts/hud.gd` speedometer, state and cooldown readout
- `tests/movement_test.gd` headless smoke test:
  `godot --headless --path . -s res://tests/movement_test.gd`
- `tests/run_loop_test.gd` headless run loop test (generator limits, a bot pilot clearing the
  hardest gap of each kind, salvage, extraction, titanfall, the fight, win and loss):
  `godot --headless --path . -s res://tests/run_loop_test.gd`
