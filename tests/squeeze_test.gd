extends SceneTree
## Squeezing through gaps off duty (player.gd pinch, stuck, squeeze): a gap
## wider than her soft layer is a walk; a snug one pinches and drags on her;
## one narrower than her core gets her stuck, and mashing jump (wriggle)
## squeezes her through. Wriggling, her soft parts give more (eco_model.gd).
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
	var snug := await _walk(0.24, 3.0, false)
	var tight := await _walk(0.19, 3.0, false)
	print("after 3 s walking: 30 cm gap %.2f m in, 24 cm %.2f m (pinch %.2f), 19 cm %.2f m (stuck %s)" % [wide[0], snug[0], snug[1], tight[0], tight[2]])
	_check("a 30 cm gap is a walk", wide[0] > 2.0 and not wide[2], wide)
	_check("a 24 cm gap pinches and drags on her", snug[1] > 0.5 and snug[0] < wide[0] - 1.0, snug)
	_check("a 19 cm gap gets her stuck", tight[2] and tight[0] < 0.7, tight)
	_check("stuck, the prompt to wriggle shows", player.stuck, player.stuck)

	var mashed := await _walk(0.19, 6.0, true)
	print("mashing jump: 19 cm gap %.2f m in after 6 s, squeeze up to %.2f" % [mashed[0], mashed[3]])
	_check("mashing, she wriggles through", mashed[0] > 2.0, mashed)
	_check("wriggling squeezes her hard", mashed[3] > 0.6, mashed[3])
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## Builds a gap `width` wide (its mouth 0.5 m ahead of her, 1.2 m long), walks
## her into it for `seconds` (wriggling five times a second if `mash`):
## [how far she got past the start, deepest pinch, stuck at the end, most squeeze].
func _walk(width: float, seconds: float, mash: bool) -> Array:
	for w in walls:
		w.queue_free()
	walls.clear()
	for side in [-1.0, 1.0]:
		var wall := StaticBody3D.new()
		var box := CollisionShape3D.new()
		box.shape = BoxShape3D.new()
		(box.shape as BoxShape3D).size = Vector3(0.9, 3, 1.2)
		wall.add_child(box)
		wall.position = Vector3(side * (width * 0.5 + 0.45), 1.5, -1.1)
		root.add_child(wall)
		walls.append(wall)
	player.global_position = Vector3.ZERO
	player.squeeze = 0.0
	player.wish_dir = Vector3(0, 0, -1)
	await physics_frame
	var deepest := 0.0
	var most := 0.0
	var frames := int(seconds * 60.0)
	for f in frames:
		if mash and f % 12 == 0 and player.stuck:
			player.wriggle()
		var v: Vector3 = player.soft_press(WALK)
		player.global_position += Vector3(v.x, 0, v.z) / 60.0
		deepest = maxf(deepest, player.pinch)
		most = maxf(most, player.squeeze)
		await physics_frame
	return [-player.global_position.z, deepest, player.stuck, most]


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
