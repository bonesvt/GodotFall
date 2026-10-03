extends SceneTree
## Headless test for romance (scripts/hub/romance.gd + npc_talk.gd): Ophelia
## can be romanced and Mom can't, a talk a hub stay warms her up, her heart
## scenes unlock in order and stop for Eco's answer (1-3), answers move
## affection, walking off a scene saves it for later, the last scene can make
## them a couple, friends or wait, dates and gifts hook in, every romance line
## parses, and the 1-3 keys answer in the real hub.
## Run: godot --headless --path . -s res://tests/romance_test.gd

const NpcTalk := preload("res://scripts/hub/npc_talk.gd")
const Romance := preload("res://scripts/hub/romance.gd")
const PATH := "user://test_romance.cfg"

var failures := 0


class FakeNpc extends Node3D:
	var who := ""
	var talking := false

	func hush() -> void:
		talking = false

	func say(_s) -> void:
		talking = true


func _initialize() -> void:
	_run.call_deferred()


func _fresh() -> NpcTalk:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var t: NpcTalk = NpcTalk.new()
	t.save_path = PATH
	root.add_child(t)
	return t


func _npc(who: String) -> FakeNpc:
	var n := FakeNpc.new()
	n.who = who
	root.add_child(n)
	return n


## Plays the talk to its end, answering every question with `pick` (0-based).
func _play_out(t: NpcTalk, pick := 0) -> Array:
	var said := []
	var guard := 0
	while t.active() and guard < 200:
		guard += 1
		if not t.options.is_empty():
			said.append(t.current_line())
			t.choose(mini(pick, t.options.size() - 1))
		else:
			said.append(t.current_line())
			_adv(t)
	return said


