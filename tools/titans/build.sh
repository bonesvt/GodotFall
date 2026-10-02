#!/bin/sh
# Rebuilds every titan and titan weapon, reimports, and (with --shots DIR)
# renders the showcase. Needs blender 4 and godot 4.3 on PATH (xvfb-run for
# shots on a headless box).
set -e
cd "$(dirname "$0")/../.."
python3 tools/titans/make_wear.py
blender --background --python tools/titans/build_titans.py -- assets/models/titans 2>&1 | grep -E "exported|Error|Traceback" || true
# Fresh .glb files import once without the script, so point them at it and reimport.
godot --headless --import >/dev/null 2>&1 || true
sed -i 's|import_script/path=""|import_script/path="res://assets/models/titans/titan_import.gd"|' assets/models/titans/*.glb.import
touch assets/models/titans/*.glb
godot --headless --import >/dev/null 2>&1 || true
if [ "$1" = "--shots" ]; then
	xvfb-run -a -s "-screen 0 1280x1024x24" godot -s res://tools/titans/showcase.gd -- --out="$2" >/dev/null 2>&1
fi
