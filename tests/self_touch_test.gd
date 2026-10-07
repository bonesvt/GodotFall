extends SceneTree
## Eco's soft parts touch each other and her own body (eco_model.gd
## _touch_self): her right cheek pressed into her left pushes the left one
## out (and with jiggle_collide off it passes through); her hair, chest and
## glutes stay out of her body, limbs and each other while she runs and turns.
## Run: godot --headless --path . -s res://tests/self_touch_test.gd

const ECO := preload("res://assets/models/eco.tscn")

var failures := 0


func _initialize() -> void:
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	var on := await _cheeks(true)
	var off := await _cheeks(false)
	print("left cheek pushed out by the right: touch on %.1f mm, off %.1f mm" % [on, off])
	_check("her right cheek pressing in pushes her left one out", on > 4.0, on)
	_check("with contact off it passes through", off < 1.0, off)

	var eco = ECO.instantiate()
	eco.jiggle_style = "anime"
	root.add_child(eco)
	await process_frame
	eco.body_jiggle = true
	_check("hand bones are found for the forearms", _bodies(eco, "J_Sec_L_Bust1") == 3, _bodies(eco, "J_Sec_L_Bust1"))
	_check("hair keeps out of 5 body parts", _bodies(eco, "J_Sec_Hair1_01") == 5, _bodies(eco, "J_Sec_Hair1_01"))
	var pairs := 0
	for s in eco._springs:
		pairs += s.get("pairs", []).size()
	_check("all 10 soft pairs wired with full body jiggle", pairs == 10, pairs)

	# a hair tip shoved right into her chest comes back out of it
	var hair: Dictionary = _spring(eco, "J_Sec_Hair1_01")
	var chest: Vector3 = eco.skeleton.global_transform * eco.skeleton.get_bone_global_pose(eco.skeleton.find_bone("J_Bip_C_Chest")).origin
	var out: Vector3 = eco._touch_self(hair, chest, hair["target"])
	_check("hair pushed into her chest is put back outside it", out.distance_to(chest) > 0.09, out.distance_to(chest))

	# run, stop and spin with everything bouncing: worst overlap of parts and body
	var anim := eco.find_child("AnimationPlayer", true, false) as AnimationPlayer
	eco._anim = null
	anim.play("run")
	var worst := 0.0
	for f in 150:
		eco.position.z -= 6.0 / 60.0
		eco.rotation.y += 0.12 if f > 90 else 0.0
		if f == 60:
			eco.nudge(Vector3(0.05, 0.04, 0))
		await process_frame
		worst = maxf(worst, _worst_overlap(eco))
	print("worst overlap while running: %.1f mm" % (worst * 1000.0))
	_check("soft parts stay out of each other and her body (< 5 mm)", worst < 0.005, worst * 1000.0)
	eco.queue_free()

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## Stands her still, shoves her right cheek's tip 3 cm toward her left and
## returns how far (mm) her left cheek's tip then moves out to her left.
func _cheeks(touch: bool) -> float:
	var eco = ECO.instantiate()
	eco.jiggle_style = "classic"
	eco.idle_motion = false
	eco.jiggle_collide = touch
	root.add_child(eco)
	await _frames(30)
	var left := _spring(eco, "J_Sec_L_Glute1")
	var right := _spring(eco, "J_Sec_R_Glute1")
	var toward: Vector3 = ((left["target"] as Vector3) - (right["target"] as Vector3)).normalized()
	right["tip"] += toward * 0.03
	var most := 0.0
	for f in 20:
		await process_frame
		most = maxf(most, ((left["tip"] as Vector3) - (left["target"] as Vector3)).dot(toward) * 1000.0)
	eco.queue_free()
	await process_frame
	return most


## Deepest any soft part sits inside another (a pair) or inside her body
## beyond what her pose itself holds, in metres.
func _worst_overlap(eco) -> float:
	var worst := 0.0
	for s in eco._springs:
		var r: float = s.get("touch", 0.0)
		for pair: Array in s.get("pairs", []):
			var o: Dictionary = pair[0]
			var held: Vector3 = o["target"] - s["target"]
			var n := held.normalized()
			var closest: float = held.length() if pair[1] else minf(held.length(), r + float(o["touch"]))
			worst = maxf(worst, closest - ((o["tip"] as Vector3) - (s["tip"] as Vector3)).dot(n))
	return worst


func _bodies(eco, bone: String) -> int:
	return _spring(eco, bone).get("bodies", []).size()


func _spring(eco, bone: String) -> Dictionary:
	for s in eco._springs:
		if eco.skeleton.get_bone_name(s["bone"]) == bone:
			return s
	return {}


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
