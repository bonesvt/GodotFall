extends SceneTree
## Stopping Mom or Ophelia on her way back to whoever had her (rescue_event.gd
## stop_walker()). Before three visits she comes round and goes home. Once
## she's theirs, a quick-time event: hold on ([F] fast enough) and she comes
## home, their hold on her eased; lose her and she gives Eco what they gave
## her (Marrow's Hold, the colony's next piece, a Redline charge), then walks
## on, and can't be stopped again that walk. Every camera move eases.
##   godot --headless --path . -s res://tests/rescue_stop_test.gd

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const Redline := preload("res://scripts/hub/redline.gd")
const Rescue := preload("res://scripts/hub/rescue.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const ViceLooks := preload("res://scripts/hub/vice_looks.gd")
const ColonyGear := preload("res://scripts/hub/colony_gear.gd")
const EcoModel := preload("res://scripts/ps2/eco_model.gd")
const Family := preload("res://scripts/hub/family.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

var run_node: Node
var player: CharacterBody3D
var ev: Node
var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_rstop_armory.cfg"
	run_node.npc_path = "user://test_rstop_npc.cfg"
	for f in ["user://test_rstop_armory.cfg", "user://test_rstop_npc.cfg", "user://test_rstop_armory_vices.cfg", "user://test_rstop_armory_rescue.cfg",
			"user://test_rstop_armory_hub_grip.cfg", "user://test_rstop_armory_looks.cfg", "user://test_rstop_armory_redline.cfg", "user://test_rstop_armory_hymn.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(60)
	player = run_node.player
	ev = run_node.rescue_event
	run_node.hush_pull.triggers._next = INF
	ev._roll = INF
	Vices.reset()
	Hymn.reset()
	Redline.reset()
	Rescue.reset()
	HubGrip.reset()
	ViceLooks.reset()
	run_node.place_player(Vector3(0.5, 0.1, 160.0))
	await _ticks(4)
	var mom: Node3D = run_node.hub_npcs["mom"]

	# had once, not theirs yet: she comes round and goes home
	Rescue.lost_to = {"mom": ["marrow"]}
	Rescue.hooks = {"mom": {"marrow": 40.0}}
	ev.walk_off_now("mom")
	await _ticks(3)
	_check("off to Marrow, from just ahead of Eco", ev.walking() and not mom.visible, ev._drawn_captor)
	_check("[F] Stop Mom, on her", _spot_at(ev._walker.global_position), _stop_spot())
	ev.stop_walker()
	await _ticks(2)
	_check("not theirs yet: she comes round, no scene", not ev.busy() and not ev.walking() and mom.visible, ev.step)
	_check("and says so", run_node.hud.toast_label.text.contains("Take me home"), run_node.hud.toast_label.text)
	_check("the stop spot's gone with her", _stop_spot().is_empty(), "")

	# theirs (three visits): hold on to her
	Rescue.make_theirs("mom", "cutter")
	_check("three visits in: Cutter's", Rescue.changed_by("mom") == "cutter" and Rescue.held_by("mom") == "cutter", Rescue.visits)
	var state: ConfigFile = run_node.npc_talk.state
	Family.add(state, "mom", 40 - Family.bond(state, "mom"))
	var hook_was := Rescue.hook("mom", "cutter")
	ev.walk_off_now("mom")
	await _ticks(3)
	var cuts_was: int = ev.cuts
	ev.stop_walker()
	_check("she pulls away: a scene, Eco held still for it", ev.busy() and ev.step == ev.Step.STOP and player.entranced, ev.step)
	await _until(func(): return ev.t >= ev.Q_START + 0.1, 4.0)
	_check("the bar's up", ev._q_ui.visible and ev.qte_result == "", ev.qte)
	var presses := 0
	while ev.qte_result == "" and presses < 200:
		ev.qte_press()
		presses += 1
		await _ticks(6)  # ten a second
	_check("held on to", ev.qte_result == "held", [ev.qte_result, presses])
	await _until(func(): return not ev.busy(), 8.0)
	await _ticks(2)
	_check("home with Eco", not ev.walking() and mom.visible and not player.entranced, ev.step)
	_check("Cutter's hold on her eased", is_equal_approx(Rescue.hook("mom", "cutter"), hook_was + Rescue.HOOK_SAVED), Rescue.hook("mom", "cutter"))
	_check("closer for it", Family.bond(state, "mom") == 40 + ev.BOND_HELD, Family.bond(state, "mom"))
	_check("no hard cuts", ev.cuts == cuts_was, ev.cuts - cuts_was)

	# lost, to each of them: she gives it to Eco, and walks on
	for c in ["marrow", "colony", "cutter"]:
		Rescue.make_theirs("mom", c)
		ev.walk_off_now("mom")
		await _ticks(3)
		_check("%s: off to them" % c, ev.walking() and ev._drawn_captor == c, ev._drawn_captor)
		var hold_was := Vices.hold
		var gear_was := Hymn.gear.duplicate()
		var charges_was := Redline.charges
		cuts_was = ev.cuts
		ev.stop_walker()
		await _until(func(): return ev.qte_result == "lost", 8.0)
		_check("%s: not held: lost her" % c, ev.qte_result == "lost" and ev.busy(), ev.qte)
		var start: Vector3 = ev._walker.global_position
		await _until(func(): return ev.t - ev._q_at >= ev.G_IN + 0.2, 6.0)
		_check("%s: she stepped in close to Eco" % c, ev._walker.global_position.distance_to(player.global_position) < start.distance_to(player.global_position) - 0.3,
				ev._walker.global_position.distance_to(player.global_position))
		_check("%s: theirs in Eco's eyes" % c, EcoModel.swirl_override > 0.0 and EcoModel.swirl_override_tint == ev.EYE_TINT[c], EcoModel.swirl_override)
		await _until(func(): return not ev.busy(), 8.0)
		await _ticks(2)
		match c:
			"marrow":
				_check("marrow: his Hold on Eco up", is_equal_approx(Vices.hold, hold_was + Vices.HOLD_PER_DOSE), Vices.hold)
			"colony":
				var piece: String = Hymn.GEAR[gear_was.size()]
				_check("colony: its next piece on Eco", Hymn.gear.size() == gear_was.size() + 1 and piece in Hymn.gear, Hymn.gear)
				var body: Node = player.get_node("EcoBody/Body")
				_check("colony: and on her body", ColonyGear.piece_node(body, piece) != null, piece)
			"cutter":
				_check("cutter: a Redline charge in her", Redline.charges == charges_was + 1, Redline.charges)
		_check("%s: she walks on" % c, ev.walking() and not player.entranced and ev.step == ev.Step.IDLE, ev.step)
		_check("%s: her eyes still easing back, not snapped" % c, EcoModel.swirl_override > 0.0 and ev._swirl_fade > 0.0, EcoModel.swirl_override)
		var turn_was: float = ev._walker.rotation.y
		await _ticks(1)
		_check("%s: she turns to the road, not snaps" % c, absf(angle_difference(turn_was, ev._walker.rotation.y)) < 0.3, angle_difference(turn_was, ev._walker.rotation.y))
		await _until(func(): return EcoModel.swirl_override < 0.0, 3.0)
		_check("%s: Eco's own eyes back" % c, EcoModel.swirl_override < 0.0, EcoModel.swirl_override)
		_check("%s: no hard cuts" % c, ev.cuts == cuts_was, ev.cuts - cuts_was)
		await _ticks(3)
		_check("%s: and she can't be stopped again this walk" % c, _stop_spot().is_empty(), _stop_spot())
		ev._end_walk()
		ev._walk_home()

	# Teen: none of it
	ContentRating.set_rating("T", false)
	run_node.drawn_now()
	await _ticks(2)
	_check("teen: nobody walks off", not ev.walking(), "")
	ContentRating.set_rating("M", false)
	Vices.reset()
	Vices.save()
	Hymn.reset()
	Hymn.save()
	Redline.reset()
	Redline.save()
	Rescue.reset()
	Rescue.save()
	HubGrip.reset()
	HubGrip.save()
	ViceLooks.reset()
	ViceLooks.save()
	print("rescue_stop_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _stop_spot() -> Dictionary:
	for s in run_node.zone_info.get("interactables", []):
		if s["id"] == ev.STOP_SPOT:
			return s
	return {}


func _spot_at(at: Vector3) -> bool:
	var s := _stop_spot()
	return not s.is_empty() and (s["pos"] as Vector3).distance_to(at) < 0.5


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _until(ok: Callable, seconds: float) -> void:
	var left := int(Engine.physics_ticks_per_second * seconds)
	while left > 0 and not ok.call():
		await physics_frame
		left -= 1


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
