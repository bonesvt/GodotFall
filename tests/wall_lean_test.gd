extends SceneTree
## Off duty, Eco leans back on a wall behind her (eco_model.gd _wall_lean):
## her capsule (0.4 m) keeps her backside 27 cm off it, so standing still she
## eases back until the wall presses her glutes, and comes off it once she
## moves. On duty (a run) or in first person she doesn't. Off duty the
## player's capsule slims to 0.15 m (player.gd STROLL_RADIUS), so she can
## stand right up against a wall and still lean into it.
## Run: godot --headless --path . -s res://tests/wall_lean_test.gd

const ECO := preload("res://assets/models/eco.tscn")
const PLAYER := preload("res://scenes/player.tscn")

var failures := 0


class Walker extends CharacterBody3D:
	var state := 0
	var crouching := false
	var strolling := true
	var third_person := true
	var resting := false


func _initialize() -> void:
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	# a wall with its face where her capsule would stop her (she faces -Z)
	var wall := StaticBody3D.new()
	var box := CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	(box.shape as BoxShape3D).size = Vector3(4, 3, 1)
	wall.add_child(box)
	wall.position = Vector3(0, 1.5, 0.4 + 0.5)
	root.add_child(wall)

	var leaning := await _stand(true, true)
	print("off duty: eased back %.0f cm, glute turn %.1f deg; walking off %.0f cm" % [leaning[0] * 100, leaning[1], leaning[2] * 100])
	_check("off duty she eases back onto the wall", leaning[0] > 0.25 and leaning[0] < 0.3, leaning[0])
	_check("the wall presses her glutes", leaning[1] > 3.0, leaning[1])
	_check("she comes off it when she walks", leaning[2] < 0.01, leaning[2])
	wall.position.z = 0.15 + 0.5
	var slim := await _stand(true, true)
	print("against the wall with the slim capsule: eased back %.1f cm, glute turn %.1f deg" % [slim[0] * 100, slim[1]])
	_check("with the slim capsule she leans in a little", slim[0] > 0.02 and slim[0] < 0.06, slim[0])
	_check("and the wall presses her glutes", slim[1] > 3.0, slim[1])

	var player = PLAYER.instantiate()
	root.add_child(player)
	await process_frame
	var cap := player.collision.shape as CapsuleShape3D
	_check("on duty her capsule is 0.4 m", is_equal_approx(cap.radius, 0.4), cap.radius)
	player.strolling = true
	_check("off duty it slims to 0.15 m", is_equal_approx(cap.radius, 0.15), cap.radius)
	player.strolling = false
	_check("and back on a run", is_equal_approx(cap.radius, 0.4), cap.radius)
	player.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var duty := await _stand(false, true)
	_check("on a run she doesn't lean", duty[0] < 0.001, duty[0])
	var fp := await _stand(true, false)
	_check("in first person she doesn't lean", fp[0] < 0.001, fp[0])

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## Stands her 2 s with her back to the wall, then walks her off it:
## [how far she eased back, her left glute's turn, how far back half a second into walking].
func _stand(strolling: bool, third: bool) -> Array:
	var walker := Walker.new()
	walker.strolling = strolling
	walker.third_person = third
	root.add_child(walker)
	var eco = ECO.instantiate()
	eco.jiggle_style = "classic"
	walker.add_child(eco)
	await _frames(120)
	var out := [eco._lean, _angle(eco.skeleton, "J_Sec_L_Glute1")]
	walker.velocity = Vector3(0, 0, -1.0)
	for f in 30:
		walker.position += walker.velocity / 60.0
		await process_frame
	out.append(eco._lean)
	walker.queue_free()
	await process_frame
	return out


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _angle(sk: Skeleton3D, bone: String) -> float:
	var i := sk.find_bone(bone)
	var q := sk.get_bone_pose_rotation(i)
	return rad_to_deg((sk.get_bone_rest(i).basis.get_rotation_quaternion().inverse() * q).get_angle())


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
