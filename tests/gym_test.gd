extends SceneTree
## Headless test for Biggie's gym (gym_room.gd, gym_workout.gd, gym.gd): the
## room is through the back of his den, every workout plays its scene with
## Eco posed at the equipment, F skips it, the points are saved and shape her
## model, and each workout rests until the next run.
## Run: godot --headless --path . -s res://tests/gym_test.gd

const Gym := preload("res://scripts/hub/gym.gd")
const GymRoom := preload("res://scripts/hub/gym_room.gd")
const Armory := preload("res://scripts/hub/armory.gd")

const ARMORY := "user://test_gym_armory.cfg"
const NPCS := "user://test_gym_npcs.cfg"

var run_node
var player
var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARMORY))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(NPCS))
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 99
	run_node.armory_path = ARMORY
	run_node.npc_path = NPCS
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(60)
	player = run_node.player
	var info: Dictionary = run_node.zone_info

	# Points: capped, and what each part gets.
	var f := Gym.fresh()
	var got := Gym.train(f, "squat")
	_check("squats train glutes and legs", got == {"glutes": 8, "legs": 8} and f["glutes"] == 8, got)
	for i in 20:
		Gym.train(f, "squat")
	_check("points stop at the most a body holds", f["glutes"] == Gym.MAX_POINTS and Gym.train(f, "squat").is_empty(), f)

	# The room: through a door in the back of Biggie's den, and on the training grounds.
	var gym: Dictionary = info.get("gym", {})
	_check("every workout has a spot", gym.size() == Gym.WORKOUTS.size(), gym.keys())
	var through := PhysicsRayQueryParameters3D.create(Vector3(GymRoom.DOOR_X, 2.2, -35.0), Vector3(GymRoom.DOOR_X, 2.2, -41.0))
	_check("door from Biggie's den into the gym", root.get_world_3d().direct_space_state.intersect_ray(through).is_empty(), through.to)
	var beside := PhysicsRayQueryParameters3D.create(Vector3(7.0, 2.2, -35.0), Vector3(7.0, 2.2, -41.0))
	_check("a wall between the den and the gym", not root.get_world_3d().direct_space_state.intersect_ray(beside).is_empty(), beside.to)
	await _stand_at(gym["squat"]["pos"] + Vector3(0, 0, 0.6))
	_check("she stands on the gym floor", player.is_on_floor() and absf(player.global_position.y - 1.2) < 0.3, player.global_position)
	_check("full speed in the gym", not player.strolling, player.strolling)
	var board: Label3D = info.get("gym_board")
	_check("Biggie's chalkboard starts blank", board != null and board.text == Gym.board_text(Gym.fresh()), board.text if board else null)

	# Every workout: F starts its scene (hub paused, camera on her), she is
	# posed at the equipment, F skips it, the points land.
	for id: String in Gym.WORKOUTS:
		var spot := _spot(info, id)
		await _stand_at(spot["pos"])
		_check("prompt at the %s" % id, run_node.nearest_hub_spot().get("workout") == id, run_node.nearest_hub_spot().get("id"))
		await _press("interact")
		await _ticks(2)
		var w = run_node.workout
		_check("%s scene starts" % id, w != null and paused and not player.visible and get_root().get_camera_3d() == w.camera, [w, paused])
		if w == null:
			continue
		while w.time < 1.25 and w.shot < 1:
			await process_frame
		await _check_pose(id, w)
		await _press("interact")
		await _ticks(3)
		_check("%s skips with F" % id, run_node.workout == null and not paused and player.visible, run_node.workout)
		_check("%s adds its points" % id, run_node.armory.fitness == _expected(id), run_node.armory.fitness)
		_check("%s's prop is back in the room" % id, gym[id].get("prop") == null or gym[id]["prop"].visible, id)
		await _press("interact")
		await _ticks(2)
		_check("%s rests until the next run" % id, run_node.workout == null and run_node.hud.toast_label.text.begins_with("BIGGIE"), run_node.hud.toast_label.text)

	# What she trained is saved, shapes her, and is chalked up.
	var saved := Armory.open(ARMORY)
	_check("training is saved", saved.fitness == run_node.armory.fitness, saved.fitness)
	_check("chalkboard keeps score", board.text == Gym.board_text(run_node.armory.fitness), board.text)
	var eco = player.get_node("EcoBody").shadow
	var shaped := 0.0
	var toned := Vector4.ZERO
	for mi: MeshInstance3D in eco.find_children("*", "MeshInstance3D", true, false):
		var b := mi.find_blend_shape_by_name("Fit_Glutes")
		if b >= 0 and mi.name.contains("Body"):
			shaped = mi.get_blend_shape_value(b)
			toned = mi.get_instance_shader_parameter("tone")
	var amounts := Gym.amounts(run_node.armory.fitness)
	_check("her glutes fill out as she trains", is_equal_approx(shaped, amounts["glutes"]) and shaped > 0.0, shaped)
	_check("her stomach, abs, arms and legs tone up", toned.is_equal_approx(Vector4(amounts["abs"], amounts["arms"], amounts["legs"], amounts["stomach"])) and toned.x > 0.0 and toned.w > 0.0, toned)

	# A run later, the gym is open again.
	run_node.start_run(5)
	await _ticks(10)
	run_node.enter_hub()
	await _ticks(30)
	await _stand_at(_spot(run_node.zone_info, "squat")["pos"])
	await _press("interact")
	await _ticks(2)
	_check("after a run the workouts come back", run_node.workout != null, run_node.workout)
	if run_node.workout != null:
		run_node.workout.time = 1.0
		await _press("interact")
		await _ticks(2)
	await _partners()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARMORY))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(NPCS))
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


