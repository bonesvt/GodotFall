extends SceneTree
## Headless test for Eco in first person: her own arm on the gun
## (scripts/eco_fp_arms.gd) and her chest bouncing on the first-person body
## (scripts/eco_fp_body.gd) when she jumps, lands and looks about.
## Run: godot --headless --path . -s res://tests/fp_body_test.gd

const EcoArms := preload("res://scripts/eco_fp_arms.gd")

var player
var failures := 0


func _initialize() -> void:
	Engine.max_fps = 60  # the springs step per frame, so run them at game speed
	var level: Node = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	_run.call_deferred()


func _run() -> void:
	await _ticks(30)
	player = root.get_node("TestLevel/Player")
	var eco = player.get_node("EcoBody")
	var weapon = player.get_node("Head/Camera3D/Weapon")
	var cam: Camera3D = player.camera
	_place(Vector3(0, 0.1, 6), 0.0)
	await _ticks(20)

	# her arm: her own model, cut down to the right arm, hand round the grip
	var arm = weapon.viewmodel.find_child("Arm", true, false)
	_check("the gun carries her own arm", arm is EcoArms, arm)
	var sk: Skeleton3D = arm.skeleton
	var hand: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("J_Bip_R_Hand")).origin
	var grip: Vector3 = arm.global_transform * arm.wrist
	_check("her wrist sits at the grip", hand.distance_to(grip) < 0.005, hand.distance_to(grip))
	var on_screen := cam.is_position_in_frustum(sk.global_transform * sk.get_bone_global_pose(sk.find_bone("J_Bip_R_Middle2")).origin)
	_check("her hand is on screen", on_screen, null)
	var shown := 0
	var face_cut := true
	for mi in arm.find_children("*", "MeshInstance3D", true, false):
		if mi.visible and mi.mesh != null and mi.is_visible_in_tree():
			shown += 1
		if mi.name == "Face" or mi.name == "Hair":
			face_cut = face_cut and mi.mesh == null
	_check("only her arm is drawn (no face, no hair)", face_cut and shown >= 1, shown)
	# the arm dresses like her body
	eco.set_suit(5, "heavy")
	await _frames(20)
	_check("the arm follows her suit tier and weight", arm.model.suit_tier == 5 and arm.model.suit_weight == "heavy", [arm.model.suit_tier, arm.model.suit_weight])
	var bracer = arm.model.find_child("suit_t1h_bracer_r", true, false)
	_check("heavy suit shows her right bracer on the arm", bracer != null and bracer.visible and bracer.mesh != null, bracer)
	var left_bracer = arm.model.find_child("suit_t1h_bracer_l", true, false)
	_check("the left bracer is cut away", left_bracer == null or left_bracer.mesh == null, left_bracer)
	eco.set_suit(0, "medium")
	await _frames(20)

	# her chest springs run on the first-person body
	var body = eco.body
	_check("first-person body runs her springs", body.springs_enabled, null)
	_check("first-person jiggle turned up", body.jiggle > 1.0, body.jiggle)
	# looking down she sees her chest
	_place(Vector3(0, 0.1, 6), 0.0)
	player.get_node("Head").rotation.x = deg_to_rad(-45)
	await _ticks(20)
	var bsk: Skeleton3D = body.skeleton
	var tip: Vector3 = bsk.global_transform * bsk.get_bone_global_pose(bsk.find_bone("J_Sec_L_Bust2")).origin
	_check("looking 45 degrees down shows her chest", cam.is_position_in_frustum(tip), cam.to_local(tip))
	player.get_node("Head").rotation.x = 0.0
	await _ticks(20)
	_place(Vector3(0, 0.1, 6), 0.0)
	await _ticks(60)
	var calm := _angle(body.skeleton, "J_Sec_L_Bust1")
	var peak := 0.0
	await _press("jump")
	for i in 90:
		await physics_frame
		peak = maxf(peak, _angle(body.skeleton, "J_Sec_L_Bust1"))
	_check("a jump and landing bounce her chest hard", peak > 14.0, [calm, peak])
	await _ticks(120)
	_check("it settles after the landing", _angle(body.skeleton, "J_Sec_L_Bust1") < 4.0, _angle(body.skeleton, "J_Sec_L_Bust1"))

	# a quick look left and right swings it
	peak = 0.0
	for i in 30:
		player.rotation.y = sin(i * 0.5) * 0.6
		player.get_node("Head").rotation.x = cos(i * 0.5) * 0.3 - 0.6
		await physics_frame
		peak = maxf(peak, _angle(body.skeleton, "J_Sec_L_Bust1"))
	_check("shaking the view swings her chest", peak > 10.0, peak)

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


func _place(pos: Vector3, yaw: float) -> void:
	player.global_position = pos
	player.rotation.y = yaw
	player.get_node("Head").rotation.x = 0.0
	player.velocity = Vector3.ZERO


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	await physics_frame
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)
	await physics_frame


## How far a bone has turned from its rest pose, in degrees.
func _angle(sk: Skeleton3D, bone: String) -> float:
	var i := sk.find_bone(bone)
	var q := sk.get_bone_pose_rotation(i)
	return rad_to_deg((sk.get_bone_rest(i).basis.get_rotation_quaternion().inverse() * q).get_angle())


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
