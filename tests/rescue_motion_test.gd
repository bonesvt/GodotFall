extends SceneTree
## The rescue scenes move like film, not slides (rescue_event.gd): Biggie's
## alert, the knockdown in time, and a too-late scene played frame by frame.
## Wherever it can be seen (the screen not black or white):
##   the view never jumps (it glides; cuts only happen in the dark)
##   it never lurches (no sudden starts: its speed changes a little a frame)
##   nobody teleports (Biggie, them, the captor, Eco: a stride a frame at most)
## and coming out of each scene into her own view doesn't jump either.
##   godot --headless --path . -s res://tests/rescue_motion_test.gd

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const Redline := preload("res://scripts/hub/redline.gd")
const Rescue := preload("res://scripts/hub/rescue.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const ViceLooks := preload("res://scripts/hub/vice_looks.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

## The fastest the view may move (m/s) or turn (degrees/s) where it's seen,
## and the hardest it may speed up or slow down (m/s each second): a frame's
## worth of each, at the frame's own length.
const CAM_SPEED := 12.0
const CAM_TURN := 300.0
const CAM_ACCEL := 60.0
## The fastest anyone may move where they're seen (m/s): no teleports.
const BODY_SPEED := 12.0
const DT := 1.0 / 60.0

var run_node: Node
var ev: Node
var failures := 0
var worst := {}


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_rescue_motion_armory.cfg"
	run_node.npc_path = "user://test_rescue_motion_npc.cfg"
	for f in ["user://test_rescue_motion_armory.cfg", "user://test_rescue_motion_npc.cfg", "user://test_rescue_motion_armory_vices.cfg",
			"user://test_rescue_motion_armory_rescue.cfg", "user://test_rescue_motion_armory_hub_grip.cfg", "user://test_rescue_motion_armory_looks.cfg",
			"user://test_rescue_motion_armory_redline.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _frames(60)
	ev = run_node.rescue_event
	run_node.hush_pull.triggers._next = INF
	Vices.reset()
	Hymn.reset()
	Redline.reset()
	Rescue.reset()
	HubGrip.reset()
	ViceLooks.reset()
	Vices.hold = 10.0
	Redline.catches = 1
	var p: Node3D = run_node.player
	run_node.place_player(Vector3(1.5, 0.1, 141.0))
	await _frames(20)

	# Biggie runs in, says it, runs off; the view back to hers
	ev.start("mom", "marrow")
	await _watch("the alert", func(): return ev.running(), 12.0)
	_check("the alert: no hard cuts where it's seen", ev.cuts == 0, ev.cuts)
	_check("Biggie jogs in and slows to a stop (he moved, and he's stood)", worst.get("biggie_moved", 0.0) > 3.0, worst.get("biggie_moved"))

	# in time: she runs at him, he goes down, Mom comes over to her
	var at: Vector3 = ev._site["captor"]
	run_node.place_player(at + Vector3(1.2, 0.1, -2.6))
	await _frames(10)
	var from: Vector3 = p.global_position
	ev.knock()
	await _watch("in time", func(): return not ev.busy() and ev._fade_up < 0.0, 14.0)
	_check("in time: no hard cuts where it's seen", ev.cuts == 0, ev.cuts)
	_check("she ran at him herself (no teleport to him)", worst.get("eco_ran", 0.0) > 1.0, worst.get("eco_ran"))

	# too late: Cutter, his needle, her eyes
	ev.start("mom", "cutter")
	await _watch("Cutter's alert", func(): return ev.running(), 12.0)
	ev.left = 0.05
	await _watch("too late", func(): return ev.step == ev.Step.IDLE and not ev.busy() and ev._fade_up < 0.0, 18.0)
	_check("too late: no hard cuts where it's seen", ev.cuts == 0, ev.cuts)
	_check("Cutter walked in to her, and back", worst.get("captor_moved", 0.0) > 1.0, worst.get("captor_moved"))

	for k in worst:
		print("  worst %s: %s" % [k, str(worst[k])])
	Vices.reset()
	Hymn.reset()
	Redline.reset()
	Rescue.reset()
	Rescue.save()
	HubGrip.reset()
	HubGrip.save()
	ViceLooks.reset()
	ViceLooks.save()
	print("rescue_motion_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


## Steps frames at a steady DT until `done`, checking every frame what can be seen.
func _watch(what: String, done: Callable, seconds: float) -> void:
	Engine.max_fps = 60
	var cam := root.get_viewport().get_camera_3d()
	var last_pos: Vector3 = cam.global_position
	var last_fwd: Vector3 = -cam.global_basis.z
	var last_v := 0.0
	var bodies := {}
	var cam_fail := ""
	var body_fail := ""
	var frames := int(seconds / DT)
	var prev_dt := DT
	while frames > 0 and not done.call():
		await process_frame
		frames -= 1
		# (process_frame comes before this frame's _process: what we see is the last
		# frame's doing, over the last frame's delta)
		var dt: float = maxf(prev_dt, 0.001)
		prev_dt = ev.get_process_delta_time()
		cam = root.get_viewport().get_camera_3d()
		var veil: float = ev._veil.color.a
		var seen := veil < 0.9
		var pos: Vector3 = cam.global_position
		var fwd: Vector3 = -cam.global_basis.z
		var step := pos.distance_to(last_pos)
		var turn := rad_to_deg(fwd.angle_to(last_fwd))
		var v := step / dt
		if seen:
			worst["cam_step"] = maxf(worst.get("cam_step", 0.0), step)
			worst["cam_turn_per_s"] = maxf(worst.get("cam_turn_per_s", 0.0), turn / dt)
			worst["cam_speed"] = maxf(worst.get("cam_speed", 0.0), v)
			worst["cam_accel"] = maxf(worst.get("cam_accel", 0.0), absf(v - last_v) / dt)
			if cam_fail == "" and (step > CAM_SPEED * dt or turn > CAM_TURN * dt):
				cam_fail = "%s: the view jumped %.2f m / %.1f deg at t=%.2f" % [what, step, turn, ev.t]
			if cam_fail == "" and absf(v - last_v) > CAM_ACCEL * dt:
				cam_fail = "%s: the view lurched (%.1f -> %.1f m/s) at t=%.2f" % [what, last_v, v, ev.t]
		last_pos = pos
		last_fwd = fwd
		last_v = v if seen else 0.0
		# everyone it shows
		var dtb: float = dt
		var people := {"biggie": ev._biggie, "victim": ev._victim, "captor": ev._captor, "eco": run_node.player}
		for k in people:
			var n = people[k]
			if n == null or not is_instance_valid(n) or not (n as Node3D).is_visible_in_tree():
				bodies.erase(k)
				continue
			var at: Vector3 = (n as Node3D).global_position
			if bodies.has(k) and seen:
				var moved: float = at.distance_to(bodies[k][0])
				var total: float = bodies[k][1] + moved
				bodies[k] = [at, total]
				worst[k + "_step"] = maxf(worst.get(k + "_step", 0.0), moved)
				if k == "biggie":
					worst["biggie_moved"] = maxf(worst.get("biggie_moved", 0.0), total)
				if k == "eco" and ev.step == ev.Step.SAVED:
					worst["eco_ran"] = maxf(worst.get("eco_ran", 0.0), total)
				if k == "captor" and ev.step == ev.Step.LATE:
					worst["captor_moved"] = maxf(worst.get("captor_moved", 0.0), total)
				if body_fail == "" and moved > BODY_SPEED * dt:
					body_fail = "%s: %s jumped %.2f m at t=%.2f" % [what, k, moved, ev.t]
			else:
				bodies[k] = [at, bodies[k][1] if bodies.has(k) else 0.0]
	_check(what + ": the view moves smoothly", cam_fail == "", cam_fail)
	_check(what + ": nobody teleports where it's seen", body_fail == "", body_fail)
	_check(what + ": done", done.call(), ev.step)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
