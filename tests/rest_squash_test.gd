extends SceneTree
## Sitting and lying, her soft parts rest on what holds her up (eco_model.gd
## _support_y): sitting or lying on her back her glutes flatten on the seat,
## face down her bust does, and nothing sinks below it. With jiggle_collide off
## they keep their shape. Getting up, they come back to normal.
## Run: godot --headless --path . -s res://tests/rest_squash_test.gd

const ECO := preload("res://assets/models/eco.tscn")
const SEAT := 0.5

var failures := 0


func _initialize() -> void:
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	for pose in ["sit", "back", "prone"]:
		var on := await _rest(pose, true)
		var off := await _rest(pose, false)
		var part := "bust" if pose == "prone" else "glute"
		print("%s: %s flat %.2f (off %.2f), lowest tip %.3f above the seat, after getting up %.2f" % [pose, part, on[part], off[part], on["lowest"], on["after"]])
		_check("%s: her %s flattens on the seat" % [pose, part], on[part] < 0.95, on[part])
		_check("%s: with collisions off it keeps its shape" % pose, off[part] > 0.999, off[part])
		_check("%s: nothing sinks into the seat" % pose, on["lowest"] > -0.005, on["lowest"])
		_check("%s: up again, back in shape" % pose, on["after"] > 0.99, on["after"])
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## Rests her in `pose` on a seat SEAT high: her flattest glute and bust
## scales there, the lowest soft part's centre over the seat, and her
## flattest scale a while after getting up.
func _rest(pose: String, collide: bool) -> Dictionary:
	var eco = ECO.instantiate()
	eco.jiggle_style = "classic"
	eco.idle_motion = false
	eco.jiggle_collide = collide
	eco.jiggle_squish = true
	root.add_child(eco)
	await _frames(10)
	eco.rest_seat_height = SEAT
	eco.rest_pose = pose
	await _frames(200)
	var sk: Skeleton3D = eco.skeleton
	var out := {
		"glute": minf(_flat(sk, "J_Sec_L_Glute1"), _flat(sk, "J_Sec_R_Glute1")),
		"bust": minf(_flat(sk, "J_Sec_L_Bust1"), _flat(sk, "J_Sec_R_Bust1")),
	}
	var lowest := INF
	for bone in ["J_Sec_L_Glute1", "J_Sec_R_Glute1", "J_Sec_L_Bust1", "J_Sec_R_Bust1"]:
		var at := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin
		lowest = minf(lowest, at.y - SEAT)
	out["lowest"] = lowest
	eco.rest_pose = ""
	await _frames(200)
	var after := 1.0
	for bone in ["J_Sec_L_Glute1", "J_Sec_R_Glute1", "J_Sec_L_Bust1", "J_Sec_R_Bust1"]:
		after = minf(after, _flat(sk, bone))
	out["after"] = after
	eco.queue_free()
	await process_frame
	return out


func _flat(sk: Skeleton3D, bone: String) -> float:
	var sc := sk.get_bone_pose_scale(sk.find_bone(bone))
	return minf(sc.x, minf(sc.y, sc.z))


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
