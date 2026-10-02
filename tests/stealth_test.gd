extends SceneTree
## Headless test for grunt stealth: vision cone, sight range, cover, the
## detection meter, gunshot hearing and squad callouts.
## Run: godot --headless --path . -s res://tests/stealth_test.gd

const Grunt := preload("res://scripts/grunt.gd")

var level
var player
var weapon
var failures := 0
var spawned: Array = []

# Open ground west of the slide ramp, far from the grunt arena.
const SPOT := Vector3(-40, 0.1, 20)


func _initialize() -> void:
	level = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	_run.call_deferred()


func _run() -> void:
	await _ticks(30)
	player = root.get_node("TestLevel/Player")
	weapon = player.get_node("Head/Camera3D/Weapon")

	# Behind a grunt: a still pilot 12 m behind it is never noticed.
	_place(SPOT)
	var g = _grunt(Vector3(-12, 0, 0), Vector3(-1, 0, 0))
	await _seconds(4.0)
	_check("grunts start unaware", g.awareness == Grunt.Awareness.UNAWARE and not g.alerted, g.awareness)
	_check("pilot behind a grunt is not noticed", g.detection < 0.02, g.detection)
	_check("no indicator while unaware", not g.indicator.visible, g.indicator.visible)

	# A gunshot behind it is heard: it turns to look, then spots the pilot.
	player.get_node("Head").rotation.x = 1.2  # fire into the ground
	weapon.refill()
	await _press("fire")
	await _ticks(2)
	_check("gunshot makes a nearby grunt suspicious", g.awareness == Grunt.Awareness.SUSPICIOUS and g.indicator.text == "?", [g.awareness, g.detection])
	await _seconds(3.0)
	_check("suspicious grunt turns and spots the pilot", g.alerted and g.indicator.text == "!", [g.awareness, g.detection])
	_clear()

	# Too far: a grunt looking straight at the pilot beyond its sight range.
	_place(SPOT)
	g = _grunt(Vector3(-48, 0, 0), Vector3(1, 0, 0))
	await _seconds(3.0)
	_check("pilot beyond sight range is not noticed", g.detection < 0.02, g.detection)
	_clear()

	# Full cover between the pilot and a grunt facing them.
	_place(SPOT)
	var wall = level._box(SPOT + Vector3(-3, 1.4, 0), Vector3(1, 2.8, 3), Color.GRAY)
	g = _grunt(Vector3(-15, 0, 0), Vector3(1, 0, 0))
	await _seconds(3.0)
	_check("cover hides the pilot", g.detection < 0.02, g.detection)
	wall.queue_free()
	_clear()

	# Low cover: crouched behind it hides you, standing up shows you.
	_place(SPOT)
	wall = level._box(SPOT + Vector3(-1.2, 0.6, 0), Vector3(0.5, 1.2, 3), Color.GRAY)
	g = _grunt(Vector3(-15, 0, 0), Vector3(1, 0, 0))
	g.passive = true  # just look, don't fill the meter
	await _ticks(3)
	var eye: Vector3 = g.global_position + Grunt.EYE
	var standing: int = g._visible_points(eye)
	Input.action_press("crouch")
	await _ticks(10)
	var crouched: int = g._visible_points(eye)
	_check("crouching behind low cover hides the pilot", standing > 0 and crouched == 0, [standing, crouched])
	Input.action_release("crouch")
	wall.queue_free()
	_clear()

	# In plain view the meter takes a moment to fill, faster up close, slower crouched.
	_place(SPOT)
	var near = _grunt(Vector3(-8, 0, 0), Vector3(1, 0, 0))
	var far = _grunt(Vector3(-30, 0, -3), Vector3(1, 0, 0))
	near.passive = true
	far.passive = true
	await _ticks(3)
	var near_rate: float = near._sight_gain(near.global_position + Grunt.EYE)
	var far_rate: float = far._sight_gain(far.global_position + Grunt.EYE)
	Input.action_press("crouch")
	await _ticks(10)
	var crouch_rate: float = far._sight_gain(far.global_position + Grunt.EYE)
	Input.action_release("crouch")
	_check("closer pilots are noticed faster", near_rate > far_rate * 3.0 and far_rate > 0.0, [near_rate, far_rate])
	_check("crouching is noticed slower", crouch_rate > 0.0 and crouch_rate < far_rate * 0.6, [crouch_rate, far_rate])
	_clear()

	_place(SPOT)
	g = _grunt(Vector3(-12, 0, 0), Vector3(1, 0, 0))
	await _ticks(40)
	_check("not alerted instantly", not g.alerted and g.detection > 0.0, g.detection)
	await _seconds(2.0)
	_check("pilot in plain view gets spotted", g.alerted and g.awareness == Grunt.Awareness.ALERTED, g.detection)
	_clear()

	# Squad callout: an alerted grunt alerts squadmates nearby, not far-off ones.
	_place(SPOT + Vector3(0, 0, 60))
	var a = _grunt(Vector3(-20, 0, 0), Vector3(-1, 0, 0))
	var b = _grunt(Vector3(-26, 0, 4), Vector3(-1, 0, 0))
	var c = _grunt(Vector3(-20, 0, -8), Vector3(-1, 0, 0))
	var lone = _grunt(Vector3(-20, 0, -40), Vector3(-1, 0, 0))
	await _ticks(5)
	var events := []
	a.called_out.connect(func(_g, squad): events.append(squad.size()))
	b.awareness_changed.connect(func(_g, aw): events.append(aw))
	a.alert()
	_check("callout and awareness signals fire", events == [Grunt.Awareness.ALERTED, 2], events)
	_check("alerted grunt calls in its squad", b.alerted and c.alerted, [b.alerted, c.alerted])
	_check("callout doesn't reach far grunts", not lone.alerted, lone.alerted)

	# Damage always alerts.
	lone.take_damage(1.0, lone.global_position)
	_check("getting shot alerts a grunt", lone.alerted, lone.awareness)

	# Losing the pilot: out of sight long enough, an alerted grunt goes back to searching.
	_clear()
	_place(SPOT)
	wall = level._box(SPOT + Vector3(-3, 1.4, 0), Vector3(1, 2.8, 3), Color.GRAY)
	g = _grunt(Vector3(-15, 0, 0), Vector3(1, 0, 0))
	g.leash = 1.0
	await _ticks(3)
	g.alert()
	g.lose_track_time = 1.0
	await _seconds(2.0)
	_check("hidden pilot is lost and searched for", not g.alerted and g.awareness == Grunt.Awareness.SUSPICIOUS, g.awareness)
	wall.queue_free()
	_clear()

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## Spawns a grunt at an offset from SPOT, facing the given direction.
func _grunt(offset: Vector3, facing: Vector3):
	var g = level.spawn_grunt(player.global_position + offset - Vector3(0, 0.1, 0))
	g.rotation.y = atan2(-facing.x, -facing.z)
	spawned.append(g)
	return g


func _clear() -> void:
	for g in spawned:
		if is_instance_valid(g):
			g.queue_free()
	spawned.clear()


func _place(pos: Vector3) -> void:
	for a in ["move_forward", "crouch", "jump", "grapple", "fire"]:
		Input.action_release(a)
	player.global_position = pos
	player.rotation.y = PI / 2.0  # facing -X
	player.get_node("Head").rotation.x = 0.0
	player.velocity = Vector3.ZERO
	player.health = player.max_health


func _press(action: String) -> void:
	await physics_frame
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _seconds(s: float) -> void:
	await _ticks(int(s * Engine.physics_ticks_per_second))


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
