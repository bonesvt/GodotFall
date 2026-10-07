extends SceneTree
## Walls push Eco's soft parts (eco_model.gd _collide): backing her into a
## wall presses her glutes forward off it; stepping away lets them spring
## back past rest and settle; with jiggle_collide off the wall does nothing.
## Run: godot --headless --path . -s res://tests/jiggle_collide_test.gd

const ECO := preload("res://assets/models/eco.tscn")

var failures := 0


func _initialize() -> void:
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	# a wall behind her: its front face at z = 0.1 (she faces -Z, her glutes stick out to +Z)
	var wall := StaticBody3D.new()
	var box := CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	(box.shape as BoxShape3D).size = Vector3(4, 3, 1)
	wall.add_child(box)
	wall.position = Vector3(0, 1.5, 0.6)
	root.add_child(wall)

	var pressed := await _pressed(true)
	var free := await _pressed(false)
	print("glute turn with the wall at her back: collide on %.1f deg, off %.1f deg" % [pressed[0], free[0]])
	_check("the wall presses her glutes", pressed[0] > 5.0, pressed)
	_check("with collisions off it doesn't", free[0] < 2.0, free)
	_check("stepping away, they spring loose", pressed[1] > 2.0, pressed)

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## Stands her just in front of the wall, backs her 6 cm into it, then steps
## her away: [glute turn while pressed, biggest swing after stepping away].
func _pressed(collide: bool) -> Array:
	var eco = ECO.instantiate()
	eco.jiggle_style = "classic"
	eco.idle_motion = false
	eco.jiggle_collide = collide
	root.add_child(eco)
	eco.position.z = -0.02
	await _frames(30)
	for f in 10:
		eco.position.z = -0.02 + 0.06 * (f + 1) / 10.0
		await process_frame
	await _frames(20)
	var held := _angle(eco.skeleton, "J_Sec_L_Glute1")
	eco.position.z = -0.4
	var after := 0.0
	for f in 30:
		await process_frame
		after = maxf(after, _angle(eco.skeleton, "J_Sec_L_Glute1"))
	eco.queue_free()
	await process_frame
	return [held, after]


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
