extends SceneTree
## Full body jiggle (scripts/ps2/eco_flesh.gd, Settings > Game): off by default
## and then Eco is untouched; on, her stomach, thighs, upper arms and calves
## get soft bones with skin weighted to them where they should be, the springs
## ripple on a hop and settle, and turning it off puts her meshes back.
## Run: godot --headless --path . -s res://tests/body_jiggle_test.gd

const ECO := preload("res://assets/models/eco.tscn")
const Prefs := preload("res://scripts/game/prefs.gd")
const EcoFlesh := preload("res://scripts/ps2/eco_flesh.gd")
const TEST_SETTINGS := "user://test_body_jiggle_settings.cfg"

var failures := 0


func _initialize() -> void:
	Engine.max_fps = 60
	Prefs.path = TEST_SETTINGS
	DirAccess.remove_absolute(TEST_SETTINGS)
	_run.call_deferred()


func _run() -> void:
	var eco = ECO.instantiate()
	root.add_child(eco)
	await process_frame
	var sk: Skeleton3D = eco.skeleton
	var body := eco.find_child("Body", true, false) as MeshInstance3D
	var bare_mesh := body.mesh
	var bare_bones := sk.get_bone_count()
	_check("off by default", not Prefs.body_jiggle() and not eco.body_jiggle, eco.body_jiggle)
	_check("off: no extra bones", sk.find_bone("J_Sec_C_Belly") < 0, sk.get_bone_count())
	_check("off: 26 springs as before", eco._springs.size() == 26, eco._springs.size())

	var t0 := Time.get_ticks_msec()
	eco.body_jiggle = true
	print("reweighting took %d ms" % (Time.get_ticks_msec() - t0))
	_check("on: 7 soft bones added", sk.get_bone_count() == bare_bones + 7, sk.get_bone_count())
	_check("on: 33 springs", eco._springs.size() == 33, eco._springs.size())
	_check("on: her body mesh is the reweighted one", body.mesh != bare_mesh, body.mesh)

	# where the weight went (in skeleton space: +Z is her back, -Z her front)
	var at := _weighted(body, sk)
	var hips_y := sk.get_bone_global_rest(sk.find_bone("J_Bip_C_Hips")).origin.y
	var knee_y := sk.get_bone_global_rest(sk.find_bone("J_Bip_L_LowerLeg")).origin.y
	for n: String in EcoFlesh.bone_names():
		_check("%s has skin on it" % n, at.get(n, []).size() > 20, at.get(n, []).size())
	_check("belly weight is on her front", _all(at.get("J_Sec_C_Belly", []), func(p: Vector3) -> bool: return p.z < 0.02), _range(at.get("J_Sec_C_Belly", [])))
	_check("belly weight stays below her chest", _all(at.get("J_Sec_C_Belly", []), func(p: Vector3) -> bool: return p.y < 1.2), _range(at.get("J_Sec_C_Belly", [])))
	_check("thigh weight is between hip and knee", _all(at.get("J_Sec_L_Thigh", []), func(p: Vector3) -> bool: return p.y < hips_y and p.y > knee_y - 0.03), _range(at.get("J_Sec_L_Thigh", [])))
	_check("calf weight is below the knee", _all(at.get("J_Sec_L_Calf", []), func(p: Vector3) -> bool: return p.y < knee_y + 0.03), _range(at.get("J_Sec_L_Calf", [])))
	_check("weights still add up to 1", _sums_ok(body), "")

	# a hop: they ripple a few degrees and settle
	var anim := eco.find_child("AnimationPlayer", true, false) as AnimationPlayer
	eco._anim = null
	anim.play("idle")
	await _frames(40)
	var names := ["J_Sec_C_Belly", "J_Sec_L_Thigh", "J_Sec_L_Calf", "J_Sec_L_UpperArmSoft"]
	var peak := {}
	for n in names:
		peak[n] = 0.0
	for f in 30:
		if f < 6:
			eco.position.y = -0.25 * f / 6.0
		elif f < 9:
			eco.position.y = -0.25 + 0.25 * (f - 6) / 3.0
		await process_frame
		for n in names:
			peak[n] = maxf(peak[n], _slid(sk, n))
	print("hop peaks (mm): ", peak)
	for n in names:
		_check("%s moves on a hop" % n, peak[n] > 2.0, peak[n])
	_check("stomach stays within its reach", peak["J_Sec_C_Belly"] <= EcoFlesh.BELLY["reach"] * 1000.0 + 0.1, peak)
	_check("calves move less than thighs", peak["J_Sec_L_Calf"] < peak["J_Sec_L_Thigh"], peak)
	await _frames(90)
	var still := 0.0
	for n in names:
		still = maxf(still, _slid(sk, n))
	_check("settles after the hop", still < 1.0, still)

	# running doesn't pin them at their limits
	anim.play("run")
	var run_most := 0.0
	for f in 90:
		eco.position.z -= 6.0 / 60.0
		await process_frame
		if f > 30:
			run_most = maxf(run_most, _slid(sk, "J_Sec_L_Thigh"))
	print("thigh while running: %.1f mm" % run_most)
	_check("thighs ripple while running", run_most > 2.0, run_most)

	eco.body_jiggle = false
	_check("off again: her own mesh is back", body.mesh == bare_mesh, body.mesh)
	_check("off again: 26 springs", eco._springs.size() == 26, eco._springs.size())
	eco.body_jiggle = true
	_check("back on: no second set of bones", sk.get_bone_count() == bare_bones + 7, sk.get_bone_count())
	eco.queue_free()

	# a copy left to the settings follows the toggle live
	var follower = ECO.instantiate()
	root.add_child(follower)
	await process_frame
	Prefs.set_body_jiggle(true)
	_check("turning the setting on changes her at once", follower.body_jiggle and follower._springs.size() == 33, follower._springs.size())
	Prefs.set_body_jiggle(false)
	_check("and off", not follower.body_jiggle and follower._springs.size() == 26, follower._springs.size())
	follower.queue_free()
	DirAccess.remove_absolute(TEST_SETTINGS)

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## Rest positions (skeleton space) of the vertices with over 10% weight on
## each soft bone, by bone name.
func _weighted(mi: MeshInstance3D, sk: Skeleton3D) -> Dictionary:
	var out := {}
	var to_sk := sk.global_transform.affine_inverse() * mi.global_transform
	for s in mi.mesh.get_surface_count():
		var arrays: Array = mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / verts.size()
		for i in bones.size():
			if weights[i] > 0.1:
				var n := String(mi.skin.get_bind_name(bones[i]))
				if n.begins_with("J_Sec_") and n in EcoFlesh.bone_names():
					if not out.has(n):
						out[n] = []
					out[n].append(to_sk * verts[i / per])
	return out


func _sums_ok(mi: MeshInstance3D) -> bool:
	for s in mi.mesh.get_surface_count():
		var arrays: Array = mi.mesh.surface_get_arrays(s)
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := weights.size() / (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		for v in range(0, weights.size(), per):
			var sum := 0.0
			for k in per:
				sum += weights[v + k]
			if absf(sum - 1.0) > 0.01:
				print("  weight sum %.3f at vertex %d" % [sum, v / per])
				return false
	return true


func _all(points: Array, ok: Callable) -> bool:
	return not points.is_empty() and points.all(ok)


func _range(points: Array) -> String:
	if points.is_empty():
		return "none"
	var lo: Vector3 = points[0]
	var hi: Vector3 = points[0]
	for p: Vector3 in points:
		lo = lo.min(p)
		hi = hi.max(p)
	return "%s..%s" % [lo, hi]


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## How far a soft bone has slid off its rest, in millimetres.
func _slid(sk: Skeleton3D, bone: String) -> float:
	var i := sk.find_bone(bone)
	return sk.get_bone_pose_position(i).distance_to(sk.get_bone_rest(i).origin) * 1000.0


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
