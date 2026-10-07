extends SceneTree
## Squeezing through gaps off duty (player.gd pinch, stuck, squeeze, sidling):
## in a gap she turns side-on to a wall and shuffles through; a gap wider
## than her soft layer is a walk; a snug one pinches and drags on her but
## doesn't stop her; a spot that juts out into it (or a gap narrower than her
## core) gets her stuck, and mashing jump (wriggle) squeezes her past.
## Run: godot --headless --path . -s res://tests/squeeze_test.gd

const PLAYER := preload("res://scenes/player.tscn")
const WALK := Vector3(0, 0, -1.3)

var failures := 0
var player
var walls: Array[Node] = []


func _initialize() -> void:
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	player = PLAYER.instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.strolling = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await physics_frame

	var wide := await _walk(0.30, 3.0, false)
	var snug := await _walk(0.24, 5.0, false)
	print("after walking: 30 cm gap %.2f m in, 24 cm %.2f m (pinch %.2f, stuck %s)" % [wide[0], snug[0], snug[1], snug[2]])
	_check("a 30 cm gap is a walk", wide[0] > 2.0 and not wide[4], wide)
	_check("a 24 cm gap pinches and drags on her", snug[1] > 0.5 and snug[0] < wide[0] * 0.95, snug)
	_check("but doesn't stop her: she gets through", snug[0] > 2.0 and not snug[4], snug)
	_check("in it she turns side-on to the walls", snug[5], snug[5])

	var snagged := await _walk(0.27, 4.0, false, 0.06)
	print("27 cm gap with a 6 cm snag: %.2f m in, stuck %s" % [snagged[0], snagged[4]])
	_check("a snag jutting into the gap gets her stuck", snagged[4] and snagged[0] < 1.4, snagged)
	_check("stuck, the prompt to wriggle shows", player.stuck, player.stuck)
	var mashed := await _walk(0.27, 6.0, true, 0.06)
	print("mashing jump: %.2f m in after 6 s, squeeze up to %.2f" % [mashed[0], mashed[3]])
	_check("mashing, she wriggles past it", mashed[0] > 2.0, mashed)
	_check("wriggling squeezes her", mashed[3] > 0.2, mashed[3])

	var tight := await _walk(0.19, 3.0, false)
	_check("a gap narrower than her core gets her stuck too", tight[4] and tight[0] < 0.7, tight)
	var through := await _walk(0.19, 6.0, true)
	_check("and mashing gets her through it", through[0] > 2.0, through)
	# out of the gap she turns back to face where she's going
	for f in 40:
		player.soft_press(WALK)
		await physics_frame
	_check("clear of it, she stops sidling", not player.sidling, player.sidling)
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## Builds a gap `width` wide (its mouth 0.5 m ahead of her, 1.2 m long, a
## knob jutting `snag` m into it from the left halfway along), walks her into
## it for `seconds` (wriggling five times a second while stuck if `mash`):
## [how far she got, deepest pinch, unused, most squeeze, stuck once past the
## mouth and still stuck, ever side-on].
func _walk(width: float, seconds: float, mash: bool, snag := 0.0) -> Array:
	for w in walls:
		w.queue_free()
	walls.clear()
	for side in [-1.0, 1.0]:
		walls.append(_box(Vector3(side * (width * 0.5 + 0.45), 1.5, -1.1), Vector3(0.9, 3, 1.2)))
	if snag > 0.0:
		walls.append(_box(Vector3(-(width * 0.5 - snag * 0.5), 1.2, -1.1), Vector3(snag, 0.22, 0.16)))
	player.global_position = Vector3.ZERO
	player.rotation.y = 0.0
	player.squeeze = 0.0
	player.sidling = false
	player.wish_dir = Vector3(0, 0, -1)
	await physics_frame
	var deepest := 0.0
	var most := 0.0
	var side_on := false
	var frames := int(seconds * 60.0)
	for f in frames:
		if mash and f % 12 == 0 and player.stuck:
			player.wriggle()
		var v: Vector3 = player.soft_press(WALK)
		player.global_position += Vector3(v.x, 0, v.z) / 60.0
		deepest = maxf(deepest, player.pinch)
		most = maxf(most, player.squeeze)
		side_on = side_on or (player.sidling and absf(player.sidle_face.x) > 0.9)
		await physics_frame
	return [-player.global_position.z, deepest, 0, most, player.stuck, side_on]


func _box(at: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var box := CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	(box.shape as BoxShape3D).size = size
	wall.add_child(box)
	wall.position = at
	root.add_child(wall)
	return wall


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
