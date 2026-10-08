extends SceneTree
## Ophelia's obsession (obsession.gd): once they're together, a run started
## without seeing her makes her upset (she won't talk), skipping her again
## starts her obsession, past LACE_AT she laces their smoke dates with
## Keepsake, which turns Eco's spirals rose, pulls her home on runs and drifts
## her lines to Ophelia; the tin in Ophelia's tent sets up the talk
## (obsession_screen.gd), and helping her makes it all wear off. Mature only.
##   godot --headless --path . -s res://tests/obsession_test.gd

const Vices := preload("res://scripts/hub/vices.gd")
const Obsession := preload("res://scripts/hub/obsession.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

var run_node: Node
var player: CharacterBody3D
var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_obsession_armory.cfg"
	run_node.npc_path = "user://test_obsession_npcs.cfg"
	for f in ["user://test_obsession_armory.cfg", "user://test_obsession_armory_vices.cfg", "user://test_obsession_armory_obsession.cfg", "user://test_obsession_npcs.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	# Ophelia is only in the hub once Level 2 has rescued her (run_manager RESCUED_IN).
	var progress := ConfigFile.new()
	progress.set_value("progress", "cleared", ["level2"])
	progress.save(run_node.armory_path)
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(60)
	player = run_node.player
	run_node.hush_pull.triggers._next = INF
	Vices.reset()
	Obsession.reset()
	_check("its own save next to her vices", Obsession.save_path.ends_with("test_obsession_armory_obsession.cfg"), Obsession.save_path)
	var stay: int = run_node.runs_ended

	# Not together: nothing counts.
	Obsession.run_started(false, stay)
	_check("not together: no count", Obsession.skips == 0 and not Obsession.upset, Obsession.skips)

	# Together, out without seeing her: she's upset and won't talk.
	Obsession.run_started(true, stay)
	_check("skipped her once: upset", Obsession.skips == 1 and Obsession.upset and Obsession.meter == 0.0, [Obsession.skips, Obsession.upset])
	run_node.npc_talk.state.set_value("ophelia", "met", true)
	run_node.talk_to("ophelia")
	await _ticks(2)
	_check("she won't talk, this time", run_node.hud.toast_label.text.begins_with("Ophelia (angry") and not run_node.npc_talk.active() and not Obsession.upset, run_node.hud.toast_label.text)
	_check("but Eco saw her", Obsession.seen_stay == stay, Obsession.seen_stay)
	Obsession.run_started(true, stay)
	_check("seeing her first: no skip", Obsession.skips == 0 and not Obsession.upset, Obsession.skips)

	# Skipping her again and again: the obsession starts.
	for i in 3:
		Obsession.run_started(true, stay + 10 + i)
	_check("three skips: obsessed", Obsession.skips == 3 and Obsession.meter == Obsession.OBSESS_PER_SKIP * 2.0, Obsession.meter)

	# Laced smoke dates.
	_check("not laced below LACE_AT", (func(): Obsession.meter = Obsession.LACE_AT - 1.0; return not Obsession.smoke_date()).call(), Obsession.keepsake)
	Obsession.meter = Obsession.LACE_AT
	_check("laced: Keepsake in Eco", Obsession.smoke_date() and Obsession.keepsake == Obsession.LACE, Obsession.keepsake)
	Obsession.keepsake = 60.0
	await _ticks(5)
	var body: Node = player.get_node("EcoBody/Body")
	_check("rose spirals in her eyes", body._swirl_tint == body.ROSE_SWIRL and body._hypno > 0.4, [body._swirl_tint, body._hypno])

	# The pull home on a run, and her lines drifting to Ophelia.
	Obsession.run_started(true, stay + 20)
	Obsession.tick_run(1.0)
	var early := Obsession.crave
	Obsession.tick_run(Obsession.AWAY_FULL)
	_check("the pull home builds on a run", early < 0.1 and Obsession.crave > 0.4, [early, Obsession.crave])
	var drifted := Obsession.drift("Eco: \"I think the left flank is clear if we go now.\"", 0.0, 0)
	_check("her lines drift to Ophelia", drifted.contains(Obsession.DRIFTS[0].trim_prefix("...")) and drifted.ends_with("\""), drifted)
	_check("not every line", Obsession.drift("Eco: \"I think the left flank is clear.\"", 0.99, 0).ends_with("clear.\""), "")

	# The tin in her tent, then having it out.
	_check("the tin's there to find", Obsession.papers_there(), Obsession.keepsake)
	var tin := Vector3.INF
	for spot in run_node.zone_info.get("interactables", []):
		if spot["id"] == "ophelia_papers":
			tin = spot["pos"]
	player.global_position = tin + Vector3(0, 0.1, 0)
	await _ticks(10)
	_check("its prompt", run_node.nearest_hub_spot().get("id", "") == "ophelia_papers", run_node.nearest_hub_spot().get("id", ""))
	await _press("interact")
	await _ticks(2)
	_check("found: KEEPSAKE in her handwriting", Obsession.found and Obsession.talk_waiting() and run_node.hud.toast_label.text.contains("KEEPSAKE"), run_node.hud.toast_label.text)
	run_node.talk_to("ophelia")
	await _ticks(2)
	_check("talking to her now: they have it out", run_node.bench != null and run_node.bench.kind == "obsession", run_node.bench)
	run_node.bench.choose("helped")
	_check("help her", Obsession.resolved == "helped", Obsession.resolved)
	await _until(func(): return run_node.bench == null, 5.0)
	var k := Obsession.keepsake
	var m := Obsession.meter
	Obsession.run_over()
	_check("helping: it wears off over runs", Obsession.keepsake < k and Obsession.meter < m, [Obsession.keepsake, Obsession.meter])
	_check("no more laced dates", not Obsession.smoke_date(), Obsession.keepsake)

	# Teen: none of it.
	ContentRating.set_rating("T", false)
	_check("teen: no obsession", not Obsession.allowed() and Obsession.eyes() == 0.0 and not Obsession.papers_there(), Obsession.allowed())
	ContentRating.set_rating("M", false)
	Obsession.reset()
	Obsession.save()

	print("obsession_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _press(action: String) -> void:
	await physics_frame
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _until(ok: Callable, seconds: float) -> void:
	var left := int(Engine.physics_ticks_per_second * seconds)
	while left > 0 and not ok.call():
		await physics_frame
		left -= 1


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
