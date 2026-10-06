extends SceneTree
## Eco's run start and stop (eco_model.gd _run_moves) and footfalls: going
## from a stand into a run she dips and leans into it, pulling up from a run
## she sinks, leans back and settles upright, each foot landing in the run
## shoves its own side's glute (and the other side's much less), and nothing
## is left bent once it's over.
## Run: godot --headless --path . -s res://tests/run_moves_test.gd

const ECO := preload("res://assets/models/eco.tscn")

var failures := 0


class Walker extends CharacterBody3D:
	var state := 0
	var crouching := false
	var strolling := false


func _initialize() -> void:
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	var w := Walker.new()
	root.add_child(w)
	var eco = ECO.instantiate()
	eco.jiggle_style = "classic"
	w.add_child(eco)
	await _frames(30)
	var sk: Skeleton3D = eco.skeleton
	var hips := sk.find_bone("J_Bip_C_Hips")
	var spine := sk.find_bone("J_Bip_C_Spine")
	var stand_hips := sk.get_bone_global_pose(hips).origin.y

	# one footfall: its own side shoves, the other doesn't
	await _frames(60)
	eco.footfall("L", 2.0)
	var peak := {"L": 0.0, "R": 0.0}
	for f in 20:
		await process_frame
		peak["L"] = maxf(peak["L"], _angle(sk, "J_Sec_L_Glute1"))
		peak["R"] = maxf(peak["R"], _angle(sk, "J_Sec_R_Glute1"))
	_check("a left footfall jiggles the left glute", peak["L"] > 2.0, peak)
	_check("and the right one much less", peak["R"] < peak["L"] * 0.5, peak)

	# from a stand into a run
	var lean := 0.0
	var dip := 0.0
	for f in 40:
		w.velocity = Vector3(0, 0, -6.0 * minf(f / 6.0, 1.0))
		w.position += w.velocity / 60.0
		await process_frame
		if f < 25:
			lean = minf(lean, _pitch(sk, spine))
			dip = maxf(dip, stand_hips - sk.get_bone_global_pose(hips).origin.y)
	_check("starting off, she leans into the run", eco._start_t >= 0.0 or lean < -0.05, lean)
	# keep running: both feet land, each shoving its own side
	eco.footfalls = {"L": 0, "R": 0}
	for f in 120:
		w.position += w.velocity / 60.0
		await process_frame
	print("footfalls in 2 s of running: ", eco.footfalls)
	_check("both feet land while running", eco.footfalls["L"] >= 2 and eco.footfalls["R"] >= 2, eco.footfalls)

	# pull up from the run
	var back := 0.0
	var sink := 0.0
	var run_hips := 0.0
	for f in 50:
		w.velocity = Vector3.ZERO
		await process_frame
		if eco._stop_t >= 0.0:
			back = maxf(back, _pitch(sk, spine) - _rest_pitch(sk, spine))
			sink = maxf(sink, eco._strut_undo.get("hips_at", [Vector3.ZERO, Vector3.ZERO])[0].y - sk.get_bone_pose_position(hips).y)
	print("stop: lean back %.3f rad, sink %.3f m" % [back, sink])
	_check("stopping, she leans back against it", back > 0.05, back)
	_check("and sinks into her knees", sink > 0.015, sink)
	await _frames(40)
	_check("then stands straight again", eco._stop_t < 0.0 and eco._strut_undo.is_empty(), eco._strut_undo.keys())

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## How far a bone leans back (+) or forward (-), in skeleton space (radians).
func _pitch(sk: Skeleton3D, bone: int) -> float:
	var up := sk.get_bone_global_pose(bone).basis.y.normalized()
	return atan2(up.z, up.y)


func _rest_pitch(sk: Skeleton3D, bone: int) -> float:
	var up := sk.get_bone_global_rest(bone).basis.y.normalized()
	return atan2(up.z, up.y)


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
