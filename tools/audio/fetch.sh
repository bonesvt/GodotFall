#!/bin/sh
# Downloads the CC0 packs the sounds are cut from into $SND (default /tmp/snd).
# OpenGameArt packs: https://opengameart.org/content/<slug>. Kenney packs: kenney.nl/assets/<slug>.
# Unzip/un-7z everything in place afterwards (python3 -m pip install py7zr).
set -e
SND=${SND:-/tmp/snd}
mkdir -p "$SND/oga/raw" "$SND/kenney"
for k in sci-fi-sounds impact-sounds interface-sounds digital-audio rpg-audio ui-audio; do
  url=$(curl -sL "https://kenney.nl/assets/$k" | grep -oE 'https://kenney.nl/media/pages/assets/[^"]+\.zip' | head -1)
  curl -sL -o "$SND/kenney/$k.zip" "$url" && unzip -qo "$SND/kenney/$k.zip" -d "$SND/kenney/$k"
done
for slug in 100-cc0-metal-and-wood-sfx 15-vocal-male-strainhurtpainjump-sounds 16-button-clicks 27-metal-audio-samples-sfx 31-pings-and-metal-filing-sounds 37-hitspunches 4-atmospheric-ghostly-loops 40-wet-towel-clubpoundhitattack-sounds 42-snow-and-gravel-footsteps 50-cc0-sci-fi-sfx 6-user-interface-ding-clicks 68-workshop-sounds 75-cc0-breaking-falling-hit-sfx aggressive-npc-sounds-hey-i-will-kill-you amb-morning-sounds-perfect-loop amb-outside-1 ambient-bird-sounds chunky-explosion compressed-gas-leak-sfx crickets-ambient-noise-loopable deep-bone-crackbreak-sfx doomsday-laser-cannon-sound-effect dripping-water-loop electricity-game-sound-pack electricity-sound-effects-0 energy-drain explosion-somewhere-far explosions-4 fantasy-weapons-and-apparel-sfx-library fire-crackling flare-ignition footsteps-leather-cloth-armor generator-loop grunts-male-death-and-pain gun-reload-lock-or-click-sound gun-reload-sound-effects handgun-reload-sound-effect heartbeat-single-sound hollywood-style-pistol-silencer-sound-effect iron-door loopable-dungeon-ambience male-gruntyelling-sounds mech-stomp-step-sound mechanical-explosion mechanical-sounds mild-wind-background-noise miscmenu-sci-fi-sounds missile-sound muffled-distant-explosion quick-drill-fix radio-death-sound radio-noise-1 rain-loopable robotic-transformations rocket-launch seamless-energy-emission-loop sfx-circuit-breaker silencers-by-emopreben static steam-release-sounds stone-door swamp-environment-audio swish-bamboo-stick-weapon-swhoshes swishes-sound-pack the-free-firearm-sound-library tree-creaking wind1; do
  mkdir -p "$SND/oga/raw/$slug/x"
  curl -sL "https://opengameart.org/content/$slug" | grep -oE 'https://opengameart.org/sites/default/files/[^"]+\.(zip|7z|wav|ogg|mp3|flac)' | sort -u | while read -r f; do
    curl -sL -o "$SND/oga/raw/$slug/$(basename "$f" | sed 's/%20/ /g')" "$f"
  done
done
