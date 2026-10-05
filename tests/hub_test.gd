extends SceneTree
## Headless test for the temple hub: the game opens there, you can stand and
## walk in it, everything Eco can look at answers, the stairs climb to her loft,
## the people live in tents outside, the poster outside starts the Pinewoods
## run with a marker over it until that run is won, and a finished run comes
## back to the hub.
## Run: godot --headless --path . -s res://tests/hub_test.gd

const HubBuilder := preload("res://scripts/hub/hub_builder.gd")
const Grounds := preload("res://scripts/hub/hub_grounds.gd")
const TitanStyle := preload("res://scripts/run/titan_style.gd")

var run_node
var player
var failures := 0


func _initialize() -> void:
	# Hints go to their own settings file, so these runs never mark them seen on your save.
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 99
	run_node.armory_path = "user://test_hub_armory.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_node.armory_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(60)
	player = run_node.player
	var info: Dictionary = run_node.zone_info
	_check("game opens in the hub", run_node.phase == run_node.Phase.HUB and run_node.run == null, run_node.phase)
	_check("pilot stands on the temple floor", player.is_on_floor() and absf(player.global_position.y - HubBuilder.F) < 0.3, player.global_position)

	# Walk down the nave toward the idol for two seconds: nothing blocks the middle of the hall.
	# Off duty in the hub she struts at stroll speed instead of running.
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _ticks(240)
	var strut_speed: float = player.horizontal_speed()
	Input.action_release("move_forward")
	_check("walk down the nave", start.z - player.global_position.z > 3.0 and player.is_on_floor(), player.global_position)
	_check("she struts in the hub", player.strolling and absf(strut_speed - player.stroll_speed) < 0.1, [player.strolling, strut_speed])

	# Every interactable answers, and lines cycle.
	var ids := []
	for spot in info["interactables"]:
		ids.append(spot["id"])
		if spot.has("npc"):
			continue   # people talk instead (tests/npc_test.gd)
		if spot.has("family"):
			continue   # Mom's bed: tests/family_test.gd
		if spot["id"] in ["tutorial_poster", "uncharted_map", "garage", "level_board", "level2_board"]:  # level boards: tests/level1_test.gd, level2_test.gd
			continue
		await _stand_at(spot["pos"])
		if spot.has("screen"):
			# Workbenches open their screen (pausing the hub) and F closes it.
			await _press("interact")
			await _ticks(2)
			_check("%s opens its bench" % spot["id"], run_node.bench != null and run_node.bench.kind == spot["screen"] and paused, spot["id"])
			await _press("interact")
			await _ticks(2)
			_check("%s bench closes" % spot["id"], run_node.bench == null and not paused, spot["id"])
			continue
		_check("prompt at %s" % spot["id"], run_node.nearest_hub_spot().get("id") == spot["id"] and run_node.hud.prompt_label.text == spot["prompt"], run_node.hud.prompt_label.text)
		await _press("interact")
		await _ticks(2)
		_check("%s says something" % spot["id"], run_node.hud.toast_label.text == spot["lines"][0] and run_node.phase == run_node.Phase.HUB, run_node.hud.toast_label.text)
		if spot.has("rest"):
			# she sits or lies down there instead (her rest poses are checked below); get her up
			_check("%s lets her rest" % spot["id"], run_node.rest_pose == spot["rest"]["pose"] and player.resting, run_node.rest_pose)
			await _get_up()
			continue
		if spot["lines"].size() > 1:
			await _press("interact")
			await _ticks(2)
			_check("%s lines cycle" % spot["id"], run_node.hud.toast_label.text == spot["lines"][1], run_node.hud.toast_label.text)
	for id in ["tutorial_poster", "level_board", "level2_board", "uncharted_map", "idol", "lore_builders", "lore_eye", "lore_tablets", "titan", "gunsmith",
			"weapon_rack", "suit_locker", "titan_workshop", "bedroll", "letter", "wardrobe", "garage"]:
		_check("hub has %s" % id, id in ids, ids)
	# Downstairs: the statue, lore, mission table, armour bench, gunsmith and rack;
	# her bed, letter and wardrobe are up in the loft; the poster is outside.
	var at := {}
	for spot in info["interactables"]:
		at[spot["id"]] = spot["pos"]
	var loft_y := HubBuilder.F + HubBuilder.GALLERY_H
	var upstairs := ["bedroll", "letter", "wardrobe"].filter(func(id): return absf(at[id].y - loft_y) < 0.3 and HubBuilder.LOFT.has_point(Vector2(at[id].x, at[id].z)))
	_check("bed, letter and wardrobe are in the loft", upstairs.size() == 3, upstairs)
	var hall := Rect2(-HubBuilder.HALF, HubBuilder.BACK_Z, HubBuilder.HALF * 2, HubBuilder.FRONT_Z - HubBuilder.BACK_Z)
	var downstairs := ["idol", "lore_builders", "lore_eye", "lore_tablets", "level_board", "level2_board", "suit_locker", "gunsmith", "weapon_rack"].filter(
			func(id): return absf(at[id].y - HubBuilder.F) < 1.2 and hall.has_point(Vector2(at[id].x, at[id].z)))
	_check("statue, lore, mission table and benches downstairs", downstairs.size() == 9, downstairs)
	var poster: Vector3 = at["tutorial_poster"]
	_check("tutorial poster is outside the temple", not hall.grow(HubBuilder.WALL_T).has_point(Vector2(poster.x, poster.z)) and poster.y < 0.5, poster)
	var marker: Node3D = info["tutorial_marker"]
	_check("marker over the poster on a fresh save", marker.visible and marker.global_position.distance_to(poster) < 4.0, marker.global_position)
	for who in ["mom", "ophelia", "biggie"]:
		var talk: Vector3 = at["npc_" + who]
		_check("%s lives in a tent outside" % who, not hall.grow(HubBuilder.WALL_T + 2.0).has_point(Vector2(talk.x, talk.z)), talk)
	_check("spot left for Eco at her bench", info.get("eco_spot") is Marker3D, info.get("eco_spot"))

	await _rest_checks(info)

	# The paint shop: F opens the garage and pauses the hub, a change is saved
	# for the chassis, and F closes it again.
	TitanStyle.path = "user://titan_style_hub_test.cfg"
	DirAccess.remove_absolute(TitanStyle.path)
	for spot in info["interactables"]:
		if spot["id"] == "garage":
			await _stand_at(spot["pos"])
	await _press("interact")
	await _ticks(2)
	var garage = run_node.garage
	_check("paint shop opens the garage", garage != null and paused, [garage, paused])
	if garage != null:
		garage.change(1, "livery")
		_check("garage saves the paint job", TitanStyle.load_style(garage.chassis)["livery"] == garage.style["livery"] and garage.style["livery"] != "factory", garage.style)
		await _press("interact")
		await _ticks(2)
		_check("F closes the garage", run_node.garage == null and not paused and run_node.phase == run_node.Phase.HUB, [run_node.garage, paused])
	DirAccess.remove_absolute(TitanStyle.path)

	# The loft: walk up the stairs by the door into her bedroom.
	await _stand_at(HubBuilder.STAIRS_FROM + Vector3(0, 0, 0.4))
	player.rotation.y = 0.0  # face -Z, up the stairs
	Input.action_press("move_forward")
	for i in 1200:  # at strut speed
		await physics_frame
		if _on_gallery():
			break
	Input.action_release("move_forward")
	_check("walk up the stairs into the loft", _on_gallery(), player.global_position)

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
	_check("full speed on the training grounds", not player.strolling, player.strolling)
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

	# The poster outside starts the Pinewoods run.
	await _stand_at(info["tutorial_poster"])
	_check("poster prompt", run_node.hud.prompt_label.text.begins_with("[F] Head out on the Pinewoods run"), run_node.hud.prompt_label.text)
	await _press("interact")
	await _ticks(3)
	_check("poster starts the Pinewoods run", run_node.phase == run_node.Phase.ZONE and run_node.run.zone == 0 and run_node.run.run_seed == 99 and run_node.run.level == "", run_node.phase)
	await physics_frame
	_check("no strut on a run", not player.strolling, player.strolling)
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
	run_node.titan.global_position = run_node.zone_info["evac"] + Vector3(0, 0.5, 0)  # walk it to the evac pad
	await _ticks(3)
	_check("titan win ends the run", run_node.result == "RUN COMPLETE", run_node.result)
	await _press("run_restart")
	await _ticks(3)
	_check("win returns to the hub on foot", run_node.phase == run_node.Phase.HUB and player.visible and player.get_node("Head/Camera3D").current, run_node.phase)
	_check("marker over the poster gone once the Pinewoods run is won", not run_node.zone_info["tutorial_marker"].visible, run_node.zone_info["tutorial_marker"].visible)

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