## Mom and Ophelia: [B] by them asks them along, they wait in the gym, train
## beside her in every workout instead of Biggie, and their bodies take the
## same points as hers. Ophelia's is a date once she'll go on one.
func _partners() -> void:
	run_node.gym_done.clear()
	var info: Dictionary = run_node.zone_info
	var mom: Node3D = run_node.hub_npcs["mom"]
	var talk := _npc_spot(info, "mom")
	await _stand_at(talk["pos"])
	_check("Mom can be asked to the gym", run_node._prompt().contains("[B] Train together"), run_node._prompt())
	await _press("invite_gym")
	await _ticks(2)
	_check("asking her starts a talk", run_node.npc_talk.active() and run_node.gym_partner == "", run_node.npc_talk.current_line())
	await _talk_through()
	var wait: Dictionary = info["gym_wait"]
	_check("Mom waits in the gym", run_node.gym_partner == "mom" and mom.global_position.distance_to(wait["pos"]) < 0.1 and mom.outfit == "tight", [run_node.gym_partner, mom.global_position, mom.outfit])
	_check("her talk spot goes with her", _npc_spot(info, "mom")["pos"].distance_to(wait["pos"]) < 0.1, _npc_spot(info, "mom")["pos"])
	var expected := Gym.fresh()
	for id: String in Gym.WORKOUTS:
		await _stand_at(_spot(info, id)["pos"])
		_check("%s with Mom: prompt says so" % id, run_node._prompt().ends_with("with Mom"), run_node._prompt())
		await _press("interact")
		await _ticks(2)
		var w = run_node.workout
		_check("%s with Mom: she trains beside her, no Biggie" % id, w != null and w.follower != null and w.follower.npc != null and not mom.visible
				and w._name.text != "BIGGIE", [w, w._name.text if w else ""])
		if w == null or w.follower == null:
			continue
		while w.time < 1.25 and w.shot < 1:
			await process_frame
		await _check_partner_pose(id, w.follower)
		await _press("interact")
		await _ticks(3)
		Gym.train(expected, id)
		_check("%s with Mom: her points saved too" % id, run_node.armory.fitness_of("mom") == expected and mom.visible and run_node.hud.toast_label.text.contains("MOM"), run_node.armory.fitness_of("mom"))
	var saved := Armory.open(ARMORY)
	_check("Mom's training is saved", saved.fitness_of("mom") == expected, saved.partner_fitness)
	var amounts := Gym.amounts(expected)
	var shaped := -1.0
	var toned := Vector4.ZERO
	for mi: MeshInstance3D in mom.find_children("*", "MeshInstance3D", true, false):
		var b := mi.find_blend_shape_by_name("Fit_Glutes")
		if b >= 0:
			shaped = mi.get_blend_shape_value(b)
			toned = mi.get_instance_shader_parameter("tone")
	_check("Mom's body fills out like Eco's", shaped > 0.0 and is_equal_approx(shaped, amounts["glutes"]), shaped)
	_check("Mom tones up like Eco", toned.is_equal_approx(Vector4(amounts["abs"], amounts["arms"], amounts["legs"], amounts["stomach"])), toned)
	var tone_on := false
	for mi: MeshInstance3D in mom.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as ShaderMaterial
			if m != null and m.resource_name == "npc_mom_body":
				tone_on = m.get_shader_parameter("use_tone") == true and m.get_shader_parameter("tone_tex") != null
	_check("Mom's body material has the muscle tone map", tone_on, tone_on)

	# Ophelia, once she'll date: asking her is a date, and Mom goes home.
	run_node.gym_done.clear()
	var oph: Node3D = run_node.hub_npcs["ophelia"]
	run_node.npc_talk.state.set_value("ophelia", "affection", 80)
	var before: int = run_node.npc_talk.affection("ophelia")
	await _stand_at(_npc_spot(info, "ophelia")["pos"])
	await _press("invite_gym")
	await _ticks(2)
	_check("asking Ophelia is a date", run_node.gym_date and run_node.npc_talk.affection("ophelia") == before + 8, [run_node.gym_date, run_node.npc_talk.affection("ophelia")])
	await _talk_through()
	_check("Ophelia waits in the gym, Mom goes home", run_node.gym_partner == "ophelia" and oph.global_position.distance_to(info["gym_wait"]["pos"]) < 0.1
			and mom.global_position.distance_to(info["gym_wait"]["pos"]) > 3.0 and mom.outfit != "tight", [oph.global_position, mom.global_position, mom.outfit])
	await _stand_at(_spot(info, "crunch")["pos"])
	await _press("interact")
	await _ticks(2)
	var w = run_node.workout
	_check("the gym date plays their date lines", w != null and w.date and w._caption.text == Gym.PARTNER_LINES["ophelia_date"]["crunch"][0][1], w._caption.text if w else "")
	if w != null:
		w.time = 1.0
		await _press("interact")
		await _ticks(3)