func _run() -> void:
	# The file parses: settings, scenes in order, choices with their answers.
	var t := _fresh()
	var oph := _npc("ophelia")
	var mom := _npc("mom")
	var b: Dictionary = t.bank("ophelia")
	_check("Ophelia is romanceable", t.romanceable("ophelia"), b.keys())
	_check("Mom is not", not t.romanceable("mom"), t.bank("mom").keys())
	var ats: Array = b["heart"].map(func(h): return h["at"])
	_check("five heart scenes in order", ats == [10, 25, 45, 65, 85], ats)
	var s := Romance.settings(b)
	_check("likes and dislikes read", s["likes"].has("tape") and s["dislikes"].has("flowers") and s["date_from"] == 45, s)
	var q: Dictionary = b["heart"][0]["lines"][3]
	_check("a choice has three answers with their replies", q.has("choice") and q["choice"].size() == 3 and q["choice"][0]["delta"] == 6 and q["choice"][0]["lines"].size() == 2 and q["choice"][0]["lines"][1][0] == "ophelia", q)
	var last: Array = b["heart"][4]["lines"].back()["choice"]
	var tape: Array = b["heart"][0]["lines"]
	_check("moods parse off the speaker", tape[2][0] == "ophelia" and tape[2][2] == ["down", "blush"] and q["choice"][2]["lines"][1][2] == ["sad", "lookaway"], [tape[2], q["choice"][2]["lines"][1]])
	_check("the last scene's answers carry flags", last.map(func(o): return o["flag"]) == ["together", "later", "friends"], last.map(func(o): return o["flag"]))

	# First talk is her intro: no affection for that.
	t.start(oph, 0, false)
	_check("intro first", t.current_line() == "ophelia: Oh. It's you.", t.current_line())
	_play_out(t)
	_check("no affection from the intro", t.affection("ophelia") == 0, t.affection("ophelia"))
	# Talking again in the same stay: an everyday talk, still nothing.
	t.start(oph, 0, false)
	_play_out(t)
	_check("one warm-up a stay", t.affection("ophelia") == 0, t.affection("ophelia"))
	# Next stay: +3, and Mom never gets any.
	t.start(oph, 1, true)
	_play_out(t)
	_check("talking after a run warms her up", t.affection("ophelia") == Romance.TALK_GAIN, t.affection("ophelia"))
	t.start(mom, 1, true)
	_play_out(t)
	t.start(mom, 2, true)
	_play_out(t)
	_check("Mom has no affection", t.affection("mom") == 0, t.affection("mom"))

	# At 10 the tape scene is waiting, and the prompt knows.
	Romance.add(t.state, "ophelia", 10 - t.affection("ophelia") - Romance.TALK_GAIN)
	_check("scene waiting with the next stay's warm-up", t.beat_waiting("ophelia", 2), t.affection("ophelia"))
	_check("not in this stay", not t.beat_waiting("ophelia", 1), t.affection("ophelia"))
	t.start(oph, 2, true)   # won/lost reaction comes first
	_play_out(t)
	t.start(oph, 2, true)
	_check("heart scene plays", t.beat == 10 and t.current_line() == "ophelia: Hey. Mechanic.", t.current_line())
	for i in 3:
		_adv(t)
	_check("it stops on a choice", t.options.size() == 3 and t.current_line().begins_with("choice: Scoot over"), t.current_line())
	var held := t.index
	t.tick(30.0, oph.global_position)
	_check("a choice waits for Eco", t.active() and t.index == held and t.options.size() == 3, t.index)
	_adv(t)
	_check("F doesn't skip a choice", t.options.size() == 3, t.current_line())
	var before := t.affection("ophelia")
	t.choose(0)
	_check("the answer plays, then her reply", t.current_line() == "eco: Scoot over. I'm in charge of the volume.", t.current_line())
	_adv(t)
	_check("her reply to that answer", t.current_line().begins_with("ophelia: Fine. Don't touch"), t.current_line())
	_adv(t)
	_check("then the scene goes on", t.current_line().begins_with("ophelia: Track three"), t.current_line())
	_check("she liked it (+6)", t.affection("ophelia") == before + 6, t.affection("ophelia"))
	_play_out(t)
	_check("scene plays once", not t.beat_waiting("ophelia", 2), t.state.get_value("ophelia", "beats"))

	# A bratty answer costs.
	Romance.add(t.state, "ophelia", 25 - t.affection("ophelia"))
	t.start(oph, 2, true)
	_check("cage scene at 25", t.beat == 25, t.beat)
	before = t.affection("ophelia")
	var said := _play_out(t, 2)
	_check("mean answer costs (-5)", t.affection("ophelia") == before - 5 and said.has("ophelia: Wow. Silver linings. Thanks, Eco."), [t.affection("ophelia"), said])

	# Walking off a scene before answering keeps it for later.
	Romance.add(t.state, "ophelia", 45 - t.affection("ophelia"))
	t.start(oph, 2, true)
	_check("nail scene at 45", t.beat == 45, t.beat)
	t.tick(0.1, oph.global_position + Vector3(20, 0, 0))
	_check("walking off ends it", not t.active(), t.active())
	_check("and it waits for next time", t.beat_waiting("ophelia", 2), t.state.get_value("ophelia", "beats"))

	# Dates need 45; gifts go by taste, once a run.
	var t2 := _fresh()
	_check("no date at 0", not t2.date(oph, "diner", 0), t2.affection("ophelia"))
	Romance.add(t2.state, "ophelia", 45)
	_check("date at 45", t2.date(oph, "diner", 0) and t2.current_line().begins_with("ophelia: So this is a date") and t2.affection("ophelia") == 45 + Romance.DATE_GAIN, [t2.current_line(), t2.affection("ophelia")])
	t2.stop()
	_check("a gift she likes", t2.give_gift(oph, "tape", 0) == Romance.GIFT_LIKE and t2.current_line().begins_with("ophelia: You remembered"), t2.current_line())
	_check("one gift a run", t2.give_gift(oph, "tape", 0) == 0, t2.affection("ophelia"))
	_check("a gift she hates", t2.give_gift(oph, "flowers", 1) == Romance.GIFT_DISLIKE and t2.current_line().begins_with("ophelia: Wow. I'll put it"), t2.current_line())
	t2.stop()
	t2.queue_free()

	# The confession: later, then together.
	Romance.add(t.state, "ophelia", 100)
	for at in [45, 65]:
		Romance.mark_beat(t.state, "ophelia", at)
	t.start(oph, 3, true)
	_play_out(t)   # the won reaction
	t.start(oph, 3, true)
	_check("confession at 85", t.beat == 85, t.beat)
	said = _play_out(t, 1)
	_check("'ask me again' keeps it open", Romance.status(t.state, "ophelia") == "" and t.beat_waiting("ophelia", 3), Romance.status(t.state, "ophelia"))
	t.start(oph, 3, true)
	_check("she asks again", t.beat == 85, t.beat)
	_play_out(t, 0)
	_check("kiss: together", Romance.status(t.state, "ophelia") == "together" and Romance.stage(t.state, "ophelia") == "together", Romance.status(t.state, "ophelia"))
	t.start(oph, 3, true)
	var first_together: Array = t.bank("ophelia")["together"][0]
	_check("couple talks replace everyday ones", t.current_line() == "%s: %s" % [first_together[0][0], first_together[0][1]], t.current_line())
	t.stop()
	_check("hearts full", Romance.hearts(t.state, "ophelia") == 5.0, Romance.hearts(t.state, "ophelia"))
	var saved := ConfigFile.new()
	saved.load(PATH)
	_check("all of it is saved", saved.get_value("ophelia", "status", "") == "together" and saved.get_value("ophelia", "affection", 0) == 100, saved.get_section_keys("ophelia"))

	# Friends ends the romance for good.
	var t3 := _fresh()
	Romance.add(t3.state, "ophelia", 90)
	t3.state.set_value("ophelia", "met", true)
	for at in [10, 25, 45, 65]:
		Romance.mark_beat(t3.state, "ophelia", at)
	t3.start(oph, 0, false)
	_play_out(t3, 2)
	_check("friends: no more scenes, no dates", Romance.status(t3.state, "ophelia") == "friends" and not t3.beat_waiting("ophelia", 5) and not Romance.can_date(t3.state, t3.bank("ophelia"), "ophelia"), Romance.status(t3.state, "ophelia"))
	t3.queue_free()

	# Every romance line parses into speaker + text (voices come from the
	# talk system itself, so nothing else to check here).
	var bad := []
	var count := 0
	var convs: Array = b["together"].duplicate()
	for h in b["heart"]:
		convs.append(h["lines"])
	for g in [b["date"], b["gift"]]:
		convs.append_array(g.values())
	for conv in convs:
		for line in _flat(conv):
			count += 1
			if not (line[0] in ["eco", "ophelia"]) or line[1] == "":
				bad.append(line)
	_check("every romance line has a speaker (%d lines)" % count, bad.is_empty() and count > 60, bad.slice(0, 3))

	await _hub_keys()

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


