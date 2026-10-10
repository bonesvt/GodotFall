extends SceneTree
## The fitting (fitting_scene.gd) moves smoothly: frame to frame its camera
## never jumps while the picture can be seen (a cut only happens under the
## white, or a white blink), the glide into the close-up and the crane back out
## ease in and out, the arm comes down without a jump, the partner's already
## sat when the white clears, and the hub comes back up out of the white rather
## than snapping in. Played alone (the cuff) and face to face with Mom (the visor).
##   godot --headless --path . --fixed-fps 60 -s res://tests/fitting_motion_test.gd
## (--fixed-fps keeps it exact; without it, moves are scaled by each frame's time)

const Hymn := preload("res://scripts/hub/hymn.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

## Most the camera may move or turn in one 60 fps frame while the picture shows.
## Each frame's move is scaled to a 60 fps frame by its real delta, so a run
## without --fixed-fps (or a slow frame) doesn't read as a jump.
const MAX_STEP := 0.05
const MAX_TURN := 3.0
const FRAME := 1.0 / 60.0
## Above this the white hides a cut.
const HIDDEN := 0.75

var run_node: Node
var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_fitting_motion_armory.cfg"
	run_node.npc_path = "user://test_fitting_motion_npcs.cfg"
	for f in ["user://test_fitting_motion_armory.cfg", "user://test_fitting_motion_npcs.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(60)
	run_node.hush_pull.triggers._next = INF
	Hymn.reset()
	Hymn.gear = ["headphones"]
	var fitting: Node = run_node.fitting_scene
	await _watch(fitting, "cuff", "", "")
	Hymn.gear = ["headphones", "cuff"]
	await _watch(fitting, "visor", "mom", "headphones")
	Hymn.reset()
	print("fitting_motion_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


## Plays the fitting of `piece` (with `with` getting `with_piece`) frame by
## frame at 60 fps and checks how everything moves.
func _watch(fitting: Node, piece: String, with: String, with_piece: String) -> void:
	var what := piece + (" with " + with if with != "" else "")
	fitting.play(piece, with, with_piece)
	await process_frame
	var last := Transform3D()
	var have := false
	var worst_step := 0.0
	var worst_turn := 0.0
	var worst_at := 0.0
	var cuts_hidden := true
	var arm_last := Vector3.INF
	var arm_jump := 0.0
	var sat_when_clear := -1.0
	var visor_peak := 0.0
	var visor_steps := 0
	var visor_was := 0.0
	var glide_speeds: Array = []
	var d_was := fitting.get_process_delta_time()
	while fitting.busy():
		await process_frame
		if not fitting.busy():
			break
		# moves per 60 fps frame; a stalled frame counts as at most three, so a real cut still shows.
		# process_frame fires before the nodes' _process, so what moved since the last
		# look was moved by the last frame's delta, not this one's
		var per := FRAME / clampf(d_was, FRAME * 0.25, FRAME * 3.0)
		d_was = fitting.get_process_delta_time()
		var cam: Camera3D = fitting._cam
		var veil: float = fitting._veil.color.a
		if cam != null:
			var xf := cam.global_transform
			if have:
				var step := xf.origin.distance_to(last.origin) * per
				var turn := rad_to_deg(last.basis.get_rotation_quaternion().angle_to(xf.basis.get_rotation_quaternion())) * per
				if veil < HIDDEN and (step > MAX_STEP or turn > MAX_TURN):
					cuts_hidden = false
				if veil < HIDDEN and step > worst_step:
					worst_step = step
					worst_at = fitting.t
				if veil < HIDDEN:
					worst_turn = maxf(worst_turn, turn)
				if fitting.t > fitting.ON - fitting.CAM_IN and fitting.t < fitting.ON:
					glide_speeds.append(step)
			last = xf
			have = true
		var clamp: Node3D = fitting._arm.get_node("Clamp") if fitting._arm != null else null
		if clamp != null and fitting.t > fitting.IN:
			if arm_last != Vector3.INF:
				arm_jump = maxf(arm_jump, clamp.global_position.distance_to(arm_last) * per)
			arm_last = clamp.global_position
		if sat_when_clear < 0.0 and veil < 0.5 and fitting._with_rest != null:
			sat_when_clear = fitting._with_rest.weight
		var v: float = fitting.visor_level
		visor_peak = maxf(visor_peak, v)
		if v > 0.02 and v < 0.98 and v != visor_was:
			visor_steps += 1
		visor_was = v
	_check("%s: the camera never jumps where it can be seen" % what, cuts_hidden, "worst %.3f m at %.2f s, %.1f deg" % [worst_step, worst_at, worst_turn])
	_check("%s: the arm comes down and goes up without a jump" % what, arm_jump < 0.08, arm_jump)
	if with == "":
		# eases in and out: slow at both ends of the glide, quicker in the middle
		var n := glide_speeds.size()
		var ok: bool = n > 20 and glide_speeds[2] < glide_speeds[n / 2] and glide_speeds[n - 3] < glide_speeds[n / 2]
		_check("%s: the glide to the close-up eases in and out" % what, ok, glide_speeds.slice(0, 3) + ["..."] + glide_speeds.slice(n / 2, n / 2 + 1) + ["..."] + glide_speeds.slice(n - 3))
	else:
		_check("%s: they're already sat when the white clears" % what, sat_when_clear >= 0.99, sat_when_clear)
	if piece == "visor":
		_check("%s: its orders fade up and down" % what, visor_peak > 0.99 and visor_steps > 6, [visor_peak, visor_steps])
	# back on the hub: out of the white, not snapped in (sampled by time, not frames)
	var veils: Array = []
	var since := 0.0
	for at in [1.0 / 60.0, 0.5, 1.15]:
		while since < at:
			await process_frame
			since += fitting.get_process_delta_time()
		veils.append(fitting._veil.color.a)
	_check("%s: the hub comes back out of the white" % what, veils[0] > 0.8 and veils[1] > 0.05 and veils[1] < veils[0] and veils[2] < 0.01, veils)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
