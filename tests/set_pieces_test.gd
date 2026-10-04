extends SceneTree
## Headless test for the generated zones' set pieces (scripts/run/procgen/set_pieces.gd).
## Run: godot --headless --path . -s res://tests/set_pieces_test.gd
## Every model loads and gets its colliders; then the pilot (the real player
## controller, driven by its inputs) kicks up a kick slot onto its deck, runs
## the length of a long billboard, and grapples a mast's hook.

const SetPieces := preload("res://scripts/run/procgen/set_pieces.gd")
const Shapes := preload("res://scripts/run/procgen/prop_shapes.gd")
const Kit := preload("res://scripts/run/level_kit.gd")

var failures := 0
var world: Node3D
var player


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	Kit.box(world, Vector3(0, -0.5, 0), Vector3(400, 1, 400), Color(0.5, 0.5, 0.5))
	_every_piece()
	player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	await _ticks(10)
	await _kick_slot()
	await _billboard()
	await _grapple_mast()
	await _corner_kick()
	await _pillar_ledge()
	await _roost()
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## Every model, out of the way along x = 120: it loads, gets a body per
## collider, and its hooks and tops come back turned with it.
func _every_piece() -> void:
	var bad := []
	var z := -150.0
	for id in Shapes.SHAPES:
		var before := world.get_child_count()
		var placed := SetPieces.place(world, id, Vector3(120, 0, z), 90.0)
		var shape: Dictionary = Shapes.SHAPES[id]
		var added := world.get_child_count() - before
		if placed["node"] == null or added != 1 + shape["boxes"].size() + shape["columns"].size():
			bad.append([id, added])
		if placed["hooks"].size() != shape["hooks"].size():
			bad.append([id, "hooks"])
		for h in placed["hooks"]:
			if absf((h as Vector3).x - 120.0) > 16.0:
				bad.append([id, "hook turned wrong", h])
		z += 12.0
	_check("%d set pieces load with their colliders" % Shapes.SHAPES.size(), bad.is_empty(), bad)


## Run in along the slot, jump onto a wall, and kick from wall to wall
## until you're stood on the deck past its far end.
func _kick_slot() -> void:
	var at := Vector3(0, 0, 0)
	SetPieces.place(world, "kick_slot", at, 0.0)
	var deck_y: float = Shapes.SHAPES["kick_slot"]["tops"][0].y
	_place(Vector3(0.9, 0.1, 13.0), 0.0)
	Input.action_press("move_forward")
	await _ticks(50)
	await _press("jump")
	player.velocity.x = 3.0
	var best := 0.0
	var walls := 0
	var was := ""
	for i in 300:
		await physics_frame
		var s: String = player.state_name()
		if s == "WALLRUN" and was != "WALLRUN":
			walls += 1
		was = s
		if OS.has_environment("DBG") and i % 6 == 0:
			print(i, " ", s, " ", player.global_position, " ", player.velocity, " wall=", player.is_on_wall())
		best = maxf(best, player.global_position.y)
		if s == "WALLRUN" and player.wallrun_timer > 0.12:
			await _press("jump")
		elif s == "AIR" and player.velocity.y < -0.5 and player.air_jumps_left > 0 and player.global_position.y > deck_y - 1.8:
			# The last boost: a double jump over the lip once you're near the top.
			await _press("jump")
		if player.is_on_floor() and player.global_position.y > deck_y - 0.3:
			break
	var on_deck: bool = player.is_on_floor() and player.global_position.y > deck_y - 0.3
	_check("kick slot: wall to wall (%d walls) up to the deck at %.1f m (best %.1f)" % [walls, deck_y, best], on_deck and walls >= 2, player.global_position)


## A long billboard beside a road: jump onto it and run its length.
func _billboard() -> void:
	SetPieces.place(world, "billboard_l", Vector3(-30, 0, 0), 90.0)
	_place(Vector3(-28.6, 0.1, 12.0), 0.0)
	Input.action_press("move_forward")
	await _ticks(40)
	await _press("jump")
	player.velocity.x = -3.0
	var start_z := INF
	var end_z := INF
	for i in 200:
		await physics_frame
		if OS.has_environment("DBG") and i % 5 == 0:
			print(i, " ", player.state_name(), " ", player.global_position, " ", player.velocity, " wall=", player.is_on_wall())
		if player.state_name() == "WALLRUN":
			if start_z == INF:
				start_z = player.global_position.z
			end_z = player.global_position.z
		elif start_z != INF:
			break
	var ran := start_z - end_z if start_z != INF else 0.0
	_check("billboard: wallrun along it (%.1f m of 16)" % ran, ran > 11.0, [start_z, end_z])


