extends SceneTree
## Headless test for the temple hub: the game opens there, you can stand and
## walk in it, everything Eco can look at answers, the map table starts a run,
## and a finished run comes back to the hub.
## Run: godot --headless --path . -s res://tests/hub_test.gd

const HubBuilder := preload("res://scripts/hub/hub_builder.gd")
const Grounds := preload("res://scripts/hub/hub_grounds.gd")

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

	# Grounds: walled in on every side.
	for probe in [Vector3(-90, 3, 0), Vector3(90, 3, 0), Vector3(0, 3, -110), Vector3(0, 3, 115)]:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 3, 0) if probe.z < 0 else Vector3(0, 3, 40), probe)
		var hit := root.get_world_3d().direct_space_state.intersect_ray(ray)
		_check("grounds closed toward %s" % probe, not hit.is_empty(), probe)

	# Shooting range: the pistol knocks targets down and the board counts them.
	var targets: Array = info["range_targets"]
	var target: Node3D = targets[0]
	await _stand_at(Vector3(Grounds.RANGE_LINE + 1.5, 0.1, target.global_position.z))
	player.rotation.y = PI / 2.0  # face -X, downrange
	await _ticks(2)
	var cam: Camera3D = player.get_node("Head/Camera3D")
	var aim: Vector3 = target.global_position + Vector3(0, 1.15, 0) - cam.global_position
	player.head.rotation.x = atan2(aim.y, Vector2(aim.x, aim.z).length())
	var weapon = player.get_node("Head/Camera3D/Weapon")
	weapon.base_spread = 0.0
	weapon.refill()
	await _ticks(30)
	await _press("fire")
	await _ticks(5)
	_check("pistol knocks a range target down", target.down and info["range_score"]["hits"] == 1, info["range_score"])
	await _ticks(400)
	_check("range target pops back up", not target.down, target.down)

	# Movement course clock: armed on the start pad, runs once you leave, stops at the finish.
	var course: Dictionary = info["course"]
	await _stand_at(course["start"])
	_check("start pad arms the clock", run_node.course_armed, run_node.course_armed)
	_place(course["start"] + Vector3(4.5, 0.6, 0))
	await _ticks(20)
	_check("leaving the pad starts the clock", run_node.course_time > 0.0, run_node.course_time)
	await _stand_at(course["finish"])
	_check("finish tower stops the clock", run_node.course_time < 0.0 and run_node.course_best > 0.0, run_node.course_best)
	await _stand_at(course["start"])
	_place(course["start"] + Vector3(-5, 0.5, 0))
	await _ticks(40)
	_check("touching the grass resets the run", run_node.course_time < 0.0, run_node.course_time)

	# Titan yard: call the practice titan, embark, walk, shoot a dummy, climb out.
	var pad: Vector3 = info["titan_pad"]
	await _stand_at(pad + Vector3(9, 0, -6))
	player.rotation.y = PI  # face +Z, toward the pad
	await _ticks(2)
	_check("yard prompt", run_node.hud.prompt_label.text.contains("Call in your titan"), run_node.hud.prompt_label.text)
	await _press("titan_core")
	await _ticks(300)
	var practice = run_node.hub_titan
	_check("practice titan lands in the yard", practice != null and not practice.dropping, practice)
	_place(practice.global_position + Vector3(0, 0.5, -3.0))
	await _ticks(5)
	await _press("interact")
	await _ticks(3)
	_check("embark the practice titan", run_node.hub_piloting and practice.camera.current and not player.visible, run_node.hub_piloting)
	var t0: Vector3 = practice.global_position
	Input.action_press("move_forward")
	await _ticks(90)
	Input.action_release("move_forward")
	_check("practice titan walks", practice.global_position.distance_to(t0) > 3.0, practice.global_position)
	var dummy: Node3D = info["dummies"][1]
	var to_dummy: Vector3 = dummy.global_position - practice.global_position
	practice.rotation.y = atan2(-to_dummy.x, -to_dummy.z)
	practice.head.rotation.x = atan2(4.5 - practice.EYE, Vector2(to_dummy.x, to_dummy.z).length())
	var hp0: float = dummy.hp
	Input.action_press("titan_fire")
	await _ticks(60)
	Input.action_release("titan_fire")
	_check("titan gun hits a dummy", dummy.hp < hp0, dummy.hp)
	await _press("interact")
	await _ticks(3)
	_check("climb out of the titan", not run_node.hub_piloting and player.visible and player.get_node("Head/Camera3D").current and player.global_position.distance_to(practice.global_position) < 8.0, player.global_position)

	# Falling out of the world puts you back inside the door, free.
	_place(Vector3(0, -40, 40))
	await _ticks(3)
	_check("falling out of the world returns you to the door", player.global_position.distance_to(info["spawn"]) < 1.0 and run_node.phase == run_node.Phase.HUB, player.global_position)

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