## Steps through the talk going on with F.
func _talk_through() -> void:
	for i in 40:
		if not run_node.npc_talk.active():
			break
		await _press("interact")
		await _ticks(4)
	await _ticks(2)


## The partner's pose fits the equipment beside her.
func _check_partner_pose(id: String, f) -> void:
	var sk: Skeleton3D = f._sk
	await sk.skeleton_updated
	var at := func(bone: String) -> Vector3: return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin
	var hand_r: Vector3 = at.call("J_Bip_R_Hand")
	var hand_l: Vector3 = at.call("J_Bip_L_Hand")
	var foot: Vector3 = at.call("J_Bip_R_Foot")
	var hips: Vector3 = at.call("J_Bip_C_Hips")
	var head: Vector3 = at.call("J_Bip_C_Head")
	var floor_y: float = f.spot["pos"].y
	var apart: float = Vector2(hips.x - f.leader.eco.global_position.x, hips.z - f.leader.eco.global_position.z).length()
	_check("%s with Mom: she's beside Eco, not in her" % id, apart > 0.7, apart)
	match id:
		"squat":
			_check("squat with Mom: feet planted, dumbbell at her chest", absf(foot.y - floor_y) < 0.2 and f._prop.global_position.distance_to(hand_r) < 0.2, [foot.y - floor_y, f._prop.global_position.distance_to(hand_r)])
		"pullup":
			var wrist_y: float = floor_y + GymRoom.BAR_H - f.GRIP
			_check("pull-up with Mom: hands on the bar", absf(hand_r.y - wrist_y) < 0.05 and absf(hand_l.y - wrist_y) < 0.05, [hand_r.y - floor_y, hand_l.y - floor_y])
		"bridge", "crunch":
			_check("%s with Mom: lying on her mat" % id, absf(head.y - floor_y) < 0.45 and absf(foot.y - floor_y) < 0.2, [head.y - floor_y, foot.y - floor_y])
		"bag":
			var bag: Vector3 = f.leader.spot["bag"].global_position
			_check("bag with Mom: she holds the bag", hand_r.distance_to(bag) < 0.4 and hand_l.distance_to(bag) < 0.4 and absf(foot.y - floor_y) < 0.2, [hand_r.distance_to(bag), hand_l.distance_to(bag)])