## Look at a mast's hook from 16 m off and grapple it.
func _grapple_mast() -> void:
	var placed := SetPieces.place(world, "grapple_mast", Vector3(40, 0, 0), 0.0)
	var hook: Vector3 = placed["hooks"][0]
	_place(Vector3(40, 0.1, 16.0), 0.0)
	await _ticks(10)
	var eye: Vector3 = player.camera.global_position
	var to := hook - eye
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	Input.action_press("grapple")
	await _ticks(3)
	var hooked: bool = player.state_name() == "GRAPPLE" and player.grapple_point.distance_to(hook) < 1.5
	var closest := 99.0
	for i in 120:
		await physics_frame
		closest = minf(closest, (player.global_position + Vector3.UP).distance_to(hook))
	Input.action_release("grapple")
	_check("grapple mast: hook caught and pulled in (%.1f m)" % closest, hooked and closest < 4.0, player.grapple_point)


## Wallrun the corner's inside wall into the corner, kick off it, and double
## jump over onto the deck in the corner.
func _corner_kick() -> void:
	var at := Vector3(0, 0, 60)
	SetPieces.place(world, "corner_kick", at, 0.0)
	var top: Vector3 = at + Shapes.SHAPES["corner_kick"]["tops"][0]
	_place(at + Vector3(2.4, 0.1, 11.0), 0.0)
	var r := await _climb(top, 3.0)
	_check("corner kick: wallrun, kick, onto the deck at %.1f m (best %.1f)" % [top.y, r[1]], r[0], player.global_position)


## Hop onto the squat pillar, then from it up onto the block.
func _pillar_ledge() -> void:
	var at := Vector3(30, 0, 60)
	SetPieces.place(world, "pillar_ledge", at, 0.0)
	var top: Vector3 = at + Shapes.SHAPES["pillar_ledge"]["tops"][0]
	_place(at + Vector3(0, 0.1, 9.0), 0.0)
	var r := await _climb(top, 0.0)
	_check("pillar ledge: pillar, then onto the block at %.1f m (best %.1f)" % [top.y, r[1]], r[0], player.global_position)


## Hold forward and jump at every chance: off the floor once moving (and off
## anything stood on below the top), wall jumps, and the double jump on the
## way down. Returns [stood on top, best height].
func _climb(top: Vector3, side_push: float) -> Array:
	Input.action_press("move_forward")
	await _ticks(25)
	var best := 0.0
	var start_y: float = player.global_position.y
	for i in 300:
		await physics_frame
		var s: String = player.state_name()
		var y: float = player.global_position.y
		if OS.has_environment("DBG") and i % 6 == 0:
			print(i, " ", s, " ", player.global_position, " ", player.velocity, " wall=", player.is_on_wall())
		best = maxf(best, y)
		if player.is_on_floor() and y > top.y - 0.3:
			break
		if player.is_on_floor():
			if player.global_position.z - top.z < 6.0 or y > start_y + 0.5:
				await _press("jump")
				if side_push != 0.0:
					player.velocity.x = side_push
		elif s == "WALLRUN" and player.wallrun_timer > 0.12:
			await _press("jump")
		elif s == "AIR" and player.velocity.y < -0.5 and player.air_jumps_left > 0:
			await _press("jump")
		if y < start_y - 0.5 and i > 30:
			break
	Input.action_release("move_forward")
	var ok: bool = player.is_on_floor() and player.global_position.y > top.y - 0.3
	return [ok, best]


## Grapple the roost's hook from the ground and drop onto its deck.
func _roost() -> void:
	var at := Vector3(60, 0, 60)
	var placed := SetPieces.place(world, "scaffold_roost", at, 0.0)
	var hook: Vector3 = placed["hooks"][0]
	var top: Vector3 = placed["tops"][0]
	_place(at + Vector3(0, 0.1, 14.0), 0.0)
	await _ticks(10)
	var to: Vector3 = hook - player.camera.global_position
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	Input.action_press("grapple")
	var landed := false
	for i in 240:
		await physics_frame
		if OS.has_environment("DBG") and i % 6 == 0:
			print(i, " ", player.state_name(), " ", player.global_position, " ", player.velocity)
		var p: Vector3 = player.global_position
		if Input.is_action_pressed("grapple") and absf(p.z - top.z) < 1.0 and p.y > top.y:
			Input.action_release("grapple")
		if player.is_on_floor() and p.y > top.y - 0.3:
			landed = true
			break
	Input.action_release("grapple")
	_check("scaffold roost: grapple the hook and land on the deck at %.1f m" % top.y, landed, player.global_position)


func _place(pos: Vector3, yaw: float) -> void:
	for a in ["move_forward", "crouch", "jump", "grapple"]:
		Input.action_release(a)
	player.global_position = pos
	player.rotation.y = yaw
	player.get_node("Head").rotation.x = 0.0
	player.velocity = Vector3.ZERO
	player.state = player.State.AIR


func _press(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
