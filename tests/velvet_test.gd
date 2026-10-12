extends SceneTree
## Pip's Velvet (velvet.gd): found through the Still's cupboard, offered by Pip,
## twelve daily check-ups (velvet_scene.gd stages [velvet 1]..[velvet 12] from
## dialogue/npc/pip_M.txt), the dose on the next run, what builds up, the
## withdrawal, and the drop's odds. Mature only.
##   godot --headless --path . -s res://tests/velvet_test.gd

const Velvet := preload("res://scripts/hub/velvet.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const NpcTalk := preload("res://scripts/hub/npc_talk.gd")
const VelvetScene := preload("res://scripts/hub/velvet_scene.gd")
const VelvetRun := preload("res://scripts/run/velvet_run.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const Below := preload("res://scripts/hub/downtown_below.gd")

const SAVE := "user://test_velvet.cfg"

var failures := 0


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	ContentRating.set_rating("M", false)
	Velvet.save_path = SAVE
	_run.call_deferred()


func _run() -> void:
	Velvet.reset()
	_check("nothing until she's found the Still", not Velvet.offer_due() and not Velvet.checkup_due(), Velvet.state)
	Velvet.find()
	_check("found: Pip asks", Velvet.offer_due(), "")
	ContentRating.set_rating("T", false)
	_check("Teen: never", not Velvet.offer_due() and Velvet.health_scale() == 1.0 and Velvet.state_name() == "", "")
	ContentRating.set_rating("M", false)

	# No, then a note on the bench after all.
	Velvet.answer("velvet_no")
	_check("no: no more offer, no check-up", not Velvet.offer_due() and not Velvet.checkup_due(), Velvet.state)
	Velvet.answer("velvet_yes")
	_check("yes: 'tomorrow, then'", Velvet.state == "yes" and not Velvet.checkup_due(), Velvet.last_day)
	Velvet.run_started()
	Velvet.run_over()
	_check("a run later: the first check-up", Velvet.checkup_due() and Velvet.next_checkup() == 1, Velvet.day)

	# Day one: dosed, and it rides along on the next run.
	_check("check-up 1", Velvet.checkup() == 1 and Velvet.dosed and Velvet.level > 0.0, Velvet.level)
	_check("once a day", not Velvet.checkup_due() and Velvet.checkup() == 0, "")
	_check("what's built up costs max health", Velvet.health_scale() < 1.0, Velvet.health_scale())
	Velvet.run_started()
	_check("on the run: harder, faster, tougher, quicker to heal",
		Velvet.on() and Velvet.damage_out() > 1.2 and Velvet.speed_scale() > 1.0 and Velvet.damage_scale() < 1.0 and Velvet.regen_scale() > 1.0, Velvet.damage_out())
	_check("and it can drop her", Velvet.drop_chance() > 0.0 and Velvet.drop_hurt() > 0.0, Velvet.drop_chance())
	var plain := Velvet.drop_chance()
	Vices.hushed = true
	_check("mixed with Hush: far likelier, and deadly", Velvet.mixed() and Velvet.drop_chance() > plain, Velvet.drop_chance())
	Vices.hushed = false
	Velvet.run_over()
	_check("run over: off it", not Velvet.on() and Velvet.damage_out() == 1.0, "")

	# The rest of the days, one a run; day 11 is no dose.
	for n in range(2, 12):
		Velvet.checkup()
		Velvet.run_started()
		Velvet.run_over()
	_check("eleven check-ups, still on the trial", Velvet.checkups == 11 and Velvet.state == "yes", Velvet.checkups)
	_check("deep in it by now", Velvet.level >= 60.0, Velvet.level)
	Velvet.run_started()
	_check("a run without a dose: withdrawal", Velvet.shakes() and Velvet.crave() > 0.0 and Velvet.damage_scale() > 1.0 and Velvet.speed_scale() < 1.0, Velvet.crave())
	Velvet.run_over()
	_check("day twelve due", Velvet.checkup_due() and Velvet.next_checkup() == 12, "")
	Velvet.checkup()
	_check("twelve: done, no more", Velvet.state == "done" and not Velvet.checkup_due(), Velvet.state)

	# Stopping on day 11 instead.
	var keep := Velvet.level
	Velvet.state = "yes"
	Velvet.answer("velvet_stop")
	_check("day 11, stop: out", Velvet.state == "out" and not Velvet.on_trial(), Velvet.state)
	Velvet.run_started()  # day twelve's dose rides along on this one
	Velvet.run_over()
	var before := Velvet.level
	Velvet.run_started()
	Velvet.run_over()
	_check("clean runs wear it off", Velvet.level < before, Velvet.level)
	Velvet.level = keep

	# Saved and loaded.
	Velvet.save()
	var lvl := Velvet.level
	Velvet.reset()
	Velvet.open(SAVE)
	_check("saved", Velvet.found and Velvet.state == "out" and Velvet.checkups == 12 and is_equal_approx(Velvet.level, lvl), Velvet.state)

	# Pip's lines: the offer and all twelve, Mature only, with only cues the scene knows.
	var talk := NpcTalk.new()
	var m: Dictionary = talk.bank("pip")
	var offer: Array = m.get("velvet offer", [])
	var flags := []
	for l in offer:
		if l is Dictionary:
			for c in l["choice"]:
				flags.append(c["flag"])
	_check("the offer asks yes or no", flags == ["velvet_yes", "velvet_no"], flags)
	var cues_ok := true
	var bad := []
	for n in range(1, 13):
		var scene: Array = m.get("velvet %d" % n, [])
		if scene.size() < 6:
			cues_ok = false
			bad.append(n)
		for l in scene:
			var said: Array = [l] if l is Array else []
			if l is Dictionary:
				for c in l["choice"]:
					said.append_array(c["lines"])
			for s in said:
				if s.size() > 2:
					for w in s[2]:
						if String(w).begins_with("@") and not String(w).substr(1) in VelvetScene.CUES:
							cues_ok = false
							bad.append("%d %s" % [n, w])
	_check("twelve check-ups, every cue known", cues_ok, bad)
	var day11: Array = m.get("velvet 11", [])
	var stop_flags := []
	for l in day11:
		if l is Dictionary:
			for c in l["choice"]:
				stop_flags.append(c["flag"])
	_check("day 11: stop or go on", stop_flags == ["velvet_stop", "velvet_go"], stop_flags)
	for n in range(1, 13):
		if not m["velvet %d" % n][0][2].any(func(w): return String(w).begins_with("@")):
			_check("day %d opens with its staging" % n, false, m["velvet %d" % n][0])
	ContentRating.set_rating("T", false)
	_check("Teen: none of it", not talk.bank("pip").has("velvet offer") and not talk.bank("pip").has("velvet 1"), "")
	ContentRating.set_rating("M", false)
	talk.free()
	Velvet.state = "yes"
	_check("after lines", VelvetScene.after_line(3).begins_with("Day 3") and VelvetScene.after_line(11).contains("No glass"), "")
	var drop := VelvetRun.new(null)
	_check("the drop's node builds", drop != null, "")
	drop.free()

	await _hub()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("velvet_test: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


## In the real hub: the offer, and all twelve check-ups staged in the Still.
func _hub() -> void:
	var run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_velvet_armory.cfg"
	run_node.npc_path = "user://test_velvet_npcs.cfg"
	for p in [run_node.armory_path, run_node.npc_path, "user://test_velvet_armory_vices_velvet.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	root.add_child(run_node)
	for i in 60:
		await physics_frame
	var talk = run_node.npc_talk
	var scene = run_node.velvet_scene
	var pip: Node3D = run_node.hub_npcs.get("pip")
	_check("hub: Pip and the check-up spot", pip != null and scene != null and run_node.zone_info["interactables"].any(func(s): return s.get("id") == VelvetScene.SPOT_ID), "")
	if pip == null or scene == null:
		run_node.queue_free()
		return
	# The offer, once she's been through the cupboard.
	Velvet.reset()
	talk.state.set_value("pip", "met", true)
	_check("hub: no offer before the Still", talk.pick("pip", 0, true) != talk.bank("pip")["velvet offer"], "")
	Velvet.find()
	_check("hub: Pip asks", talk.pick("pip", 0, true) == talk.bank("pip")["velvet offer"], "")
	talk.start(pip, 0, true)
	var guard := 0
	while talk.active() and talk.options.is_empty() and guard < 60:
		guard += 1
		talk.advance()
	talk.choose(0)
	talk.stop()
	_check("hub: she said yes", Velvet.state == "yes" and not Velvet.checkup_due(), Velvet.state)
	Velvet.day += 1
	var player = run_node.player
	player.global_position = Below.STILL + Vector3(0.9, 0.3, 1.15)
	player.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	_check("hub: the copper offers day one", run_node.hud.prompt_label.text == "[F] Pip's check-up (day 1 of 12)", run_node.hud.prompt_label.text)
	var home: Vector3 = pip.global_position
	for n in range(1, 13):
		if n > 1:
			Velvet.day += 1
			player.global_position = Below.STILL + Vector3(0.9, 0.3, 1.15)
			for i in 3:
				await physics_frame
		await _press("interact")
		await physics_frame
		var staged: bool = scene.playing == n and talk.active() and talk.hold and scene._camera != null and scene._camera.current and not player.visible \
				and scene.eco != null and pip.global_position.distance_to(Below.STILL) < 4.0
		if not staged:
			_check("hub: day %d staged" % n, false, [scene.playing, talk.active(), pip.global_position])
		guard = 0
		while talk.active() and guard < 80:
			guard += 1
			if not talk.options.is_empty():
				talk.choose(1)  # day 11: go on
			else:
				await _press("interact")
		await physics_frame
		if scene.playing != 0 or scene.eco != null or not player.visible or pip.global_position.distance_to(home) > 0.01:
			_check("hub: day %d all back after" % n, false, [scene.playing, pip.global_position])
	_check("hub: twelve days, done", Velvet.state == "done" and Velvet.checkups == 12, [Velvet.state, Velvet.checkups])
	_check("hub: the pilot's camera is back", player.get_node("Head/Camera3D").current, "")
	_check("hub: Pip back at work", pip.posed == (pip.get_meta("work", [""])[0] != ""), pip.get_meta("work", []))
	run_node.queue_free()
	await physics_frame


func _press(action: String) -> void:
	await physics_frame
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
