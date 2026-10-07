extends SceneTree
## Hits and blasts jolt Eco's soft parts (eco_model.gd jolt): taking damage
## flings them away from the hit and they wobble back; a blast's shock wave
## does it from nearby (fx.gd blast -> blast_at), harder the closer it is,
## and not at all from far away.
## Run: godot --headless --path . -s res://tests/jolt_test.gd

const PLAYER := preload("res://scenes/player.tscn")
const FX := preload("res://scripts/fx.gd")

var failures := 0
var eco


func _initialize() -> void:
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	var player = PLAYER.instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	eco = player.get_node("EcoBody").shadow
	for f in 60:
		await process_frame
	var calm := await _swing()

	player.take_damage(20.0, player.global_position + Vector3(0, 1, -3))
	var hit := await _swing()
	print("most swing over half a second: calm %.1f deg, after a hit %.1f deg" % [calm, hit])
	_check("a hit jolts her", eco.jolts == 1 and hit > calm + 4.0, [eco.jolts, calm, hit])
	await _frames(120)
	var settled := await _swing()
	_check("and it settles again", settled < calm + 1.0, settled)

	FX.blast(root, player.global_position + Vector3(0, 0, -2.5), Color.ORANGE, 2.0)
	var near := await _swing()
	await _frames(120)
	FX.blast(root, player.global_position + Vector3(0, 0, -40.0), Color.ORANGE, 2.0)
	var far := await _swing()
	print("a blast 2.5 m away: %.1f deg; 40 m away: %.1f deg" % [near, far])
	_check("a blast nearby jolts her", near > calm + 4.0, near)
	_check("one far off doesn't", eco.jolts == 2 and far < calm + 1.0, [eco.jolts, far])
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## The most her chest and glutes swing from rest over the next half second.
func _swing() -> float:
	var sk: Skeleton3D = eco.skeleton
	var most := 0.0
	for f in 30:
		await process_frame
		for bone in ["J_Sec_L_Bust1", "J_Sec_R_Bust1", "J_Sec_L_Glute1", "J_Sec_R_Glute1"]:
			var i := sk.find_bone(bone)
			var q := sk.get_bone_pose_rotation(i)
			most = maxf(most, rad_to_deg(q.angle_to(sk.get_bone_rest(i).basis.get_rotation_quaternion())))
	return most


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