## In the real hub: the prompt hints at a waiting scene and 1-3 answer.
func _hub_keys() -> void:
	var run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_romance_armory.cfg"
	run_node.npc_path = "user://test_romance_npcs.cfg"
	for p in [run_node.armory_path, run_node.npc_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	root.add_child(run_node)
	for i in 60:
		await physics_frame
	var talk = run_node.npc_talk
	var oph = run_node.hub_npcs["ophelia"]
	talk.state.set_value("ophelia", "met", true)
	talk.state.set_value("ophelia", "warm_run", 0)
	Romance.add(talk.state, "ophelia", 10)
	var player = run_node.player
	player.global_position = oph.global_position + (-oph.global_basis.z) * 1.6 + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	_check("prompt says she wants to talk", run_node.hud.prompt_label.text.ends_with("(wants to talk)"), run_node.hud.prompt_label.text)
	await _press("interact")
	for i in 3:
		await _press("interact")   # finish the line
		await _press("interact")   # next
	await physics_frame
	_check("hub: a choice is up", talk.options.size() == 3, talk.current_line())
	_check("hub: the hearts show", talk._hearts.visible and talk._hearts.fill == 0.5, talk._hearts.fill)
	await _press("interact")
	_check("hub: F doesn't answer", talk.options.size() == 3, talk.current_line())
	await _press("choice_1")
	await physics_frame
	_check("hub: 1 answers", talk.options.is_empty() and talk.current_line().begins_with("eco: Scoot over") and talk.affection("ophelia") == 16, [talk.current_line(), talk.affection("ophelia")])
	_check("hub: she reacts", talk._reaction.visible and talk._reaction.text == "Ophelia really liked that.", talk._reaction.text)
	# She blushes and smiles, and it shows on her face.
	_check("hub: she has a blush pass and head gestures", oph._blush_mats.size() == 1 and oph._head != null and oph._faces.size() > 0, [oph._blush_mats.size(), oph._head])
	_check("hub: liked answer makes her blush and smile", oph.blush > 0.4 and oph.face == "smile", [oph.blush, oph.face])
	for i in 30:
		await process_frame
	var fun := 0.0
	for fm in oph._faces:
		fun = maxf(fun, fm[0].get_blend_shape_value(fm[1]["smile"][0][0]))
	_check("hub: the smile shows", fun > 0.3, fun)
	_check("hub: the blush shows", float(oph._blush_mats[0].get_shader_parameter("amount")) > 0.3, oph._blush_mats[0].get_shader_parameter("amount"))
	# Her reply line: smile and tilt, held until her mood changes.
	await _press("interact")
	await _press("interact")
	await physics_frame
	_check("hub: a line's moods play", talk.current_line().begins_with("ophelia: Fine") and oph.gesture == "tilt", [talk.current_line(), oph.gesture])
	var skel: Skeleton3D = oph.find_child("Skeleton3D", true, false)
	var head := skel.find_bone("J_Bip_C_Head")
	var still := skel.get_bone_global_pose(head).basis
	for i in 40:
		await process_frame
	var tilted := skel.get_bone_global_pose(head).basis
	_check("hub: her head tilts", still.get_rotation_quaternion().angle_to(tilted.get_rotation_quaternion()) > 0.08 or tilted.y.angle_to(Vector3.UP) > 0.1, tilted.y.angle_to(Vector3.UP))
	talk.stop()
	_check("hub: calm once the talk ends", oph.face == "" and oph.gesture == "", [oph.face, oph.gesture])
	run_node.queue_free()


## F twice: finish the line being said, then on to the next.
func _adv(t: NpcTalk) -> void:
	if t.active() and t.options.is_empty():
		t._text.visible_characters = -1
	t.advance()


func _flat(conv: Array) -> Array:
	var out := []
	for line in conv:
		if line is Dictionary:
			for o in line["choice"]:
				out.append_array(o["lines"])
		else:
			out.append(line)
	return out


func _press(action: String) -> void:
	await physics_frame
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
