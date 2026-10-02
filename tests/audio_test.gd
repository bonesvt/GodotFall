extends SceneTree
## Headless check that the recorded sounds load and the helpers find them.
## Run: godot --headless --path . -s res://tests/audio_test.gd

const SFX := preload("res://scripts/sfx.gd")
const Ambience := preload("res://scripts/ambience.gd")

var failures := 0


func _check(ok: bool, what: String, detail: Variant = "") -> void:
	print("%s  %s  (%s)" % ["ok   " if ok else "FAIL ", what, str(detail)])
	if not ok:
		failures += 1


func _init() -> void:
	# Every sound the game plays has a recording now.
	for id in ["pistol", "pistol_last", "dry_click", "spark", "lock_err", "reload_out", "reload_in", "boot",
			"twirl", "flourish", "whack", "hit_body", "hit_head", "kill", "ricochet", "impact",
			"knife_swish", "knife_draw", "knife_hit", "knife_spin", "knife_catch", "grunt_shot",
			"xo16", "xo16_spin", "tracker", "tracker_boom", "splitter", "scrap", "scrap_jam", "titan_hit"]:
		var s := SFX.stream(id)
		_check(s is AudioStreamOggVorbis and s.get_length() > 0.05, "recording for " + id, s)
	for base in ["step_grass", "step_concrete", "step_wood", "step_metal", "titan_step", "titan_servo",
			"grunt_hurt", "grunt_pain"]:
		var id := SFX.variant(base)
		_check(id.begins_with(base + "_") and SFX.has_recording(id), "variant of " + base, id)
	_check(SFX.variant("no_such_sound") == "", "missing variant is empty")
	_check(SFX.play(root, "") == null, "empty id plays nothing")

	var amb := Ambience.start(root, {"forest_day": -10.0, "forest_wind": -16.0, "not_a_bed": 0.0})
	_check(amb.get_child_count() == 2, "ambience skips missing beds", amb.get_child_count())
	await process_frame
	for p in amb.get_children():
		var player := p as AudioStreamPlayer
		_check((player.stream as AudioStreamOggVorbis).loop, "%s loops" % p.name)
		_check(player.playing, "%s is playing" % p.name)

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
