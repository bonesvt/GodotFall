extends SceneTree
## Headless test for the city and military kits (tools/procgen/build_kits.py,
## placed by scripts/run/procgen/set_pieces.gd).
## Run: godot --headless --path . -s res://tests/city_military_test.gd
## Every model loads with its colliders and its neon lit; the pilot (the real
## player controller, driven by its inputs) runs the length of every wall made
## to wallrun and grapples every hook; then a city zone and a base are
## generated and dressed from their own kits.

const SetPieces := preload("res://scripts/run/procgen/set_pieces.gd")
const KitShapes := preload("res://scripts/run/procgen/kit_shapes.gd")
const LevelPlan := preload("res://scripts/run/procgen/level_plan.gd")
const ZoneGenerator := preload("res://scripts/run/procgen/zone_generator.gd")
const B := preload("res://scripts/run/procgen/biome.gd")
const Kit := preload("res://scripts/run/level_kit.gd")

var failures := 0
var world: Node3D
var player


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	_run.call_deferred()


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	Kit.box(world, Vector3(0, -0.5, 0), Vector3(600, 1, 600), Color(0.5, 0.5, 0.5))
	_every_piece()
	_kit_lists()
	player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	await _ticks(10)
	var x := -200.0
	for id in KitShapes.SHAPES:
		if SetPieces.RUNS.has(id):
			await _wallrun(id, Vector3(x, 0, 0))
			x += 30.0
	x = -200.0
	for id in KitShapes.SHAPES:
		if not KitShapes.SHAPES[id]["hooks"].is_empty():
			await _grapple(id, Vector3(x, 0, 120))
			x += 40.0
	world.queue_free()
	await _ticks(2)
	for biome in ["city", "military"]:
		await _zone(biome)
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## Every model, in a row at z = -250: it loads, gets a body per collider, its
## hooks and tops come back turned with it, and every neon part is lit.
func _every_piece() -> void:
	var bad := []
	var x := -250.0
	var neon := 0
	for id in KitShapes.SHAPES:
		var before := world.get_child_count()
		var placed := SetPieces.place(world, id, Vector3(x, 0, -250), 90.0)
		var shape: Dictionary = KitShapes.SHAPES[id]
		var added := world.get_child_count() - before
		if placed["node"] == null or added != 1 + shape["boxes"].size() + shape["columns"].size():
			bad.append([id, added])
		if placed["hooks"].size() != shape["hooks"].size() or placed["tops"].size() != shape["tops"].size():
			bad.append([id, "hooks/tops"])
		for mi in (placed["node"] as Node3D).find_children("*__neon*", "MeshInstance3D", true, false):
			neon += 1
			if mi.get_instance_shader_parameter("paint") == null:
				bad.append([id, "neon unlit", mi.name])
		x += 25.0
	var kits := {}
	for id in KitShapes.SHAPES:
		kits[KitShapes.SHAPES[id]["kit"]] = kits.get(KitShapes.SHAPES[id]["kit"], 0) + 1
	_check("%d kit pieces load with their colliders (%s), %d neon parts lit" % [KitShapes.SHAPES.size(), kits, neon],
			bad.is_empty() and kits.get("city", 0) >= 15 and kits.get("military", 0) >= 15 and neon > 20, bad)


## Every id biome.gd's kit lists name is a piece that exists.
func _kit_lists() -> void:
	var missing := []
	for table in [B.KIT_PROPS, B.KIT_BUILDINGS, B.KIT_WALLS, B.KIT_LANDMARKS]:
		for biome in table:
			for id in table[biome]:
				if not SetPieces.has(id):
					missing.append(id)
	for id in B.KIT_CENTREPIECE.values():
		if not SetPieces.has(id):
			missing.append(id)
	_check("biome.gd's city and military lists name real pieces", missing.is_empty(), missing)


