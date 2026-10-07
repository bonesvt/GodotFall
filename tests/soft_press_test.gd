extends SceneTree
## Off duty, Eco presses into walls softly (player.gd soft_press): her capsule
## is only her core (0.11 m), and from first touch at 0.16 m her speed into a
## wall is soaked up more the deeper she goes, all of it at her core; moving
## away is free, and standing still her soft parts ease her back out. On duty
## her full 0.4 m capsule is unchanged.
## Run: godot --headless --path . -s res://tests/soft_press_test.gd

const PLAYER := preload("res://scenes/player.tscn")

var failures := 0


func _initialize() -> void:
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	# a wall with its face at z = -1 (she faces it, -Z)
	var wall := StaticBody3D.new()
	var box := CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	(box.shape as BoxShape3D).size = Vector3(4, 3, 1)
	wall.add_child(box)
	wall.position = Vector3(0, 1.5, -1.5)
	root.add_child(wall)
	var player = PLAYER.instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.strolling = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await physics_frame
	_check("off duty her capsule is her core", is_equal_approx((player.collision.shape as CapsuleShape3D).radius, 0.11), (player.collision.shape as CapsuleShape3D).radius)

	var toward := Vector3(0, 0, -1.9)
	var speeds := []
	for gap in [0.2, 0.155, 0.14, 0.125, 0.112]:
		player.global_position = Vector3(0, 0, -1.0 + gap)
		await physics_frame
		var v: Vector3 = player.soft_press(toward)
		speeds.append(-v.z)
		print("middle %.3f m off the wall: walks in at %.2f m/s, press %.2f" % [gap, -v.z, player.press])
	_check("out of reach, nothing changes", is_equal_approx(speeds[0], 1.9), speeds[0])
	_check("first touch barely slows her", speeds[1] > 1.5, speeds[1])
	_check("pressing deeper slows her more", speeds[2] < speeds[1] and speeds[3] < speeds[2] and speeds[4] < speeds[3], speeds)
	_check("at her core she barely moves", speeds[4] < 0.05, speeds[4])

	player.global_position = Vector3(0, 0, -1.0 + 0.125)
	await physics_frame
	var away: Vector3 = player.soft_press(Vector3(0, 0, 1.9))
	_check("stepping away is free", is_equal_approx(away.z, 1.9), away)
	var idle: Vector3 = player.soft_press(Vector3.ZERO)
	_check("standing still, she's eased back out", idle.z > 0.1, idle)
	var along: Vector3 = player.soft_press(Vector3(1.0, 0, 0))
	_check("walking along the wall isn't slowed", is_equal_approx(along.x, 1.0), along)

	# pushing on at full press: over two seconds her core gives and she sinks further
	player.global_position = Vector3(0, 0, -1.0 + 0.112)
	await physics_frame
	for f in 150:
		var v: Vector3 = player.soft_press(toward)
		player.global_position += v / 60.0
		await physics_frame
	print("after pushing 2.5 s: middle %.3f m off the wall" % (player.global_position.z + 1.0))
	var cap := player.collision.shape as CapsuleShape3D
	_check("pushing on, her soft parts spread and her core gives", player.spread > 0.99 and cap.radius < 0.101, [player.spread, cap.radius])
	_check("so she sinks in a little further, but no deeper than her ribs", player.global_position.z + 1.0 < 0.108 and player.global_position.z + 1.0 > 0.099, player.global_position.z + 1.0)
	for f in 40:
		player.soft_press(Vector3.ZERO)
	_check("letting up, it comes back", player.spread < 0.01 and cap.radius > 0.109, [player.spread, cap.radius])

	player.strolling = false
	_check("on duty her capsule is 0.4 m again", is_equal_approx((player.collision.shape as CapsuleShape3D).radius, 0.4), (player.collision.shape as CapsuleShape3D).radius)
	player.queue_free()

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
