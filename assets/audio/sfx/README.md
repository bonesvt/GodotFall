# Recorded sounds

Every sound the game plays has a recording here. `scripts/sfx.gd` plays
`<id>.ogg` (or `<id>.wav`) from this folder when it exists and falls back to
its synthesized recipe otherwise, so deleting a file brings the old synth
sound back. Numbered takes such as `step_grass_1` ... `step_grass_5` are
picked at random with `SFX.variant("step_grass")`. Looping beds live in
`../ambience/` and are started with `scripts/ambience.gd`.

All files are cut from CC0 (public domain) recordings on OpenGameArt and
kenney.nl: trimmed, layered, filtered, pitched and normalized, then saved as
mono Ogg Vorbis (ambience beds are stereo). CC0 needs no credit, but the
people who recorded them are listed below. Where a pack is dual-licensed we
use it under its CC0 option. `tools/audio/` holds the specs that rebuild
every file from the original downloads.

## Where each sound is used

| Group | Ids | Plays |
| ----- | --- | ----- |
| Eco's pistol | `pistol` `pistol_last` `dry_click` `reload_out` `reload_in` `boot` `twirl` `flourish` `whack` `lock_err` `spark` | weapon.gd |
| Hits | `hit_body` `hit_head` `kill` `ricochet` `impact` | weapon.gd |
| Stiletto | `knife_draw` `knife_swish` `knife_hit` `knife_spin` `knife_catch` | knife.gd |
| Grunts | `grunt_shot`, `grunt_hurt_*` (wounded), `grunt_pain_*` (death cries, not on stealth kills) | grunt.gd |
| Titan guns | `xo16` `xo16_spin` `tracker` `tracker_boom` `splitter` `scrap` `scrap_jam` `titan_hit` | titan_gun.gd |
| Titan | `titan_step_*` `titan_servo_*` (walking), `titan_embark` + `titan_boot` (climbing in), `titan_hiss_short` (dash), `titan_doom_laser` / `titan_core_charge` / `titan_hiss` (laser, shield, overdrive cores), `titan_clang` + `debris_rock` (landfall), `explosion_big` (destroyed) | titan.gd |
| Eco's feet | `step_grass_*` `step_concrete_*` `step_wood_*` `step_metal_*` (by the floor's `surface` meta), `land` `land_heavy` | player.gd |
| Radio | `radio_squelch_on` | radio_chatter.gd |
| Ambience | forest zone: `forest_day` `forest_wind` `forest_birds`; forest's edge: `forest_wind` `forest_night`; temple hub: `temple_interior` `temple_drips` `wind_soft` `forest_birds` | forest_builder.gd, hub_builder.gd |

Recorded but not wired in yet, ready for later: `step_gravel_*`,
`cloth_*`, `knife_sheathe`, `shell_casing`, `mag_drop`, `heartbeat`, `flare`,
`titan_powerdown`, `titan_core_drain`, `titan_rocket`, `titan_metal_creak`,
`titan_hiss`, `splitter_beam_loop`, `explosion_small` `explosion_far`
`explosion_muffled` `explosion_metal`, `debris_metal`, `glass_break`,
`grunt_yell_*` `grunt_effort_*` `grunt_hey` `grunt_kill_you`,
`radio_squelch_off` `radio_static_burst` `radio_dead`, `door_iron`
`door_stone` `door_metal_open` `door_metal_close`, `cache_unlock`
`cache_open`, `pickup_part`, `workbench_drill` `workbench_ratchet`
`workbench_hammer` `workbench_tools` `workbench_squeeze`, `tree_creak`,
`ui_click` `ui_hover` `ui_confirm` `ui_error` `ui_switch` `ui_terminal`, and the
beds `forest_morning` `swamp_creek` `rain` `temple_eerie` `campfire`
`machine_hum` `radio_static_loop`.

## Sources