## In third person she lies down on her bed asleep, sits on the couch and
## stretches out along it, and sits by the campfire; a move key or jump gets
## her up and gives the player back.
func _rest_checks(info: Dictionary) -> void:
	var eco_body = player.get_node("EcoBody")
	var eco = eco_body.shadow
	var view = player.get_node("ViewCam")
	var spots := {}
	for spot in info["interactables"]:
		if spot.has("rest"):
			spots[spot["id"]] = spot
	_check("bed, couch and campfire let her rest", spots.has("bedroll") and spots.has("couch") and spots.has("campfire"), spots.keys())
	var hips: int = eco.skeleton.find_bone("J_Bip_C_Hips")
	var head: int = eco.skeleton.find_bone("J_Bip_C_Head")

	await _stand_at(spots["bedroll"]["pos"])
	await _press("interact")
	await _ticks(120)
	var at: Vector3 = spots["bedroll"]["rest"]["at"].origin
	var hips_at: Vector3 = eco.skeleton.global_transform * eco.skeleton.get_bone_global_pose(hips).origin
	var head_at: Vector3 = eco.skeleton.global_transform * eco.skeleton.get_bone_global_pose(head).origin
	_check("she lies down on the bed", eco.rest_pose == "sleep" and Vector2(hips_at.x - at.x, hips_at.z - at.z).length() < 0.1 and absf(hips_at.y - (at.y + 0.77)) < 0.05, hips_at)
	_check("lying flat, head toward the pillow", absf(head_at.y - hips_at.y) < 0.3 and head_at.x < hips_at.x - 0.3, head_at)
	var face := eco.find_child("Face", true, false) as MeshInstance3D
	_check("eyes closed asleep", face.get_blend_shape_value(face.find_blend_shape_by_name("Fcl_EYE_Close")) == 1.0, face)
	_check("resting shows her in third person, gun away", view.third_person and run_node.hud.prompt_label.text == "[F] Get up", run_node.hud.prompt_label.text)
	var stood: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _ticks(10)
	_check("player stays put while she gets up", player.global_position.distance_to(stood) < 0.05, player.global_position)
	Input.action_release("move_forward")
	await _ticks(120)
	_check("up again: player free, view back", not player.resting and run_node.rest_spot.is_empty() and not view.third_person and not eco.top_level, [player.resting, view.third_person])
	_check("eyes open again", face.get_blend_shape_value(face.find_blend_shape_by_name("Fcl_EYE_Close")) == 0.0, face)

	await _stand_at(spots["couch"]["pos"])
	await _press("interact")
	await _ticks(120)
	at = spots["couch"]["rest"]["at"].origin
	hips_at = eco.skeleton.global_transform * eco.skeleton.get_bone_global_pose(hips).origin
	head_at = eco.skeleton.global_transform * eco.skeleton.get_bone_global_pose(head).origin
	_check("she sits on the couch", eco.rest_pose == "sit" and absf(hips_at.y - (at.y + 0.57)) < 0.05 and head_at.y > hips_at.y + 0.45, [hips_at, head_at])
	_check("couch prompt offers stretching out", run_node.hud.prompt_label.text.begins_with("[F] Stretch out"), run_node.hud.prompt_label.text)
	await _press("interact")
	await _ticks(150)
	at = spots["couch"]["rest"]["alt"]["at"].origin
	hips_at = eco.skeleton.global_transform * eco.skeleton.get_bone_global_pose(hips).origin
	head_at = eco.skeleton.global_transform * eco.skeleton.get_bone_global_pose(head).origin
	_check("F stretches her out along the couch", eco.rest_pose == "lounge" and Vector2(hips_at.x - at.x, hips_at.z - at.z).length() < 0.1 and head_at.z < hips_at.z - 0.3, [hips_at, head_at])
	await _press("interact")
	await _ticks(150)
	_check("F again sits her back up", eco.rest_pose == "sit" and player.resting, eco.rest_pose)
	await _get_up()
	_check("jump gets her up from the couch", not player.resting and eco.rest_pose == "", player.resting)

	await _stand_at(spots["campfire"]["pos"])
	await _press("interact")
	await _ticks(120)
	at = spots["campfire"]["rest"]["at"].origin
	hips_at = eco.skeleton.global_transform * eco.skeleton.get_bone_global_pose(hips).origin
	_check("she sits on the bench by the fire", eco.rest_pose == "sit" and Vector2(hips_at.x - at.x, hips_at.z - at.z).length() < 0.1, hips_at)
	await _get_up()


func _get_up() -> void:
	await _press("jump")
	for i in 240:
		if run_node.rest_spot.is_empty():
			break
		await physics_frame


func _on_gallery() -> bool:
	var p: Vector3 = player.global_position
	return player.is_on_floor() and HubBuilder.LOFT.has_point(Vector2(p.x, p.z)) and p.z < HubBuilder.STAIRS_TO.z - 0.3 and absf(p.y - (HubBuilder.F + HubBuilder.GALLERY_H)) < 0.2


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
