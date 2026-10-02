extends SceneTree
## Headless smoke test for the starter pistol and grunts.
## Run: godot --headless --path . -s res://tests/combat_test.gd

var level
var player
var weapon
var failures := 0
var hits: Array[String] = []

# Open ground west of the slide ramp, far from the arena.
const RANGE_SPOT := Vector3(-40, 0.1, 20)


func _initialize() -> void:
	level = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	_run.call_deferred()


func _run() -> void:
	await _ticks(30)
	player = root.get_node("TestLevel/Player")
	weapon = player.get_node("Head/Camera3D/Weapon")
	weapon.hit_confirmed.connect(func(kind): hits.append(kind))
	_check("arena has grunts", level.grunts_alive() == 6, level.grunts_alive())
	weapon.base_spread = 0.0  # deterministic aim for the checks below

	# Body shot at 10 m: base damage
	var g = await _target(10.0)
	await _shoot_at(g, 1.0)
	_check("body shot deals 20", is_equal_approx(g.health, 40.0), g.health)
	_check("body hitmarker", hits.back() == "body", hits)

	# Headshot finishes it (45 > 40)
	await _shoot_at(g, 1.62)
	_check("headshot kills", g.dead and hits.back() == "kill", g.health)

	# Fresh grunt: three body shots, not two
	g = await _target(10.0)
	await _shoot_at(g, 1.0)
	await _shoot_at(g, 1.0)
	_check("two body shots do not kill", not g.dead, g.health)
	await _shoot_at(g, 1.0)
	_check("three body shots kill", g.dead, g.health)

	# Damage falloff at 30 m
	g = await _target(30.0)
	await _shoot_at(g, 1.0)
	var dealt: float = 60.0 - g.health
	_check("falloff at 30 m", dealt < 15.0 and dealt > 11.0, dealt)
	g.queue_free()

	# Semi-auto: holding the trigger fires once
	weapon.refill()
	var before: int = weapon.shots_fired
	Input.action_press("fire")
	await _ticks(60)
	Input.action_release("fire")
	_check("semi-auto, one shot per click", weapon.shots_fired == before + 1, weapon.shots_fired - before)

	# Bloom: spamming widens the cone, waiting recovers it
	weapon.refill()
	for i in 4:
		await _press("fire")
		await _ticks(int(weapon.fire_interval * 120) + 2)
	_check("spam blooms spread", weapon.current_spread() > 3.0, weapon.current_spread())
	await _ticks(120)
	_check("bloom recovers", weapon.current_spread() < 0.1, weapon.current_spread())

	# Magazine and reload
	weapon.refill()
	for i in weapon.magazine_size:
		await _press("fire")
		await _ticks(int(weapon.fire_interval * 120) + 2)
	_check("magazine empties", weapon.ammo == 0, weapon.ammo)
	await _press("fire")
	await _ticks(2)
	_check("empty click reloads", weapon.is_reloading(), weapon.ammo)
	await _ticks(int(weapon.reload_time * 120) + 5)
	_check("reload refills", weapon.ammo == weapon.magazine_size and not weapon.is_reloading(), weapon.ammo)

	# Wallrunning keeps the pistol accurate, plain jumping does not
	weapon.refill()
	player.state = player.State.WALLRUN
	var wall_spread: float = weapon.current_spread()
	player.state = player.State.AIR
	var air_spread: float = weapon.current_spread()
	_check("wallrun accuracy beats airborne", wall_spread < air_spread, [wall_spread, air_spread])
	_place(RANGE_SPOT, PI / 2.0)

	# Grunts: aim worse at a fast pilot, and actually shoot a still one
	g = level.spawn_grunt(RANGE_SPOT + Vector3(-12, 0, 0))
	await _ticks(5)
	var still: float = g.hit_chance()
	player.velocity = Vector3(0, 0, 11)
	var fast: float = g.hit_chance()
	player.velocity = Vector3.ZERO
	_check("grunts miss fast pilots more", fast < still * 0.5, [still, fast])
	var hp0: float = player.health
	await _ticks(120 * 6)
	_check("grunt spots and damages a still pilot", g.alerted and player.health < hp0, player.health)

	# Dying respawns the pilot and resets the arena
	await _ticks(1)
	player.take_damage(1000.0)
	await _ticks(5)
	_check("death respawns at full health", player.health == player.max_health, player.health)
	_check("death resets the arena", level.grunts_alive() == 6, level.grunts_alive())

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## Spawns a passive grunt the given distance in front of the pilot.
func _target(distance: float):
	_place(RANGE_SPOT, PI / 2.0)  # facing -X
	var g = level.spawn_grunt(RANGE_SPOT + Vector3(-distance, -0.1, 0), true)
	await _ticks(20)
	return g


## Aims at a height on the grunt, fires one shot, and waits out the bloom.
func _shoot_at(g, height: float) -> void:
	var eye: Vector3 = player.camera.global_position
	var aim: Vector3 = g.global_position + Vector3.UP * height
	var flat := Vector2(aim.x - eye.x, aim.z - eye.z).length()
	player.get_node("Head").rotation.x = atan2(aim.y - eye.y, flat)
	weapon.recoil_pending = 0.0
	weapon.bloom = 0.0
	await _press("fire")
	await _ticks(int(weapon.fire_interval * 120) + 2)


func _place(pos: Vector3, yaw: float) -> void:
	for a in ["move_forward", "crouch", "jump", "grapple", "fire"]:
		Input.action_release(a)
	player.global_position = pos
	player.rotation.y = yaw
	player.get_node("Head").rotation.x = 0.0
	player.velocity = Vector3.ZERO


func _press(action: String) -> void:
	await physics_frame
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
