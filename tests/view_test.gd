extends SceneTree
## Headless test for the first / third person toggle (scripts/view_camera.gd).
## Run: godot --headless --path . -s res://tests/view_test.gd

const ViewCamera := preload("res://scripts/view_camera.gd")
const Prefs := preload("res://scripts/game/prefs.gd")

var player
var view
var failures := 0


func _initialize() -> void:
	Prefs.path = "user://view_test_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Prefs.path))
	var level: Node = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	_run.call_deferred()


func _run() -> void:
	await _ticks(30)
	player = root.get_node("TestLevel/Player")
	view = player.get_node("ViewCam")
	var cam: Camera3D = player.camera
	var eco = player.get_node("EcoBody")
	_place(Vector3(0, 0.1, 0), 0.0)
	await _ticks(30)

	_check("starts in first person", not view.third_person and cam.position == Vector3.ZERO, cam.position)
	_check("first person shows the gun", cam.get_node("Weapon").visible, null)

	# Toggle with the key
	_place(Vector3(0, 0.1, 0), 0.0)
	await _press("toggle_view")
	await _ticks(60)
	_check("toggle goes third person", view.third_person and player.third_person, view.third_person)
	var behind: float = (cam.global_position - player.get_node("Head").global_position).dot(player.global_basis.z)
	_check("camera sits close behind her", behind > 1.4 and behind < 2.2, behind)
	# Framing, looking straight ahead: crosshair clears her head, knees just in shot
	var sk: Skeleton3D = eco.shadow.skeleton
	var size := Vector2(root.get_visible_rect().size)
	var head_top: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("J_Bip_C_Head")).origin + Vector3.UP * 0.2
	var knee: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("J_Bip_L_LowerLeg")).origin
	var head_y: float = cam.unproject_position(head_top).y / size.y
	var knee_y: float = cam.unproject_position(knee).y / size.y
	print("frame: head top at %.2f, knee at %.2f of screen height (%s)" % [head_y, knee_y, size])
	_check("crosshair clears her head", head_y > 0.5, head_y)
	_check("knees just above the bottom edge", knee_y > 0.8 and knee_y < 1.0, knee_y)
	var right: float = (cam.global_position - player.get_node("Head").global_position).dot(player.global_basis.x)
	_check("over the right shoulder", right > 0.4, right)
	_check("view-model gun hidden", not cam.get_node("Weapon").visible and not cam.get_node("Knife").visible, null)
	_check("full model drawn", eco.shadow.get_child(0) != null and not eco.body.visible, null)
	var mesh: GeometryInstance3D = eco.shadow.find_children("*", "GeometryInstance3D", true, false)[0]
	_check("full model not shadow-only", mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, mesh.cast_shadow)
	_check("pistol in her hand", eco.shadow.find_child("GunHold", true, false) != null, null)
	var arms_on_gun := 0
	for n in eco.shadow.find_child("GunHold", true, false).find_children("*", "", true, false):
		if n.get_script() == preload("res://scripts/eco_fp_arms.gd"):
			arms_on_gun += 1
	_check("no first-person arm rides on her gun", arms_on_gun == 0, arms_on_gun)
	var muzzle: Vector3 = view.muzzle_position()
	_check("tracers start from her gun, not the camera", muzzle.distance_to(player.global_position + Vector3.UP * 1.2) < 1.3 and muzzle.distance_to(cam.global_position) > 1.0, muzzle)

	# Tight: when she moves, the camera keeps up
	var before: Vector3 = cam.global_position
	player.global_position += Vector3(0, 0, -0.5)
	await _ticks(10)
	var moved: float = (cam.global_position - before).length()
	_check("camera keeps up with her", absf(moved - 0.5) < 0.05, moved)
	await _ticks(90)

	# Middle mouse is the view swap's main button (F5 still works)
	var view_keys: Array = InputMap.action_get_events("toggle_view")
	_check("middle mouse swaps the view", view_keys[0] is InputEventMouseButton and view_keys[0].button_index == MOUSE_BUTTON_MIDDLE, view_keys)
	_check("F5 still swaps the view", view_keys.any(func(e): return e is InputEventKey and e.physical_keycode == KEY_F5), view_keys)

	# Shoulder swap key
	var head: Node3D = player.get_node("Head")
	await _press("swap_shoulder")
	await _ticks(60)
	right = (cam.global_position - head.global_position).dot(player.global_basis.x)
	_check("X swaps to the left shoulder", view.side < 0.0 and right < -0.3, right)
	await _press("swap_shoulder")
	await _ticks(60)
	right = (cam.global_position - head.global_position).dot(player.global_basis.x)
	_check("X swaps back to the right", view.side > 0.0 and right > 0.3, right)
	ViewCamera.shoulder_swap_key = false
	await _press("swap_shoulder")
	await _ticks(10)
	_check("swap key off: shoulder stays", view.side > 0.0, view.side)
	ViewCamera.shoulder_swap_key = true

	# Camera distance setting
	ViewCamera.distance_setting = 3.0
	await _ticks(30)
	behind = (cam.global_position - head.global_position).dot(player.global_basis.z)
	_check("distance setting pulls the camera back", absf(behind - 3.0) < 0.15, behind)
	ViewCamera.distance_setting = 1.2
	await _ticks(30)
	behind = (cam.global_position - head.global_position).dot(player.global_basis.z)
	_check("distance setting brings it close", absf(behind - 1.2) < 0.15, behind)
	ViewCamera.distance_setting = 0.0
	await _ticks(30)

	# Hub orbit: the arrow keys nudge the camera, and the distance setting scales it
	player.strolling = true
	await _ticks(90)
	_check("orbiting in the hub", view.orbiting, view.orbiting)
	var start: Vector3 = cam.global_position
	var orbit_back: float = (start - player.global_position - Vector3.UP * view.orbit_height).length()
	Input.action_press("cam_nudge_up")
	Input.action_press("cam_nudge_right")
	await _ticks(20)
	Input.action_release("cam_nudge_up")
	Input.action_release("cam_nudge_right")
	await _ticks(60)
	var shift: Vector3 = cam.global_basis.inverse() * (cam.global_position - start)
	_check("arrow keys nudge the hub camera up and right", shift.y > 0.2 and shift.x > 0.2, shift)
	_check("the nudge is saved", float(Prefs.get_value("game", "hub_nudge_y")) > 0.2, Prefs.get_value("game", "hub_nudge_y"))
	ViewCamera.hub_nudge = Vector2.ZERO
	ViewCamera.distance_setting = view.distance * 2.0
	await _ticks(60)
	var orbit_far: float = (cam.global_position - player.global_position - Vector3.UP * view.orbit_height).length()
	_check("distance setting scales the hub camera", orbit_far > orbit_back * 1.6, [orbit_back, orbit_far])
	ViewCamera.distance_setting = 0.0
	player.strolling = false
	await _ticks(90)

	# Wallrun with the wall on her left: camera stays on the open (right) side
	_place(Vector3(-2.8, 3.0, -20), 0.0)
	view.side = -1.0
	player.velocity = Vector3(-3, 0, -10)
	Input.action_press("move_forward")
	await _until_wallrun()
	await _ticks(30)
	_check("left wall puts the camera right", view.side > 0.0, view.side)
	Input.action_release("move_forward")
	await _ticks(200)

	# Wall on her right: swaps to the left shoulder, and stays there after
	_place(Vector3(2.8, 3.0, -20), 0.0)
	player.velocity = Vector3(3, 0, -10)
	Input.action_press("move_forward")
	await _until_wallrun()
	await _ticks(60)
	_check("right wall swaps to the left shoulder", view.side < 0.0, view.side)
	right = (cam.global_position - player.get_node("Head").global_position).dot(player.global_basis.x)
	_check("camera actually moved left", right < -0.2, right)
	await _press("jump")
	Input.action_release("move_forward")
	await _ticks(60)
	_check("shoulder sticks after the wallrun", view.side < 0.0, view.side)
	await _ticks(200)

	# Never behind a wall: back her up against one and the camera pulls in
	_place(Vector3(0, 0.1, 40), 0.0)
	player.global_position = Vector3(-3.0, 0.1, -30)
	player.rotation.y = deg_to_rad(-90.0)  # facing +X, back to the left wall at x = -3.5
	await _ticks(60)
	_check("camera pulled in front of the wall", cam.global_position.x > -3.5, cam.global_position)

	# Toggle back
	await _press("toggle_view")
	await _ticks(5)
	_check("toggle back to first person", not view.third_person and cam.position == Vector3.ZERO, cam.position)
	_check("first person gun back", cam.get_node("Weapon").visible and eco.body.visible, null)
	_check("pistol leaves her hand", eco.shadow.find_child("GunHold", true, false) == null \
		or eco.shadow.find_child("GunHold", true, false).is_queued_for_deletion(), null)

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


func _until_wallrun() -> void:
	for i in 60:
		await _ticks(1)
		if player.state_name() == "WALLRUN":
			return
	_check("reached a wallrun", false, player.state_name())


func _place(pos: Vector3, yaw: float) -> void:
	for a in ["move_forward", "crouch", "jump", "grapple"]:
		Input.action_release(a)
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
