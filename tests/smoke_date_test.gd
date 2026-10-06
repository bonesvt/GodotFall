extends SceneTree
## Headless test for the staged back step date (scripts/hub/smoke_date.gd):
## Ophelia lights the cigarette and passes it, it changes hands when their
## hands meet, Eco drops the stub, their lips meet in the kiss, and finish()
## gives Ophelia back and shows the player's Eco again.
## Run: godot --headless --path . --fixed-fps 10 -s res://tests/smoke_date_test.gd

const SmokeDate := preload("res://scripts/hub/smoke_date.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const NpcTalk := preload("res://scripts/hub/npc_talk.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

var failures := 0
var scene


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var set := Node3D.new()
	root.add_child(set)
	var oph: Node3D = HubNpc.create("ophelia", Vector3(3, 0, 0), 0.0)
	set.add_child(oph)
	var stand_in_for := Node3D.new()
	set.add_child(stand_in_for)
	scene = SmokeDate.new()
	set.add_child(scene)
	scene.setup(oph, Vector3(0, 0, 0), Vector3(0, 0, -2), stand_in_for, "y2k")
	await _frames(3)
	_check("the player's Eco hides for the scene", not stand_in_for.visible, "")
	_check("Ophelia stands facing her", oph.global_position.distance_to(Vector3(0, 0, -SmokeDate.GAP)) < 0.05, oph.global_position)
	scene.play("light")
	var flame_gap := 9.0
	for i in 60:
		await _frames(1)
		if scene._flame.visible:
			flame_gap = minf(flame_gap, scene._flame.global_position.distance_to(scene._ember.global_position))
	_check("the flame finds the tip", flame_gap < 0.03, flame_gap)
	_check("lit", scene._cig.visible and scene.get_value("ember") > 0.9 and scene._holder == "o", scene._holder)
	_check("held between her fingers", _in_fingers("o") < 0.03, _in_fingers("o"))
	scene.play("first")
	await _frames(20)
	_check("Eco takes it", scene._holder == "e", scene._holder)
	var off_fingers := 0.0
	var to_lips := 9.0
	for i in 20:
		await _frames(1)
		if scene._handoff >= 1.0:
			off_fingers = maxf(off_fingers, _in_fingers("e"))
		to_lips = minf(to_lips, scene._cig.global_position.distance_to(scene.lips_point(scene._actors["e"])))
	_check("it stays in her fingers", off_fingers < 0.03, off_fingers)
	_check("to her lips", to_lips < 0.03, to_lips)
	var out_of_face: float = (scene._cig.global_basis.y).dot(-scene._actors["e"]["model"].global_basis.z)
	_check("pointing away from her face", out_of_face > 0.3, out_of_face)
	scene.play("last_drag")
	await _frames(60)
	_check("the stub's dropped", scene._holder == "" or scene._holder == "drop", scene._holder)
	scene.play("kiss")
	await _frames(45)
	var gap: float = scene.lips_point(scene._actors["e"]).distance_to(scene.lips_point(scene._actors["o"]))
	_check("their lips meet", gap < 0.045, gap)
	scene.play("exhale")
	await _frames(22)
	gap = scene.lips_point(scene._actors["e"]).distance_to(scene.lips_point(scene._actors["o"]))
	_check("and part", gap > 0.15, gap)
	scene.finish()
	await _frames(2)
	_check("the player's Eco is back", stand_in_for.visible, "")
	_check("Ophelia's free again", not oph.posed, "")
	_check("no stand-in left", set.find_child("EcoStandIn", true, false) == null, "")
	set.queue_free()
	await _in_hub()
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


## In the real hub: the back step date stages the scene, the dialogue's
## "@" cues drive it, and it's put away when the talk ends.
func _in_hub() -> void:
	ContentRating.set_rating("M", false)
	var run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_smoke_armory.cfg"
	run_node.npc_path = "user://test_smoke_npcs.cfg"
	for p in [run_node.armory_path, run_node.npc_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	root.add_child(run_node)
	for i in 60:
		await physics_frame
	var talk = run_node.npc_talk
	talk.state.set_value("ophelia", "met", true)
	NpcTalk.Romance.add(talk.state, "ophelia", 100)
	run_node.armory.stash = {"scrap": 900, "alloy": 200, "circuits": 20, "lock_cores": 0}
	_check("hub: the back step date starts", run_node.date_at({"date": "smoke"}), run_node.date_partner())
	await _frames(5)
	var staged: Node = null
	for n in run_node.zone_root.get_children():
		if n.get_script() == SmokeDate:
			staged = n
	_check("hub: the scene is staged", staged != null, "")
	if staged == null:
		return
	var eco_body: Node3D = run_node.player.get_node_or_null("EcoBody")
	_check("hub: the player's Eco steps aside", eco_body == null or not eco_body.visible, "")
	var cues := {}
	staged.connect("done", func(): cues["done"] = true)
	for i in 400:
		if not talk.active():
			break
		cues[staged.beat_name] = true
		var act := "choice_1" if talk.current_line().begins_with("choice:") else "interact"
		Input.action_press(act)
		await physics_frame
		Input.action_release(act)
		await _frames(4)
	_check("hub: the dialogue cued the kiss", cues.has("last_drag") and cues.has("kiss") and cues.has("exhale"), cues.keys())
	await _frames(5)
	_check("hub: it's put away after", cues.has("done"), cues.keys())
	_check("hub: Eco's back", eco_body == null or eco_body.visible, "")
	ContentRating.set_rating("T", false)
	run_node.queue_free()
	await _frames(2)


## How far the cigarette sits from the holder's index and middle fingers.
func _in_fingers(who: String) -> float:
	# (where her fingers ended up this frame, after the IK: the bone poses read
	# from out here are from before it)
	var mid: Vector3 = scene._actors[who]["knuckles"]
	var cig: Transform3D = scene._cig.global_transform
	# from the knuckles to the nearest point along the cigarette
	var along := clampf((mid - cig.origin).dot(cig.basis.y), 0.0, 0.08)
	return mid.distance_to(cig.origin + cig.basis.y * along)


func _check(label: String, ok: bool, detail: Variant) -> void:
	if not ok:
		failures += 1
	print("%s  %s  (%s)" % ["ok   " if ok else "FAIL ", label, str(detail)])
