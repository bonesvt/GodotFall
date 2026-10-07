extends SceneTree
## Wind and water on Eco's soft parts (eco_model.gd _weather): wind (Weather
## and wind_zone boxes like the lab fan) streams her hair downwind; standing
## in water up to her chest, her chest floats up; with neither, they hang as
## they did.
## Run: godot --headless --path . -s res://tests/weather_test.gd

const ECO := preload("res://assets/models/eco.tscn")
const Weather := preload("res://scripts/game/weather.gd")
const LaidOut := preload("res://scripts/run/laid_out.gd")

var failures := 0


func _initialize() -> void:
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	var eco = ECO.instantiate()
	eco.idle_motion = false
	root.add_child(eco)
	await _frames(90)
	var hair_still := _tip("J_Sec_Hair1_01")
	var bust_still := _tip("J_Sec_L_Bust1")

	Weather.wind = Vector3(8, 0, 0)
	await _frames(120)
	var hair_blown := _tip("J_Sec_Hair1_01")
	Weather.wind = Vector3.ZERO
	print("hair tip moved %.3f m downwind (+x) in an 8 m/s wind" % (hair_blown.x - hair_still.x))
	_check("wind streams her hair downwind", hair_blown.x - hair_still.x > 0.02, hair_blown - hair_still)
	await _frames(120)
	_check("and it settles back when it drops", absf(_tip("J_Sec_Hair1_01").x - hair_still.x) < 0.01, _tip("J_Sec_Hair1_01") - hair_still)

	# a fan's wind_zone (as in the lab) does the same, only inside its box
	var fan := Node3D.new()
	fan.add_to_group("wind_zone")
	fan.set_meta("half", Vector3(1, 1, 1))
	fan.set_meta("wind", Vector3(0, 0, -8))
	fan.position = Vector3(0, 1, 0)
	root.add_child(fan)
	await _frames(120)
	var fanned := _tip("J_Sec_Hair1_01")
	_check("a fan blows her hair too", hair_still.z - fanned.z > 0.02, fanned - hair_still)
	fan.queue_free()
	await _frames(120)

	# water up to her chest
	var world := Node3D.new()
	root.add_child(world)
	var water := LaidOut.water(world, Vector3(0, 1.45, 0), Vector2(4, 4), Color(0.2, 0.5, 0.7, 0.4))
	await _frames(120)
	var bust_wet := _tip("J_Sec_L_Bust1")
	print("chest under water: bust bone end %.3f m higher" % (bust_wet.y - bust_still.y))
	_check("under water her chest floats up", bust_wet.y - bust_still.y > 0.004, bust_wet - bust_still)
	water.queue_free()
	await _frames(120)
	_check("out of it, it settles", absf(_tip("J_Sec_L_Bust1").y - bust_still.y) < 0.003, _tip("J_Sec_L_Bust1") - bust_still)
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## Where a spring bone's first child sits (its tip), in world space.
func _tip(bone: String) -> Vector3:
	var sk: Skeleton3D = _eco().skeleton
	var i := sk.find_bone(bone)
	var child := sk.get_bone_children(i)[0]
	return sk.global_transform * sk.get_bone_global_pose(child).origin


func _eco() -> Node:
	for c in root.get_children():
		if c.get("skeleton") != null:
			return c
	return null


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
