extends SceneTree
## Headless test for the third person combat feel presets (scripts/tp_feel.gd)
## and Eco's combat moves (scripts/ps2/eco_combat_moves.gd).
## Run: godot --headless --path . -s res://tests/tp_feel_test.gd

var player
var feel
var moves
var stance
var failures := 0


func _initialize() -> void:
	var level: Node = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	_run.call_deferred()


func _run() -> void:
	await _ticks(30)
	player = root.get_node("TestLevel/Player")
	feel = player.get_node("TpFeel")
	moves = player.get_node("EcoBody").moves
	stance = player.get_node("EcoBody").stance
	var view = player.get_node("ViewCam")
	var shadow = player.get_node("EcoBody").shadow
	_check("combat moves layer on her model", moves != null, moves)
	view.set_third_person(true)

	# --- presets reach the camera, her body and her gun
	feel.apply_preset("fluid")
	_check("fluid: camera floats", is_equal_approx(view.follow_rate, 12.0) and moves.leg_twist == 1.0, [view.follow_rate, moves.leg_twist])
	feel.apply_preset("current")
	_check("current: as before", is_equal_approx(view.follow_rate, 30.0) and moves.leg_twist == 0.0 and not stance.aim_while_moving, [view.follow_rate, moves.leg_twist])

	# --- current: strafing doesn't turn her legs
	_place(Vector3(0, 0.1, 0), 0.0)
	await _ticks(30)
	Input.action_press("move_left")
	await _ticks(60)
	_check("current: no leg twist", absf(moves.twist) < 0.01, moves.twist)
	Input.action_release("move_left")

	# --- fluid: strafing left turns her hips left, her chest stays on the aim
	feel.apply_preset("fluid")
	_place(Vector3(0, 0.1, 0), 0.0)
	await _ticks(30)
	Input.action_press("move_left")
	await _ticks(60)
	_check("fluid: legs turn toward a left strafe", moves.twist > deg_to_rad(55.0), rad_to_deg(moves.twist))
	# bone attachments see the pose after the modifiers ran
	var sk: Skeleton3D = shadow.skeleton
	var turns := []
	for bone in ["J_Bip_C_Hips", "J_Bip_C_UpperChest"]:
		var att := BoneAttachment3D.new()
		att.bone_name = bone
		sk.add_child(att)
		await process_frame
		await process_frame
		var rest: Vector3 = sk.global_basis * sk.get_bone_global_rest(sk.find_bone(bone)).basis * Vector3.FORWARD
		var now: Vector3 = att.global_basis * Vector3.FORWARD
		rest.y = 0.0
		now.y = 0.0
		turns.append(rest.normalized().signed_angle_to(now.normalized(), Vector3.UP))
		att.queue_free()
	var hips_turn: float = turns[0]
	var chest_turn: float = absf(turns[1])
	var fwd: Vector3 = -player.global_basis.z
	_check("fluid: hips turned, chest still facing the aim", hips_turn > deg_to_rad(40.0) and chest_turn < deg_to_rad(25.0), [rad_to_deg(hips_turn), rad_to_deg(chest_turn), fwd])
	Input.action_release("move_left")

	# --- backpedal: legs face forward and the stride runs backwards
	_place(Vector3(0, 0.1, 0), 0.0)
	await _ticks(20)
	Input.action_press("move_back")
	await _ticks(60)
	var anim: AnimationPlayer = shadow.get("_anim")
	_check("fluid: backpedals", moves.backpedal and absf(moves.twist) < deg_to_rad(15.0) and anim.speed_scale < 0.0, [moves.backpedal, rad_to_deg(moves.twist), anim.speed_scale])
	Input.action_release("move_back")
	await _ticks(60)
	_check("stride forward again", not moves.backpedal and anim.speed_scale >= 0.0, [moves.backpedal, anim.speed_scale])

	# --- turning on the spot: feet hold for a small turn, step round for a big one
	_place(Vector3(0, 0.1, 0), 0.0)
	await _ticks(60)
	player.rotation.y = deg_to_rad(30.0)
	await _ticks(30)
	_check("fluid: feet stay planted on a small turn", moves.twist < deg_to_rad(-22.0), rad_to_deg(moves.twist))
	player.rotation.y = deg_to_rad(110.0)
	await _ticks(120)
	_check("fluid: steps round on a big turn", absf(moves.twist) < deg_to_rad(10.0), rad_to_deg(moves.twist))

	# --- shooting focus pulls the camera in and narrows the view
	var cam: Camera3D = player.get_node("Head/Camera3D")
	await _ticks(60)
	var before: float = cam.position.z
	var weapon = player.get_node("Head/Camera3D/Weapon")
	weapon.since_shot = 0.0
	await _ticks(40)
	_check("fluid: shooting pulls the camera in", cam.position.z < before - 0.15 and player.base_fov < view.tp_fov - 2.0, [before, cam.position.z, player.base_fov])
	weapon.since_shot = 10.0
	await _ticks(300)
	_check("focus eases back out", feel.focus < 0.05 and absf(player.base_fov - view.tp_fov) < 0.01, [feel.focus, player.base_fov])

	# --- snappy: the gun stays up on the run
	feel.apply_preset("snappy")
	_place(Vector3(0, 0.1, 0), 0.0)
	Input.action_press("move_forward")
	await _ticks(90)
	_check("snappy: gun up while running", stance.aim > 0.8, stance.aim)
	Input.action_release("move_forward")

	# --- a hit flinches her
	feel.apply_preset("fluid")
	_place(Vector3(0, 0.1, 0), 0.0)
	await _ticks(30)
	player.take_damage(10.0, player.global_position + Vector3(-5, 0, 0))
	await _ticks(6)
	_check("flinches from a hit", moves.get("_flinch").length() > 0.02, moves.get("_flinch"))
	player.health = player.max_health

	# --- back to first person: nothing left on the camera
	view.set_third_person(false)
	await _ticks(10)
	_check("first person camera untouched", cam.position == Vector3.ZERO, cam.position)

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


func _place(pos: Vector3, yaw: float) -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "crouch", "jump", "grapple"]:
		Input.action_release(a)
	player.global_position = pos
	player.rotation.y = yaw
	player.get_node("Head").rotation.x = 0.0
	player.velocity = Vector3.ZERO


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
