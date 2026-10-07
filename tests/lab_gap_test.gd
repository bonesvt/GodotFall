extends SceneTree
## The physics lab's squeeze gaps walked for real (the hub, the player's own
## physics and keys): down in the lab she's off duty (it's under the titan
## yard, but not part of it), walks into each gap and turns side-on, a gap with
## spots jutting into it stops her at the first one, and mashing jump gets
## her past them all and out the far end.
## Run: godot --headless --path . -s res://tests/lab_gap_test.gd

const Prefs := preload("res://scripts/game/prefs.gd")

var run_node
var player
var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	Prefs.path = "user://test_hub_prefs.cfg"
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 99
	run_node.armory_path = "user://test_gap_armory.cfg"
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	for i in 60:
		await physics_frame
	player = run_node.player
	for gap: Dictionary in run_node.zone_info["lab_gaps"]:
		var name := "%d cm gap" % roundi(gap["width"] * 100)
		var snags: int = gap["snags"].size()
		var walked := await _walk(gap, false)
		_check("%s: off duty in the lab" % name, walked["strolling"], walked)
		_check("%s: she turns side-on in it" % name, walked["sidled"], walked)
		if snags == 0:
			_check("%s: a walk, no snags to stop her" % name, walked["through"] and not walked["stuck"], walked)
			continue
		_check("%s: the first snag stops her" % name, walked["stuck"] and not walked["through"], walked)
		var mashed := await _walk(gap, true)
		_check("%s: mashing jump gets her past all %d snags" % [name, snags], mashed["through"], mashed)
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## Walks her into `gap` from just in front of it for 9 s, holding forward
## (and mashing jump while she's stuck if `mash`).
func _walk(gap: Dictionary, mash: bool) -> Dictionary:
	var c: Vector3 = gap["centre"]
	player.global_position = c + Vector3(0, 0.05, 1.3)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0
	player.squeeze = 0.0
	for i in 20:
		await physics_frame
	var out := {"strolling": player.strolling, "sidled": false, "stuck": false}
	Input.action_press("move_forward")
	for f in 540:
		if mash and f % 10 == 0 and player.stuck:
			Input.action_press("jump")
		elif f % 10 == 2:
			Input.action_release("jump")
		await physics_frame
		out["sidled"] = out["sidled"] or player.sidling
		out["stuck"] = out["stuck"] or player.stuck
	Input.action_release("move_forward")
	Input.action_release("jump")
	# the passage runs 0.6 m either side of its centre
	out["through"] = player.global_position.z < c.z - 0.8
	out["z"] = snappedf(player.global_position.z - c.z, 0.01)
	return out


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