| Pack | Uploaded by | Licence used | Files made from it |
| ---- | ----------- | ------------ | ------------------ |
| [100 CC0 metal and wood SFX](https://opengameart.org/content/100-cc0-metal-and-wood-sfx) | rubberduck | CC0 | `cache_open`, `cache_unlock`, `door_metal_close`, `door_metal_open`, `titan_embark`, `titan_hit`, `whack` |
| [15 vocal male strain/hurt/pain/jump sounds](https://opengameart.org/content/15-vocal-male-strainhurtpainjump-sounds) | qubodup | CC0 | `grunt_hurt_*` |
| [16 button clicks](https://opengameart.org/content/16-button-clicks) | qubodup | CC0 | `radio_squelch_off`, `ui_click` |
| [27 Metal Audio Samples (SFX)](https://opengameart.org/content/27-metal-audio-samples-sfx) | blacklodgegames | CC0 | `titan_clang`, `titan_metal_creak`, `titan_step_*` |
| [31 pings and metal filing sounds](https://opengameart.org/content/31-pings-and-metal-filing-sounds) | bart | CC0 | `flourish`, `ricochet` |
| [37 hits/punches](https://opengameart.org/content/37-hitspunches) | qubodup | CC0 | `hit_body`, `hit_head`, `whack` |
| [4 Atmospheric ghostly loops](https://opengameart.org/content/4-atmospheric-ghostly-loops) | qubodup | CC0 | `temple_eerie` |
| [40 wet towel club/pound/hit/attack sounds](https://opengameart.org/content/40-wet-towel-clubpoundhitattack-sounds) | qubodup | CC0 | `knife_hit` |
| [42 Snow and Gravel Footsteps](https://opengameart.org/content/42-snow-and-gravel-footsteps) | qubodup | CC0 | `step_gravel_*` |
| [50 CC0 Sci-Fi SFX](https://opengameart.org/content/50-cc0-sci-fi-sfx) | rubberduck | CC0 | `boot`, `pistol_last`, `ui_terminal` |
| [6 user interface ding clicks](https://opengameart.org/content/6-user-interface-ding-clicks) | qubodup | CC0 | `ui_confirm`, `ui_error` |
| [68 Workshop Sounds](https://opengameart.org/content/68-workshop-sounds) | bart | CC0 | `pickup_part`, `workbench_drill`, `workbench_hammer`, `workbench_ratchet`, `workbench_tools` |
| [75 CC0 breaking / falling / hit sfx](https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx) | rubberduck | CC0 | `debris_metal`, `debris_rock`, `glass_break`, `hit_head`, `impact`, `mag_drop`, `ricochet`, `titan_hit` |
| [Aggressive NPC sounds "Hey", "I will kill you"](https://opengameart.org/content/aggressive-npc-sounds-hey-i-will-kill-you) | mujtaba-io | CC0 | `grunt_hey`, `grunt_kill_you` |
| [AMB Morning Sounds (Perfect Loop)](https://opengameart.org/content/amb-morning-sounds-perfect-loop) | Kresiek The Furry | CC0 | `forest_morning` |
| [AMB Outside 1](https://opengameart.org/content/amb-outside-1) | Kresiek The Furry | CC0 | `forest_day` |
| [Ambient Bird Sounds](https://opengameart.org/content/ambient-bird-sounds) | isaiah658 | CC0 | `forest_birds` |
| [Chunky Explosion](https://opengameart.org/content/chunky-explosion) | Joth | CC0 | `tracker_boom` |
| [Compressed Gas Leak SFX](https://opengameart.org/content/compressed-gas-leak-sfx) | 0new4y | CC0 | `titan_embark` |
| [Crickets Ambient Noise - loopable](https://opengameart.org/content/crickets-ambient-noise-loopable) | Wolfgang_ | CC0 | `forest_night` |
| [Deep Bone Crack/Break SFX](https://opengameart.org/content/deep-bone-crackbreak-sfx) | Zane Little Music | CC0 | `kill` |
| [Doomsday Laser Cannon Sound Effect](https://opengameart.org/content/doomsday-laser-cannon-sound-effect) | TAD | CC0 | `titan_doom_laser` |
| [Dripping water loop](https://opengameart.org/content/dripping-water-loop) | qubodup | CC0 | `temple_drips` |
| [Electricity Game Sound Pack](https://opengameart.org/content/electricity-game-sound-pack) | faxcorp | CC0 | `splitter`, `titan_boot`, `titan_core_charge`, `titan_powerdown` |
| [Electricity Sound Effects](https://opengameart.org/content/electricity-sound-effects-0) | BMacZero | CC0 | `lock_err`, `spark`, `splitter` |
| [Energy Drain](https://opengameart.org/content/energy-drain) | qubodup | CC0 | `titan_core_drain` |
| [Explosion somewhere far](https://opengameart.org/content/explosion-somewhere-far) | pauliuw | CC0 | `explosion_far` |
| [Explosions](https://opengameart.org/content/explosions-4) | EZduzziteh | CC0 | `explosion_big`, `explosion_small` |
| [Fantasy Weapons and Apparel SFX Library](https://opengameart.org/content/fantasy-weapons-and-apparel-sfx-library) | Vehicle | CC0 | `knife_draw`, `knife_sheathe`, `land`, `land_heavy` |
| [Fire Crackling](https://opengameart.org/content/fire-crackling) | AntumDeluge | CC0 | `campfire` |
| [Flare ignition](https://opengameart.org/content/flare-ignition) | qubodup | CC0 | `flare` |
| [Footsteps Leather, Cloth, Armor](https://opengameart.org/content/footsteps-leather-cloth-armor) | HaelDB | CC0 | `cloth_*`, `knife_catch`, `pickup_part`, `step_metal_*` |
| [Generator (loop)](https://opengameart.org/content/generator-loop) | YCbCr | CC0 | `machine_hum` |
| [grunts of male death and pain](https://opengameart.org/content/grunts-male-death-and-pain) | thebardofblasphemy | CC0 | `grunt_pain_*` |
| [Gun Reload Sound Effects](https://opengameart.org/content/gun-reload-sound-effects) | BMacZero | CC0 | `pistol`, `shell_casing` |
| [Gun reload, lock or click sound](https://opengameart.org/content/gun-reload-lock-or-click-sound) | pauliuw | CC0 | `dry_click`, `pistol_last` |
| [Handgun Reload Sound Effect](https://opengameart.org/content/handgun-reload-sound-effect) | zer0_sol | CC0 | `reload_in`, `reload_out` |
| [Heartbeat (single sound)](https://opengameart.org/content/heartbeat-single-sound) | qubodup | CC0 | `heartbeat` |
| [Hollywood-style pistol silencer sound effect](https://opengameart.org/content/hollywood-style-pistol-silencer-sound-effect) | bart | CC0 | `pistol`, `pistol_last` |
| [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 | `land_heavy`, `step_concrete_*`, `step_grass_*`, `step_wood_*` |
| [Interface Sounds](https://kenney.nl/assets/interface-sounds) | Kenney | CC0 | `lock_err` |
| [Iron Door](https://opengameart.org/content/iron-door) | themightyglider | CC0 | `door_iron` |
| [Loopable Dungeon Ambience](https://opengameart.org/content/loopable-dungeon-ambience) | JaggedStone | CC0 | `temple_interior` |
| [Male Grunt/Yelling sounds](https://opengameart.org/content/male-gruntyelling-sounds) | HaelDB | CC0 | `grunt_effort_*`, `grunt_yell_*` |
| [Mech Stomp / Step Sound](https://opengameart.org/content/mech-stomp-step-sound) | hc | CC0 | `titan_step_*` |
| [Mechanical Explosion](https://opengameart.org/content/mechanical-explosion) | Spring Spring | CC0 | `explosion_metal` |
| [Mechanical Sounds](https://opengameart.org/content/mechanical-sounds) | BMacZero | CC0 | `scrap`, `scrap_jam`, `titan_embark`, `titan_servo_*` |
| [Mild Wind Background Noise](https://opengameart.org/content/mild-wind-background-noise) | Bashar3A | CC0 | `wind_soft` |
| [Misc/menu sci-fi sounds.](https://opengameart.org/content/miscmenu-sci-fi-sounds) | HaelDB | CC0 | `radio_squelch_off`, `radio_squelch_on`, `ui_hover` |
| [Missile sound](https://opengameart.org/content/missile-sound) | mikeask | CC0 | `tracker` |
| [Muffled Distant Explosion](https://opengameart.org/content/muffled-distant-explosion) | NenadSimic | CC0 | `explosion_muffled` |
| [Quick Drill Fix](https://opengameart.org/content/quick-drill-fix) | qubodup | CC0 | `workbench_squeeze` |
| [Radio Death Sound](https://opengameart.org/content/radio-death-sound) | Vinrax | CC0 | `radio_dead` |
| [Radio Noise 1](https://opengameart.org/content/radio-noise-1) | Kresiek The Furry | CC0 | `radio_static_loop` |
| [Rain (loopable)](https://opengameart.org/content/rain-loopable) | Ylmir | CC0 | `rain` |
| [Robotic Transformations](https://opengameart.org/content/robotic-transformations) | Mekaal | CC0 | `titan_servo_*`, `xo16_spin` |
| [Rocket launch](https://opengameart.org/content/rocket-launch) | qubodup | CC0 | `titan_rocket` |
| [Seamless Energy Emission Loop](https://opengameart.org/content/seamless-energy-emission-loop) | zeroisnotnull | CC0 | `splitter_beam_loop` |
| [SFX - Circuit breaker](https://opengameart.org/content/sfx-circuit-breaker) | CleytonKauffman | CC0 | `titan_boot`, `ui_switch` |
| [Silencers - By EmoPreben](https://opengameart.org/content/silencers-by-emopreben) | EmoPreben | CC0 | `pistol`, `pistol_last` |
| [Static](https://opengameart.org/content/static) | xhunterko | CC0 | `radio_static_burst` |
| [Steam release sounds](https://opengameart.org/content/steam-release-sounds) | bart | CC0 | `titan_hiss`, `titan_hiss_short` |
| [Stone Door](https://opengameart.org/content/stone-door) | bonebrah | CC0 | `door_stone` |
| [Swamp Environment Audio](https://opengameart.org/content/swamp-environment-audio) | LokiF | CC0 | `swamp_creek` |
| [Swish - bamboo stick weapon swhoshes](https://opengameart.org/content/swish-bamboo-stick-weapon-swhoshes) | qubodup | CC0 | `twirl` |
| [Swishes Sound Pack](https://opengameart.org/content/swishes-sound-pack) | artisticdude | CC0 | `knife_spin`, `knife_swish` |
| [The Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library) | bart | CC0 | `grunt_shot`, `scrap`, `xo16` |
| [Tree Creaking](https://opengameart.org/content/tree-creaking) | AntumDeluge | CC0 | `tree_creak` |
| [wind1](https://opengameart.org/content/wind1) | Luke.RUSTLTD | CC0 | `forest_wind` |
