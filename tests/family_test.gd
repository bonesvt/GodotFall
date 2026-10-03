extends SceneTree
## Headless test for Motherly Love (scripts/hub/family.gd, npc_talk.gd,
## family_scene.gd, eco_soft_lines.gd): Mom has a bond and nobody else does,
## a talk a hub stay grows it, her [bond N] scenes play in order and their
## answers move it, walking off saves a scene for later, cuddles open at 10
## once a stay, Eco comes home sick and Mom looks after her, close talks and
## other people's soft talks join in, every family line parses, Eco's
## whispers soften with the bond, and the scenes stage in the real hub.
## Run: godot --headless --path . -s res://tests/family_test.gd

const NpcTalk := preload("res://scripts/hub/npc_talk.gd")
const Family := preload("res://scripts/hub/family.gd")
const Soft := preload("res://scripts/radio/eco_soft_lines.gd")
const Whispers := preload("res://scripts/radio/eco_whispers.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const PATH := "user://test_family.cfg"
const SPEAKERS := {"mom": ["mom", "eco"], "ophelia": ["ophelia", "eco"], "biggie": ["biggie", "eco"]}
const MOODS := ["smile", "joy", "sad", "angry", "surprised", "closed", "plain", "blush", "fluster", "lookaway", "down", "tilt", "nod", "shake", "shy"]

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


func _play_out(t: NpcTalk, pick := 0) -> Array:
	var said := []
	var guard := 0
	while t.active() and guard < 200:
		guard += 1
		said.append(t.current_line())
		if not t.options.is_empty():
			t.choose(mini(pick, t.options.size() - 1))
		else:
			_adv(t)
	return said


func _run() -> void:
	var t := _fresh()
	var mom := _npc("mom")
	var oph := _npc("ophelia")
	var b: Dictionary = t.bank("mom")
	_check("Mom has a family bond", t.has_family("mom"), b.keys())
	_check("Ophelia and Biggie don't", not t.has_family("ophelia") and not t.has_family("biggie"), "")
	_check("Mom's everyday talks still load", b.has("intro") and b["any"].size() >= 6, b["any"].size())
	var ats: Array = b["bond"].map(func(s): return s["at"])
	_check("six bond scenes in order", ats == [10, 25, 40, 55, 70, 85], ats)
	_check("cuddle, sick and close talks", b["cuddle"].size() >= 5 and b["sick"].size() >= 3 and b["close"].size() >= 4, [b["cuddle"].size(), b["sick"].size(), b["close"].size()])
	_check("Ophelia and Biggie have soft talks", t.bank("ophelia")["soft"].size() >= 3 and t.bank("biggie")["soft"].size() >= 3, "")
	_check("Ophelia's romance is untouched", t.romanceable("ophelia") and t.bank("ophelia")["heart"].size() == 6, t.bank("ophelia")["heart"].size())
	_check_lines(t)

	# Intro first, no bond for it; one talk a stay grows it.
	t.start(mom, 0, false)
	_check("intro first", t.current_line().begins_with("mom: There you are"), t.current_line())
	_check("the meter shows, gold", t._hearts.visible and t._hearts.color == NpcTalk.HeartMeter.FAMILY and t._stage.text == "DISTANT", [t._hearts.visible, t._stage.text])
	_play_out(t)
	_check("no bond from the intro", t.bond("mom") == 0, t.bond("mom"))
	t.start(mom, 1, true)
	_play_out(t)
	_check("a talk after a run grows it", t.bond("mom") == Family.TALK_GAIN, t.bond("mom"))
	t.start(mom, 1, true)
	_play_out(t)
	_check("once a stay", t.bond("mom") == Family.TALK_GAIN, t.bond("mom"))
	t.start(oph, 1, true)
	_play_out(t)
	_check("Ophelia gets no bond", t.bond("ophelia") == 0 and t.affection("ophelia") == 0, [t.bond("ophelia"), t.affection("ophelia")])

	# Cuddles: locked below 10.
	_check("no cuddle yet", not t.cuddle(mom, 1), t.bond("mom"))
	# At 10 the first scene waits; walking off before answering saves it.
	Family.add(t.state, "mom", 10 - t.bond("mom") - Family.TALK_GAIN)
	_check("scene waiting with the next stay's talk", t.beat_waiting("mom", 2), t.bond("mom"))
	t.start(mom, 2, true)   # the won reaction first
	_play_out(t)
	t.start(mom, 2, true)
	_check("bond scene plays", t.bond_scene == 10 and t.current_line() == "mom: Eco. Sit with me a minute.", t.current_line())
	t.stop()
	_check("walked off: it waits", t.beat_waiting("mom", 2), t.state.get_value("mom", "bond_beats"))
	t.start(mom, 2, true)
	for i in 3:
		_adv(t)
	_check("it stops on a choice", t.options.size() == 3 and t.current_line().begins_with("choice: ...Fine. One minute"), t.current_line())
	var before := t.bond("mom")
	t.choose(0)
	_check("the answer moves the bond", t.bond("mom") == before + 6, t.bond("mom"))
	_check("Mom reacts warmly, no blush", t._reaction.text == "That meant the world to Mom.", t._reaction.text)
	var said := _play_out(t)
	_check("her reply, then the rest of the scene", said.has("mom: Come here then. Put your feet up. Mine are cold.") and said.back().begins_with("mom: My bed's warm"), said)
	_check("seen once", not t.beat_waiting("mom", 2), t.state.get_value("mom", "bond_beats"))
	# !later puts it back.
	var t2 := _fresh()
	t2.state.set_value("mom", "met", true)
	Family.add(t2.state, "mom", 10)
	t2.start(mom, 0, false)
	for i in 3:
		_adv(t2)
	t2.choose(2)
	_play_out(t2)
	_check("!later re-arms the scene", t2.beat_waiting("mom", 0) and t2.bond("mom") == 10 + Family.TALK_GAIN, [t2.state.get_value("mom", "bond_beats"), t2.bond("mom")])
	t2.queue_free()

	# Now cuddles open, once a stay.
	before = t.bond("mom")
	_check("cuddle opens at 10", t.cuddle(mom, 2) and t.active(), t.bond("mom"))
	_check("cuddle grows the bond", t.bond("mom") == before + Family.CUDDLE_GAIN, t.bond("mom"))
	_play_out(t)
	_check("one cuddle a stay", not t.cuddle(mom, 2), "")
	_check("next stay, another (the next talk)", t.cuddle(mom, 3) and t.current_line() == "eco: Your hair smells like the kitchen.", t.current_line())
	_play_out(t)

	# Sick days: the first lost run after meeting Mom, never two in a row.
	var s := t.state
	_check("not sick before meeting her", not Family.roll_sick(ConfigFile.new(), 4, false, false, 0.0), "")
	_check("a won run usually doesn't", not Family.roll_sick(s, 4, true, true, 0.9), "")
	_check("the first lost run does", Family.roll_sick(s, 5, false, true, 0.99), s.get_value("eco", "sick_run"))
	_check("rolled once a run", Family.roll_sick(s, 5, false, true, 0.99), "")
	_check("not two stays in a row", not Family.roll_sick(s, 6, false, true, 0.0), "")
	_check("care plays her sick talk", t.care(mom, 5) and t.current_line().begins_with("mom: Eco, you're burning up"), t.current_line())
	_play_out(t)
	_check("looked after: not sick any more", not Family.sick(s, 5) and not t.care(mom, 5), "")
	_check("later lost runs: by chance", Family.roll_sick(s, 8, false, true, 0.1) and not Family.roll_sick(s, 10, false, true, 0.9), "")

	# Close talks join at 50; others' soft talks once Eco has softened.
	_check("no soft talks with Ophelia yet", not _talks(t, oph, 9, 8).any(func(l): return _in(t, "ophelia", "soft", l)), t.bond("mom"))
	Family.add(t.state, "mom", 50)
	var mom_talks := _talks(t, mom, 11, 8)
	_check("close talks with Mom", mom_talks.any(func(l): return _in(t, "mom", "close", l)), mom_talks)
	_check("and everyday ones too", mom_talks.any(func(l): return _in(t, "mom", "any", l)), mom_talks)
	_check("stage climbs", Family.stage(t.state, "mom") != "distant", Family.stage(t.state, "mom"))
	var oph_talks := _talks(t, oph, 12, 8)
	_check("soft talks with Ophelia", oph_talks.any(func(l): return _in(t, "ophelia", "soft", l)), oph_talks)
	Family.add(t.state, "mom", 100)
	_check("top stage: mommy's girl", Family.stage(t.state, "mom") == "mommy's girl" and Family.softness(t.state) == 1.0, Family.stage(t.state, "mom"))

	# Whispers soften with the bond.
	_check("no soft lines at 0", Soft.fitting("kill", 0.0).is_empty(), "")
	_check("more soft lines the closer she is", Soft.fitting("kill", 0.3).size() < Soft.fitting("kill", 0.9).size(), [Soft.fitting("kill", 0.3).size(), Soft.fitting("kill", 0.9).size()])
	_check("soft lines are clean", _clean(), "")
	var w := Whispers.new()
	w.rng.seed = 3
	var hard := _whisper_texts(w, 0.0)
	_check("bratty at bond 0", not hard.any(func(x): return Soft.fitting("kill", 1.0).has(x)), hard)
	var gentle := _whisper_texts(w, 1.0)
	var n := gentle.filter(func(x): return Soft.fitting("kill", 1.0).has(x)).size()
	_check("gentler at full bond, still some brat", n > 40 and n < 90, n)
	w.free()

	await _hub()
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


## The first lines of `count` everyday talks with `npc` in hub stay `run`
## (every scene marked seen, so only the everyday lists are left).
func _talks(t: NpcTalk, npc: Node3D, run: int, count: int) -> Array:
	var who: String = npc.who
	for sc in t.bank(who)["bond"]:
		Family.mark_scene(t.state, who, sc["at"])
	t.state.set_value(who, "beats", t.bank(who)["heart"].map(func(h): return h["at"]))
	t.state.set_value(who, "run_seen", run)
	var out := []
	for i in count:
		t.start(npc, run, true)
		out.append(t.current_line())
		_play_out(t)
	return out


## Whether `line` ("speaker: text") opens one of their `list` talks.
func _in(t: NpcTalk, who: String, list: String, line: String) -> bool:
	for talk in t.bank(who)[list]:
		var first: Array = talk[0]
		if "%s: %s" % [first[0], first[1]] == line:
			return true
	return false


func _whisper_texts(w, softness: float) -> Array:
	w.softness = softness
	var out := []
	for i in 100:
		out.append(w._pick("kill").get("text", ""))
	return out


func _clean() -> bool:
	for cat in Soft.LINES:
		for e in Soft.LINES[cat]:
			var l := String(e[1]).to_lower()
			for word in ["fuck", "shit", "bitch", "damn"]:
				if l.contains(word):
					return false
	return true


## Every family line has a known speaker and known moods; every choice has an
## answer line from Eco.
func _check_lines(t: NpcTalk) -> void:
	var bad := []
	for who in SPEAKERS:
		var b: Dictionary = t.bank(who)
		var talks := []
		for list in ["close", "soft", "cuddle", "sick"]:
			talks.append_array(b[list])
		for sc in b["bond"]:
			talks.append(sc["lines"])
		for talk in talks:
			for line in talk:
				if line is Dictionary:
					for o in line["choice"]:
						if o["lines"].is_empty() or o["lines"][0][0] != "eco":
							bad.append(o)
						for l in o["lines"]:
							_check_line(who, l, bad)
				else:
					_check_line(who, line, bad)
	_check("every family line parses", bad.is_empty(), bad)


func _check_line(who: String, line: Array, bad: Array) -> void:
	if not SPEAKERS[who].has(line[0]) or String(line[1]).strip_edges() == "":
		bad.append(line)
	if line.size() > 2:
		for m in line[2]:
			if not MOODS.has(m):
				bad.append(line)


## In the real hub: the bed spot, a staged cuddle, and a sick day.
func _hub() -> void:
	var run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_family_armory.cfg"
	run_node.npc_path = "user://test_family_npcs.cfg"
	for p in [run_node.armory_path, run_node.npc_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	root.add_child(run_node)
	for i in 60:
		await physics_frame
	var talk = run_node.npc_talk
	var fam = run_node.family_scene
	var mom = run_node.hub_npcs["mom"]
	_check("hub: family scene is set up", fam != null and run_node.zone_info["interactables"].any(func(s): return s.get("id") == "family_bed"), "")
	talk.state.set_value("mom", "met", true)
	talk.state.set_value("mom", "bond_run", 0)
	var player = run_node.player
	player.global_position = fam.bed() + Vector3(1.1, 0.3, -0.6)
	player.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	_check("hub: bed spot quiet before the bond", run_node.hud.prompt_label.text == "", run_node.hud.prompt_label.text)
	Family.add(talk.state, "mom", 12)
	Family.mark_scene(talk.state, "mom", 10)
	for i in 5:
		await physics_frame
	_check("hub: bed spot offers a cuddle", run_node.hud.prompt_label.text == "[F] Curl up with Mom", run_node.hud.prompt_label.text)
	var home: Vector3 = mom.global_position
	await _press("interact")
	await physics_frame
	_check("hub: cuddle staged", fam.playing == "cuddle" and talk.active() and talk.hold, [fam.playing, talk.active()])
	_check("hub: camera on the bed, pilot parked", fam._camera != null and fam._camera.current and not player.visible, "")
	_check("hub: Mom on the bed, posed", mom.global_position.distance_to(home) > 1.0 and fam._mom_pose != null, mom.global_position)
	_check("hub: posed Eco with her", fam.eco != null and fam.eco.is_inside_tree(), "")
	# The posed bones only read back mid-update.
	var skel: Skeleton3D = mom.find_child("Skeleton3D", true, false)
	var legs := []
	skel.skeleton_updated.connect(func():
		legs.append_array([skel.get_bone_global_pose(skel.find_bone("J_Bip_R_UpperLeg")).origin, skel.get_bone_global_pose(skel.find_bone("J_Bip_R_LowerLeg")).origin]), CONNECT_ONE_SHOT)
	for i in 5:
		await process_frame
	_check("hub: Mom is sitting (thigh level)", legs.size() == 2 and absf(legs[0].y - legs[1].y) < 0.15, legs)
	var room_quilt: Node3D = run_node.zone_root.find_child("MomQuilt", true, false)
	_check("hub: the bed's quilt steps aside", room_quilt != null and not room_quilt.visible, room_quilt)
	var laid: Array = fam._props.filter(func(p): return p is MeshInstance3D and p.mesh is ArrayMesh)
	_check("hub: a quilt drapes over them", laid.size() == 1 and laid[0].get_aabb().size.y > 0.3, laid.map(func(p): return p.get_aabb()))
	var guard := 0
	while talk.active() and guard < 100:
		guard += 1
		await _press("interact")
	await physics_frame
	_check("hub: all back after the talk", fam.playing == "" and fam.eco == null and player.visible and mom.global_position.distance_to(home) < 0.01 and not talk.hold, [fam.playing, mom.global_position])
	_check("hub: the pilot's camera is back", player.get_node("Head/Camera3D").current, "")
	_check("hub: the bed's quilt is back", room_quilt.visible, "")
	_check("hub: the meter is gold", talk._hearts.color == NpcTalk.HeartMeter.FAMILY, "")
	# Sick: talking to Mom tucks Eco into her bed.
	talk.state.set_value("eco", "sick_run", run_node.runs_ended)
	player.global_position = mom.global_position + (-mom.global_basis.z) * 1.4 + Vector3(0, 0.3, 0)
	for i in 20:
		await physics_frame
	_check("hub: Mom's prompt says you're sick", run_node.hud.prompt_label.text.ends_with("(you're burning up)"), run_node.hud.prompt_label.text)
	await _press("interact")
	await physics_frame
	_check("hub: sick scene staged", fam.playing == "sick" and talk.current_line().begins_with("mom: Eco, you're burning up"), [fam.playing, talk.current_line()])
	_check("hub: Eco lies down", fam.eco != null and absf(fam.eco.rotation.x - PI / 2.0) < 0.01, "")
	run_node.queue_free()
	await process_frame


func _adv(t: NpcTalk) -> void:
	if t.active() and t.options.is_empty():
		t._text.visible_characters = -1
	t.advance()


func _press(action: String) -> void:
	await physics_frame
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
