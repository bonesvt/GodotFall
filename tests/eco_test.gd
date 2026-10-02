extends SceneTree
## Eco's model (assets/models/eco.tscn): her toon materials and expression come
## through the import, her spring bones are found, a hop makes her chest and
## glutes bounce and settle, and running at speed doesn't drag them back.
## Run: godot --headless --path . -s res://tests/eco_test.gd

const ECO := preload("res://assets/models/eco.tscn")

var failures := 0


func _initialize() -> void:
	Engine.max_fps = 60  # the springs step per frame, so run them at game speed
	_run.call_deferred()


func _run() -> void:
	var eco = ECO.instantiate()
	root.add_child(eco)
	await process_frame
	var sk: Skeleton3D = eco.skeleton
	_check("has a skeleton", sk != null, sk)
	_check("all 20 spring bones found", eco._springs.size() == 20, eco._springs.size())

	var wrong := []
	for mi in eco.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat == null or not (mat is ShaderMaterial) or not mat.resource_name.begins_with("eco_v_"):
				wrong.append("%s/%d" % [mi.name, i])
	_check("every surface wears an eco_v_ toon material", wrong.is_empty(), wrong)
	var face := eco.find_child("Face", true, false) as MeshInstance3D
	_check("fierce expression set", face != null and face.get_blend_shape_value(face.find_blend_shape_by_name("Fcl_BRW_Angry")) == 1.0, face)

	var anim := eco.find_child("AnimationPlayer", true, false) as AnimationPlayer
	eco._anim = null  # play her animations by hand (on her own she would only idle)
	for a in ["idle", "walk", "run", "fall", "crouch", "slide"]:
		_check("has %s animation" % a, anim.has_animation(a), a)

	# a hop: drop 25 cm and come back up; the jiggle bones swing, then settle
	anim.play("idle")
	await _frames(40)
	var peak := {"J_Sec_L_Bust1": 0.0, "J_Sec_L_Glute1": 0.0}
	for f in 30:
		if f < 6:
			eco.position.y = -0.25 * f / 6.0
		elif f < 9:
			eco.position.y = -0.25 + 0.25 * (f - 6) / 3.0
		await process_frame
		for b in peak:
			peak[b] = maxf(peak[b], _angle(sk, b))
	_check("chest bounces on a hop", peak["J_Sec_L_Bust1"] > 6.0, peak["J_Sec_L_Bust1"])
	_check("glutes bounce on a hop", peak["J_Sec_L_Glute1"] > 4.0, peak["J_Sec_L_Glute1"])
	_check("bounce stays within its limit", peak["J_Sec_L_Bust1"] <= 14.5 and peak["J_Sec_L_Glute1"] <= 10.5, peak)
	await _frames(90)
	_check("chest settles after the hop", _angle(sk, "J_Sec_L_Bust1") < 3.0, _angle(sk, "J_Sec_L_Bust1"))

	# running forward at 6 m/s: the jiggle bounces with her steps, not dragged back by her speed
	anim.play("run")
	var most := 0.0
	for f in 90:
		eco.position.z -= 6.0 / 60.0
		await process_frame
		if f > 30:
			most = maxf(most, _angle(sk, "J_Sec_L_Bust1"))
	_check("running bounces without slamming the limit", most > 3.0 and most < 12.0, most)

	# jiggle 0 holds them still
	eco.jiggle = 0.0
	eco.position = Vector3.ZERO
	await _frames(3)
	_check("jiggle 0 turns the bounce off", _angle(sk, "J_Sec_L_Bust1") < 0.2, _angle(sk, "J_Sec_L_Bust1"))

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## How far a bone has turned from its rest pose, in degrees.
func _angle(sk: Skeleton3D, bone: String) -> float:
	var i := sk.find_bone(bone)
	var q := sk.get_bone_pose_rotation(i)
	return rad_to_deg((sk.get_bone_rest(i).basis.get_rotation_quaternion().inverse() * q).get_angle())


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
