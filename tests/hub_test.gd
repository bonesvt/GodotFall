extends SceneTree
## Headless test for the temple hub: the game opens there, you can stand and
## walk in it, everything Eco can look at answers, the map table starts a run,
## and a finished run comes back to the hub.
## Run: godot --headless --path . -s res://tests/hub_test.gd

const HubBuilder := preload("res://scripts/hub/hub_builder.gd")

var run_node
var player
var failures := 0


func _initialize() -> void:
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 99
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(60)
	player = run_node.player
	var info: Dictionary = run_node.zone_info
	_check("game opens in the hub", run_node.phase == run_node.Phase.HUB and run_node.run == null, run_node.phase)
	_check("pilot stands on the temple floor", player.is_on_floor() and absf(player.global_position.y - HubBuilder.F) < 0.3, player.global_position)

	# Walk down the nave toward the idol for two seconds: nothing blocks the middle of the hall.
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _ticks(240)
	Input.action_release("move_forward")
	_check("walk down the nave", start.z - player.global_position.z > 8.0 and player.is_on_floor(), player.global_position)

	# Every interactable answers, and lines cycle.
	var ids := []
	for spot in info["interactables"]:
		ids.append(spot["id"])
		if spot["id"] == "map_table":
			continue
		await _stand_at(spot["pos"])
		_check("prompt at %s" % spot["id"], run_node.nearest_hub_spot().get("id") == spot["id"] and run_node.hud.prompt_label.text == spot["prompt"], run_node.hud.prompt_label.text)
		await _press("interact")
		await _ticks(2)
		_check("%s says something" % spot["id"], run_node.hud.toast_label.text == spot["lines"][0] and run_node.phase == run_node.Phase.HUB, run_node.hud.toast_label.text)
		if spot["lines"].size() > 1:
			await _press("interact")
			await _ticks(2)
			_check("%s lines cycle" % spot["id"], run_node.hud.toast_label.text == spot["lines"][1], run_node.hud.toast_label.text)
	for id in ["map_table", "idol", "titan", "workbench", "bedroll", "letter"]:
		_check("hub has %s" % id, id in ids, ids)
	_check("spot left for Eco at her bench", info.get("eco_spot") is Marker3D, info.get("eco_spot"))

	# The gallery: run up the fallen pillar from the nave onto the ledge.
	var ramp_to := HubBuilder.RAMP_TO
	var ramp_from := HubBuilder.RAMP_FROM + Vector3(HubBuilder.RAMP_FROM.x - ramp_to.x, 0, HubBuilder.RAMP_FROM.z - ramp_to.z).normalized() * 1.5
	await _stand_at(ramp_from)
	player.rotation.y = atan2(-(ramp_to.x - ramp_from.x), -(ramp_to.z - ramp_from.z))
	Input.action_press("move_forward")
	for i in 240:
		await physics_frame
		if _on_gallery():
			break
	Input.action_release("move_forward")
	_check("run up the fallen pillar onto the gallery", _on_gallery(), player.global_position)

	# Falling off the cliff puts you back inside the door, free.
	_place(Vector3(0, -40, 40))
	await _ticks(3)
	_check("falling off the cliff returns you to the door", player.global_position.distance_to(info["spawn"]) < 1.0 and run_node.phase == run_node.Phase.HUB, player.global_position)

	# Map table starts a run.
	await _stand_at(info["map_table"] + Vector3(0, 0.1, 1.4))
	_check("map table prompt", run_node.hud.prompt_label.text == "[F] Head out on a run", run_node.hud.prompt_label.text)
	await _press("interact")
	await _ticks(3)
	_check("map table starts a run", run_node.phase == run_node.Phase.ZONE and run_node.run.zone == 0 and run_node.run.run_seed == 99, run_node.phase)
	_check("hub cleared for the zone", run_node.zone_root.name == "Zone" and run_node.zone_info.has("caches"), run_node.zone_root.name)

	# Losing the run goes back to the temple.
	run_node.end_run("PILOT KIA", "test")
	await _ticks(2)
	_check("summary offers the way home", run_node.hud.summary_label.text.contains("back to the temple"), run_node.hud.summary_label.text)
	await _press("run_restart")
	await _ticks(3)
	_check("run end returns to the hub", run_node.phase == run_node.Phase.HUB and run_node.zone_root.name == "Hub" and player.visible, run_node.phase)
	_check("hub remembers the last run", run_node.hud.status_label.text.contains("PILOT KIA") and run_node.runs_started == 1, run_node.hud.status_label.text)

	# Winning in a titan also comes back, with the pilot back in control.
	run_node.start_run(99)
	run_node.load_zone(3)
	await _ticks(2)
	run_node.call_titan()
	await _ticks(400)
	_place(run_node.titan.global_position + Vector3(0, 0.5, 2.5))
	await _ticks(2)
	run_node.embark()
	await _ticks(2)
	run_node.boss.hp = 1.0
	run_node.boss.take_damage(5.0)
	await _ticks(3)
	_check("titan win ends the run", run_node.result == "RUN COMPLETE", run_node.result)
	await _press("run_restart")
	await _ticks(3)
	_check("win returns to the hub on foot", run_node.phase == run_node.Phase.HUB and player.visible and player.get_node("Head/Camera3D").current, run_node.phase)

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _on_gallery() -> bool:
	var p: Vector3 = player.global_position
	return player.is_on_floor() and p.x < -HubBuilder.HALF + 3.0 and absf(p.y - (HubBuilder.F + HubBuilder.GALLERY_H)) < 0.2


func _stand_at(pos: Vector3) -> void:
	_place(pos + Vector3(0, 0.3, 0))
	await _ticks(30)


func _place(pos: Vector3) -> void:
	for a in ["move_forward", "crouch", "jump", "grapple", "interact"]:
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
