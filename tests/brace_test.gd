extends SceneTree
## Held at full press, Eco braces (player.gd brace, eco_model.gd _brace_layer):
## into a wall in front of her both hands come up flat on it and her head
## turns aside; into a wall at her side only the near hand goes up. Turning
## away she pushes herself off it. Facing away from it, she doesn't brace.
## Run: godot --headless --path . -s res://tests/brace_test.gd

const PLAYER := preload("res://scenes/player.tscn")

var failures := 0
var player
var eco


func _initialize() -> void:
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	# a wall with its face at z = -1
	var wall := StaticBody3D.new()
	var box := CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	(box.shape as BoxShape3D).size = Vector3(4, 3, 1)
	wall.add_child(box)
	wall.position = Vector3(0, 1.5, -1.5)
	root.add_child(wall)
	player = PLAYER.instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.strolling = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	eco = player.get_node("EcoBody").shadow
	await physics_frame
	for f in 30:
		await process_frame
	var down: float = maxf(_hands()[1][0], _hands()[1][1]) + 0.05

	var hands := await _push(0.0)
	print("facing the wall: brace %.2f, hands %s m off it, at heights %s" % [player.brace, hands[0], hands[1]])
	_check("held at full press she braces", player.brace > 0.99, player.brace)
	_check("both hands up flat on the wall, not through it", hands[0][0] < 0.08 and hands[0][1] < 0.08 and hands[0][0] > 0.0 and hands[0][1] > 0.0, hands[0])
	_check("at about shoulder height", hands[1][0] > 1.1 and hands[1][0] < 1.6 and hands[1][1] > 1.1 and hands[1][1] < 1.6, hands[1])
	var head: int = eco.skeleton.find_bone("J_Bip_C_Head")
	var look: Vector3 = eco.skeleton.global_transform.basis * eco.skeleton.get_bone_global_pose(head).basis * Vector3.FORWARD
	_check("her head turned aside", absf(look.x) > 0.4, look)

	player.wish_dir = Vector3(0, 0, 1)
	var off: Vector3 = player.soft_press(Vector3(0, 0, 1.9))
	_check("turning away she pushes off the wall", off.z > 1.9 + 1.2, off)
	_check("and lets go of it", player.brace == 0.0, player.brace)
	for f in 60:
		player.soft_press(Vector3.ZERO)
		await process_frame
	hands = _hands()
	_check("hands back down a second later", hands[1][0] < down and hands[1][1] < down, hands[1])

	# the wall at her right: only her right hand
	hands = await _push(PI / 2.0)
	print("wall at her right: hands %s m off it, at heights %s" % [hands[0], hands[1]])
	_check("the near hand goes up on it", hands[0][0] < 0.08 and hands[0][0] > 0.0 and hands[1][0] > down + 0.15, hands)
	_check("the far hand stays down", hands[1][1] < down, hands[1])

	# backed into it: that's a lean, not a brace
	hands = await _push(PI)
	_check("backed into a wall her hands stay down", hands[1][0] < down and hands[1][1] < down, hands[1])

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## Stands her at her core off the wall, turned `yaw`, and pushes into it for a
## second: [her hands' distances off the wall, their heights] (right, left).
func _push(yaw: float) -> Array:
	player.brace = 0.0
	player.rotation.y = yaw
	player.global_position = Vector3(0, 0, -1.0 + 0.112)
	player.wish_dir = Vector3(0, 0, -1)
	await physics_frame
	for f in 60:
		var v: Vector3 = player.soft_press(Vector3(0, 0, -1.9))
		player.global_position += v / 60.0
		await process_frame
	await process_frame
	return _hands()


func _hands() -> Array:
	var sk: Skeleton3D = eco.skeleton
	var off := []
	var height := []
	for bone in ["J_Bip_R_Hand", "J_Bip_L_Hand"]:
		var at := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin
		off.append(snappedf(at.z + 1.0, 0.001))
		height.append(snappedf(at.y, 0.001))
	return [off, height]


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