## The wall turned to run along Z: run in from beyond its near end beside its
## face, jump onto it and run its length.
func _wallrun(id: String, at: Vector3) -> void:
	var placed := SetPieces.place(world, id, at, 90.0)
	var r: Array = SetPieces.RUNS[id]
	var basis := Basis(Vector3.UP, deg_to_rad(90.0))
	var a: Vector3 = at + basis * (r[0] as Vector3)
	var b: Vector3 = at + basis * (r[1] as Vector3)
	var near := a if a.z > b.z else b
	var far := b if a.z > b.z else a
	var length := near.z - far.z
	# How far the wall's face stands out from its run line (+x side).
	var face := 0.0
	for box in KitShapes.SHAPES[id]["boxes"]:
		var c: Vector3 = at + basis * (box[0] as Vector3)
		var s: Vector3 = box[1]
		var half := (Basis(Vector3.UP, deg_to_rad(90.0 + box[2])) * s).abs().x * 0.5
		if c.y + s.y * 0.5 > 2.5 and c.y - s.y * 0.5 < 3.0 and absf(c.z - (near.z + far.z) * 0.5) < length:
			face = maxf(face, c.x + half - near.x)
	_place(Vector3(near.x + face + 1.0, 0.1, near.z + 4.0), 0.0)
	Input.action_press("move_forward")
	await _ticks(40)
	await _press("jump")
	player.velocity.x = -3.0
	var start_z := INF
	var end_z := INF
	for i in 240:
		await physics_frame
		if OS.has_environment("DBG") and i % 5 == 0:
			print(i, " ", player.state_name(), " ", player.global_position, " ", player.velocity, " wall=", player.is_on_wall())
		if player.state_name() == "WALLRUN":
			if start_z == INF:
				start_z = player.global_position.z
			end_z = player.global_position.z
		elif start_z != INF:
			break
	Input.action_release("move_forward")
	var ran := start_z - end_z if start_z != INF else 0.0
	_check("%s: wallrun along it (%.1f m of %.1f)" % [id, ran, length], ran > length * 0.6, [start_z, end_z, face])
	placed["node"].queue_free()


## Look at the piece's first hook from 16 m off and grapple it.
func _grapple(id: String, at: Vector3) -> void:
	var placed := SetPieces.place(world, id, at, 0.0)
	var hook: Vector3 = placed["hooks"][0]
	var s := SetPieces.size(id)
	_place(Vector3(hook.x, 0.1, at.z + s.y * 0.5 + 14.0), 0.0)
	await _ticks(10)
	while player.grapple_ready_in() > 0.0:
		await physics_frame
	var to: Vector3 = hook - player.camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await _ticks(1)
	Input.action_press("grapple")
	await _ticks(3)
	var hooked: bool = player.state_name() == "GRAPPLE" and player.grapple_point.distance_to(hook) < 1.6
	var closest := 99.0
	# A hook on a roof: let go once over the roof's edge and drop onto it.
	var roof: float = placed["tops"][0].y if not placed["tops"].is_empty() and hook.y - placed["tops"][0].y < 6.0 else INF
	var landed := false
	for i in 320:
		await physics_frame
		closest = minf(closest, (player.global_position + Vector3.UP).distance_to(hook))
		if Input.is_action_pressed("grapple") and player.global_position.y > roof + 0.3:
			Input.action_release("grapple")
		if player.is_on_floor() and player.global_position.y > roof - 0.3:
			landed = true
			break
	Input.action_release("grapple")
	_check("%s: hook caught and pulled in (%.1f m%s)" % [id, closest, ", onto the roof" if landed else ""], hooked and (closest < 4.5 or landed),
			[player.grapple_point, hook, player.global_position, player.state_name(), player.velocity])


## A whole generated zone of the kind: it builds, it's dressed from its own
## kit, its walls are its own, and it has wallruns and hooks to use.
func _zone(biome: String) -> void:
	var zone := Node3D.new()
	root.add_child(zone)
	var plan = LevelPlan.make(4242 + biome.length(), 4, 4, biome)
	var info := ZoneGenerator.build_from_plan(zone, plan, 4)
	var used := {}
	for p in info["set_pieces"]:
		used[p["id"]] = true
	var own: Array = used.keys().filter(func(id): return KitShapes.SHAPES.has(id) and KitShapes.SHAPES[id]["kit"] == biome)
	var walls: Array = info["kit"]["walls"]
	var ok: bool = own.size() >= 8 and walls.all(func(w): return KitShapes.SHAPES.has(w)) \
			and info["wallruns"].size() >= 3 and info["grapple_spots"].size() >= 3
	_check("%s zone %s: %d of its own pieces (%s), %d wallruns, %d hooks" % [biome, plan.zone_name, own.size(), ", ".join(own),
			info["wallruns"].size(), info["grapple_spots"].size()], ok, walls)
	zone.queue_free()
	await _ticks(2)


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