func _npc_spot(info: Dictionary, who: String) -> Dictionary:
	for spot in info["interactables"]:
		if spot.get("npc") == who:
			return spot
	return {}


## The workout's interactable.
func _spot(info: Dictionary, id: String) -> Dictionary:
	for spot in info["interactables"]:
		if spot.get("workout") == id:
			return spot
	return {}


## What the armory should hold after doing every workout up to `id` once, in order.
func _expected(id: String) -> Dictionary:
	var f := Gym.fresh()
	for w: String in Gym.WORKOUTS:
		Gym.train(f, w)
		if w == id:
			break
	return f


## Her pose fits the equipment: hands on the bar, feet on the floor, lying on the mat.
## Read as the skeleton updates, while her posing is applied.
func _check_pose(id: String, w) -> void:
	var sk: Skeleton3D = w.eco.skeleton
	# the pose only holds inside the skeleton's update (eco_pose_modifier.gd)
	await sk.skeleton_updated
	var hand_r := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("J_Bip_R_Hand")).origin
	var hand_l := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("J_Bip_L_Hand")).origin
	var foot := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("J_Bip_R_Foot")).origin
	var hips := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("J_Bip_C_Hips")).origin
	var head := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("J_Bip_C_Head")).origin
	var floor_y: float = w.spot["pos"].y
	match id:
		"squat":
			var bar: Vector3 = w._prop.global_position
			var neck := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("J_Bip_C_Neck")).origin
			var back: Vector3 = w.eco.global_transform.basis.z   # she faces -Z
			_check("squat: bar across her upper back, behind her neck", (bar - neck).dot(back) > 0.06 and bar.y < neck.y + 0.05, [(bar - neck).dot(back), bar.y - neck.y])
			_check("squat: hands round the bar", absf(hand_r.y - bar.y) < 0.12 and hand_r.y < bar.y and hand_l.y < bar.y, [hand_r.y - bar.y, hand_l.y - bar.y])
			_check("squat: feet planted, hips down", absf(foot.y - floor_y) < 0.2 and hips.y < floor_y + 0.85, [foot.y - floor_y, hips.y - floor_y])
		"pullup":
			var wrist_y: float = floor_y + GymRoom.BAR_H - w.GRIP
			_check("pull-up: hands round the bar", absf(hand_r.y - wrist_y) < 0.04 and absf(hand_l.y - wrist_y) < 0.04, [hand_r.y - floor_y, hand_l.y - floor_y])
			_check("pull-up: feet off the floor", foot.y > floor_y + 0.15, foot.y - floor_y)
		"bridge", "crunch":
			_check("%s: lying on the mat" % id, absf(head.y - floor_y) < 0.45 and hips.y < floor_y + 0.5, [head.y - floor_y, hips.y - floor_y])
			_check("%s: feet on the mat" % id, absf(foot.y - floor_y) < 0.2, foot.y - floor_y)
		"bag":
			_check("bag: on her feet, fists up", absf(foot.y - floor_y) < 0.2 and hand_r.y > floor_y + 1.0 and hand_l.y > floor_y + 1.0, [hand_r.y - floor_y, hand_l.y - floor_y])


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
