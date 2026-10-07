extends SceneTree
## Marrow's pull (hush_pull.gd): at full Hold it takes Eco from the street and
## walks her to his basement with no player control, then gives her an errand;
## the errand's spot only shows while it's hers, and he pays for it in Hush.
##   godot --headless --path . -s res://tests/hush_pull_test.gd

const Vices := preload("res://scripts/hub/vices.gd")
const HushDen := preload("res://scripts/hub/hush_den.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

var run_node: Node
var player: CharacterBody3D
var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_pull_armory.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_node.armory_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_pull_armory_vices.cfg"))
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(60)
	player = run_node.player
	var pull: Node = run_node.hush_pull
	Vices.hold = Vices.MAX_HOLD
	_check("full hold: the pull can take her", Vices.can_pull(), Vices.hold)

	# On the street at the top of Lantern Row: she walks all the way.
	_place(Vector3(0, 0.3, 141))
	await _ticks(30)
	pull.start()
	await _ticks(2)
	_check("it takes her", pull.busy() and player.entranced and Vices.entranced, pull.step)
	_check("eyes spin up", Vices.eye_swirl() > 1.0, Vices.eye_swirl())
	_check("no prompts while it has her", run_node.hud.prompt_label.text == "" or not run_node.hud.prompt_label.visible, run_node.hud.prompt_label.text)
	Input.action_press("move_back")
	await _ticks(Engine.physics_ticks_per_second * 5)
	Input.action_release("move_back")
	_check("the player can't turn her round", player.global_position.z > 141.5, player.global_position)
	var faded := false
	var lowest_z := 999.0
	for i in Engine.physics_ticks_per_second * 150:
		await physics_frame
		if pull.step == pull.Step.FADE and player.global_position.y > 0.0 and player.global_position.distance_to(HushDen.CELLAR) > 2.0:
			faded = true  # a fade before the cellar door: something blocked her
		lowest_z = minf(lowest_z, player.global_position.z)
		if not pull.busy():
			break
	_check("she walked to the cellar door on her own", not faded, player.global_position)
	_check("she ends up in his basement", player.global_position.distance_to(HushDen.ARRIVE) < 1.5, player.global_position)
	_check("the trance lets go", not pull.busy() and not player.entranced and not Vices.entranced, pull.step)
	_check("he gives her an errand", Vices.errand in HushDen.ERRANDS and Vices.pulled, Vices.errand)
	_check("his words on screen", run_node.hud.toast_label.text.contains(HushDen.ERRANDS[Vices.errand]["task"]), run_node.hud.toast_label.text)
	_check("HUD shows the errand", run_node._vices_text().contains("MARROW"), run_node._vices_text())

	# Only her errand's spot is there; F there does it.
	var id := Vices.errand
	for other: String in HushDen.ERRANDS:
		_place(HushDen.ERRANDS[other]["pos"] + Vector3(0, 0.3, 0))
		await _ticks(20)
		var spot: Dictionary = run_node.nearest_hub_spot()
		if other == id:
			_check("%s: her errand's spot" % other, spot.get("errand", "") == other and run_node.hud.prompt_label.text == spot["prompt"], run_node.hud.prompt_label.text)
		else:
			_check("%s: not hers, not there" % other, spot.get("errand", "") == "", spot.get("id"))
	_place(HushDen.ERRANDS[id]["pos"] + Vector3(0, 0.3, 0))
	await _ticks(20)
	await _press("interact")
	await _ticks(2)
	_check("errand done", Vices.errand_done and run_node.hud.toast_label.text == HushDen.ERRANDS[id]["done"], run_node.hud.toast_label.text)
	_check("HUD: back to him", run_node._vices_text().contains("go back to him"), run_node._vices_text())
	run_node.open_bench("hush")
	await _ticks(2)
	_check("Marrow pays", run_node.bench.take() and Vices.dosed and Vices.errand == "", Vices.dosed)
	run_node.close_bench()
	await _ticks(2)

	# Out of town (the temple): a few steps, the violet, then the walk down the street.
	Vices.dosed = false
	Vices.pulled = false
	_place(run_node.zone_info["spawn"] + Vector3(0, 0.3, 0))
	await _ticks(30)
	pull.start()
	var walked_town := false
	for i in Engine.physics_ticks_per_second * 150:
		await physics_frame
		if pull.step == pull.Step.WALK and player.global_position.z > 150.0:
			walked_town = true
		if not pull.busy():
			break
	_check("from the temple: she walks in through town", walked_town, player.global_position)
	_check("and ends up at his table again", player.global_position.distance_to(HushDen.ARRIVE) < 1.5, player.global_position)

	# Every errand's spot is reachable, shows while it's hers, and F does it.
	for each: String in HushDen.ERRANDS:
		Vices.give_errand(each)
		_place(HushDen.ERRANDS[each]["pos"] + Vector3(0, 0.3, 0))
		await _ticks(30)
		var at: Dictionary = run_node.nearest_hub_spot()
		_check("%s: prompt" % each, at.get("errand", "") == each and run_node.hud.prompt_label.text == HushDen.ERRANDS[each]["prompt"], [at.get("id"), player.global_position])
		await _press("interact")
		await _ticks(2)
		_check("%s: done" % each, Vices.errand_done, run_node.hud.toast_label.text)
	Vices.errand = ""
	Vices.errand_done = false

	# Withdrawal on a run: an episode takes her off the job, she comes to at his place begging.
	Vices.hold = Vices.MAX_HOLD
	Vices.dosed = false
	run_node.start_run(11)
	await _ticks(60)
	_check("a run in withdrawal", Vices.in_withdrawal() and Vices.can_episode(), Vices.state_name())
	pull.episode()
	await _ticks(2)
	_check("the swirls take her mid-run", pull.busy() and player.entranced and Vices.eye_swirl() > 1.0, pull.step)
	var hp: float = player.health
	player.take_damage(20.0)
	_check("nothing hurts her while it has her", player.health == hp, player.health)
	await _ticks(int(Engine.physics_ticks_per_second * (pull.EPISODE_TIME + 0.5)))
	_check("she walks off the job: run abandoned", run_node.phase == run_node.Phase.OVER and run_node.result == "RUN ABANDONED", run_node.result)
	_check("the trance lets go", not pull.busy() and not player.entranced and not Vices.entranced, pull.step)
	_check("begging doesn't loosen his hold", Vices.hold == Vices.MAX_HOLD and Vices.begging and Vices.trance, [Vices.hold, Vices.begging])
	run_node.enter_hub()
	await _ticks(10)
	_check("she comes to at his table, begging", player.global_position.distance_to(HushDen.ARRIVE) < 1.5 and not Vices.begging, player.global_position)
	_check("another chance: a new errand", Vices.errand in HushDen.ERRANDS and run_node.hud.toast_label.text.contains(HushDen.ERRANDS[Vices.errand]["task"]), run_node.hud.toast_label.text)
	Vices.errand = ""
	Vices.pulled = false

	# The clock: a roll every ROLL_EVERY seconds roaming free, rising to certain.
	_check("20% a minute in the hub", is_equal_approx(Vices.timer_chance(60.0, Vices.PULL_DEADLINE), 0.2) \
			and is_equal_approx(Vices.timer_chance(Vices.PULL_DEADLINE, Vices.PULL_DEADLINE), 1.0), Vices.PULL_DEADLINE)
	_check("10% a minute on a withdrawal run", is_equal_approx(Vices.timer_chance(60.0, Vices.EPISODE_DEADLINE), 0.1), Vices.EPISODE_DEADLINE)
	Vices.errand = ""
	Vices.pulled = false
	pull.roam = 0.0
	pull.tick(Vices.ROLL_EVERY * 0.5, false)
	_check("not while she's busy", pull.roam == 0.0 and not pull.busy(), pull.roam)
	pull.tick(Vices.ROLL_EVERY * 0.5, true)
	_check("the clock shows on screen", pull.clock_text().begins_with("MARROW'S PULL  4:30") and pull.clock_text().ends_with("20%"), pull.clock_text())
	pull.roam = Vices.PULL_DEADLINE - 1.0
	pull.tick(2.0, true)
	_check("certain when the clock runs out", pull.busy(), pull.step)
	_check("the clock hides while it has her", pull.clock_text() == "", pull.clock_text())
	pull.reset()
	Vices.pulled = false
	Vices.hold = 50.0
	pull.tick(Vices.PULL_DEADLINE * 2.0, true)
	_check("not below full hold", not pull.busy() and pull.clock_text() == "", pull.step)

	print("hush_pull_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _place(pos: Vector3) -> void:
	for a in ["move_forward", "move_back", "interact"]:
		Input.action_release(a)
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.state = player.State.AIR


func _press(action: String) -> void:
	await physics_frame
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
