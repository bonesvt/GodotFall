extends SceneTree
## Headless test for grunt stealth: vision cone, sight range, cover, the
## detection meter, gunshot hearing, squad callouts, sneak-attack damage and
## the knife (takedowns on unaware grunts; tap to strike, hold a second to
## draw it as her weapon, each knife's own moves).
## Run: godot --headless --path . -s res://tests/stealth_test.gd

const Grunt := preload("res://scripts/grunt.gd")
const F := preload("res://scripts/run/forest_kit.gd")
const RunManager := preload("res://scripts/run/run_manager.gd")

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

	# Inside sight range but past the shorter range an unaware grunt notices at.
	_place(SPOT)
	g = _grunt(Vector3(-32, 0, 0), Vector3(1, 0, 0))
	await _seconds(3.0)
	_check("unaware grunts only notice at shorter range", g.detection < 0.02 and 32.0 < g.sight_range, g.detection)
	# Once alerted it still tracks the pilot out to its full sight range.
	g.alert()
	await _ticks(30)
	_check("alerted grunts see to full range", g.has_sight, g.has_sight)
	_clear()

	# Off to the side, past the edge of its vision cone.
	_place(SPOT)
	g = _grunt(Vector3(-8, 0, -11), Vector3(1, 0, 0))
	await _seconds(2.0)
	_check("pilot at the edge of vision is not seen", g.detection < 0.02, g.detection)
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
	var far = _grunt(Vector3(-22, 0, -3), Vector3(1, 0, 0))
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

	# Forest foliage: tall grass hides a crouched pilot and muffles a standing one;
	# dense foliage blocks sight like a wall.
	_place(SPOT)
	var grunt_far = _grunt(Vector3(-12, 0, 0), Vector3(1, 0, 0))
	grunt_far.passive = true
	await _ticks(3)
	var open_rate: float = grunt_far._sight_gain(grunt_far.global_position + Grunt.EYE)
	var grass = F.stealth_cover(level, SPOT + Vector3(0, 0.8, 0), Vector3(3, 2.4, 3))
	await _ticks(3)
	var grass_rate: float = grunt_far._sight_gain(grunt_far.global_position + Grunt.EYE)
	Input.action_press("crouch")
	await _ticks(10)
	var lying: int = grunt_far._visible_points(grunt_far.global_position + Grunt.EYE)
	Input.action_release("crouch")
	_check("standing in tall grass is noticed slower", grass_rate > 0.0 and grass_rate < open_rate * 0.6, [grass_rate, open_rate])
	_check("crouched in tall grass is hidden", lying == 0, lying)
	grass.queue_free()
	var bush = F.sight_blocker(level, SPOT + Vector3(-4, 1.4, 0), Vector3(1, 2.8, 3))
	await _ticks(10)
	var through: int = grunt_far._visible_points(grunt_far.global_position + Grunt.EYE)
	_check("dense foliage blocks sight", through == 0, through)
	bush.queue_free()
	_clear()

	# Sneak attacks: hits on an unaware grunt do double damage.
	_place(SPOT)
	g = _grunt(Vector3(-10, 0, 0), Vector3(-1, 0, 0))
	await _ticks(3)
	g.take_damage(20.0, g.global_position)
	_check("unaware grunts take double damage", is_equal_approx(g.health, 20.0) and g.alerted, g.health)
	g.take_damage(20.0, g.global_position)
	_check("alerted grunts take normal damage", g.dead, g.health)
	_clear()

	# Knife: a takedown from behind kills an unaware grunt outright.
	var knife = player.get_node("Head/Camera3D/Knife")
	var stabs := []
	knife.stabbed.connect(func(kind): stabs.append(kind))
	_place(SPOT)
	g = _grunt(Vector3(-1.7, 0, 0), Vector3(-1, 0, 0))
	await _ticks(3)
	_check("sneaking up behind stays unnoticed", g.is_unaware(), g.detection)
	await _stab(knife)
	_check("takedown is a thrust", stab_anims.back() == "thrust", stab_anims)
	_check("knife takedown kills an unaware grunt", g.dead and stabs.back() == "takedown", [g.health, stabs])
	_clear()

	# ...but on a grunt that knows you're there it's just a hit.
	_place(SPOT)
	g = _grunt(Vector3(-1.7, 0, 0), Vector3(1, 0, 0))
	g.passive = true  # stands still, doesn't shoot back
	await _ticks(3)
	g.awareness = Grunt.Awareness.ALERTED
	await _stab(knife)
	_check("knife on an aware grunt is a normal hit", not g.dead and is_equal_approx(g.health, 60.0 - knife.damage) and stabs.back() == "hit", [g.health, stabs])
	_clear()

	# Out of reach, or behind cover, it whiffs.
	_place(SPOT)
	g = _grunt(Vector3(-4.0, 0, 0), Vector3(-1, 0, 0))
	await _ticks(3)
	await _stab(knife)
	_check("knife has short reach", not g.dead and stabs.back() == "miss", [g.health, stabs])
	_clear()

	_place(SPOT)
	wall = level._box(SPOT + Vector3(-0.9, 1.4, 0), Vector3(0.3, 2.8, 3), Color.GRAY)
	g = _grunt(Vector3(-1.9, 0, 0), Vector3(-1, 0, 0))
	await _ticks(3)
	await _stab(knife)
	_check("knife can't stab through walls", not g.dead and stabs.back() == "miss", [g.health, stabs])
	wall.queue_free()
	_clear()

	# The knife's keys don't clash with anything: not V (titan call / core),
	# not F (interact / embark), nor any other action, in or out of a run.
	RunManager.ensure_input_actions()
	var clashes := []
	for action in InputMap.get_actions():
		if action == "melee" or String(action).begins_with("ui_"):
			continue
		for ev in InputMap.action_get_events(action):
			for mine in InputMap.action_get_events("melee"):
				if ev.is_match(mine):
					clashes.append([action, ev.as_text()])
	_check("knife keys are free", clashes.is_empty() and InputMap.action_get_events("melee").size() >= 1, clashes)
	await _ticks(int(knife.cooldown * 120) + 2)
	for key in [KEY_V, KEY_F]:
		var k := InputEventKey.new()
		k.physical_keycode = key
		k.pressed = true
		Input.parse_input_event(k)
		await _ticks(2)
		k = k.duplicate()
		k.pressed = false
		Input.parse_input_event(k)
		await _ticks(1)
	_check("V and F don't stab", not knife.is_stabbing(), knife.stab_timer)

	# The melee key stabs, and the pistol can't fire mid-stab.
	_place(SPOT)
	await _ticks(int(knife.cooldown * 120) + 2)
	var ev := InputEventAction.new()
	ev.action = "melee"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _ticks(2)
	var up := InputEventAction.new()
	up.action = "melee"
	Input.parse_input_event(up)
	await _ticks(2)
	_check("tapping the melee key stabs", knife.is_stabbing(), knife.stab_timer)
	_check("pistol holstered mid-stab", weapon.holstered, weapon.holstered)
	await _seconds(1.0)
	_check("pistol back after the stab", not weapon.holstered, weapon.holstered)

	# Holding the key for about a second draws the knife as her weapon: no
	# stab, the gun put away (hidden, can't fire), faster running; left mouse
	# attacks, I inspects, and letting go keeps it out. Real key and mouse
	# events throughout: a synthetic InputEventAction for one action also
	# releases a held one.
	var run_before: float = player.run_speed * player.speed_mult
	await _seconds(1.0)
	_key(KEY_Z, true)
	await _seconds(0.5)
	_check("half a second's hold does nothing yet", not knife.out and not knife.is_stabbing() and not weapon.holstered, [knife.out, knife.stab_timer])
	await _seconds(0.65)
	_check("a one-second hold draws the knife", knife.out and not knife.is_stabbing() and knife.anim == "draw", [knife.out, knife.anim])
	_key(KEY_Z, false)
	await _seconds(0.5)
	_check("letting go keeps it out, no stab", knife.out and not knife.is_stabbing(), [knife.out, knife.stab_timer])
	_check("knife out: the gun is put away and hidden, Eco runs faster", weapon.holstered and weapon.stowed and not weapon.viewmodel.visible \
			and player.run_speed * player.speed_mult > run_before * 1.1, [weapon.holstered, weapon.viewmodel.visible, player.speed_mult])
	Input.action_press("move_forward")
	await _seconds(1.5)
	var hs: float = player.horizontal_speed()
	Input.action_release("move_forward")
	_check("actually moves faster with the knife out", hs > player.sprint_speed * 1.1, hs)
	await _seconds(0.5)
	var lines := []
	weapon.inspected.connect(func(line): lines.append(line))
	_key(KEY_I, true)
	await _ticks(3)
	_key(KEY_I, false)
	_check("I with the knife out plays the knife inspect", knife.is_inspecting() and not weapon.is_inspecting() and lines.size() == 1 \
			and lines[0] in knife.moves["lines"], [knife.anim, lines])
	await _seconds(knife.anim_length("inspect") + 0.1)
	_check("knife inspect ends back in the guard", knife.anim == "" and knife.out, knife.anim)
	var ammo_before: int = weapon.ammo
	_click()
	await _ticks(2)
	_check("left mouse attacks with the knife out", knife.is_stabbing() and knife.anim.begins_with("attack"), [knife.stab_timer, knife.anim])
	var first: String = knife.anim
	await _seconds(0.6)
	_click()
	await _ticks(2)
	_check("attacks alternate", knife.anim.begins_with("attack") and knife.anim != first, [first, knife.anim])
	await _seconds(0.6)
	_check("the gun never fired while the knife was out", weapon.ammo == ammo_before, [ammo_before, weapon.ammo])

	# A tap of the key puts it away and the gun comes back with its draw.
	_key(KEY_Z, true)
	await _ticks(3)
	_key(KEY_Z, false)
	await _ticks(2)
	_check("tapping the key puts the knife away, no stab", not knife.out and not knife.is_stabbing() and player.speed_mult == 1.0, [knife.out, knife.stab_timer])
	_check("the gun comes back with its draw", not weapon.holstered and not weapon.stowed and weapon.is_drawing() and weapon.viewmodel.visible, [weapon.holstered, weapon.is_drawing()])
	await _seconds(0.5)
	_check("pistol back up", not weapon.holstered and not weapon.is_drawing(), weapon.holstered)
	_click()
	await _ticks(3)
	_check("the gun fires again", weapon.ammo == ammo_before - 1, [ammo_before, weapon.ammo])

	# The mouse wheel and R swap back too.
	for swap in ["wheel", "reload"]:
		await _seconds(0.5)
		_key(KEY_Z, true)
		await _seconds(1.15)
		_key(KEY_Z, false)
		_check("held again: knife out (%s)" % swap, knife.out, knife.out)
		await _seconds(0.3)
		if swap == "wheel":
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = true
			Input.parse_input_event(wheel)
			wheel = wheel.duplicate()
			wheel.pressed = false
			Input.parse_input_event(wheel)
		else:
			_key(KEY_R, true)
			await _ticks(2)
			_key(KEY_R, false)
		await _ticks(3)
		_check("%s puts the knife away and the gun back" % swap, not knife.out and not weapon.holstered, [knife.out, weapon.holstered])

	# Every knife's own moves play through without trouble.
	for id in ["needle", "kunai", "butterfly"]:
		knife.set_model(id)
		knife.draw_knife()
		var seen := []
		for move in ["draw", "attack_a", "attack_b", "thrust", "inspect"]:
			knife._play(move)
			await _ticks(2)
			seen.append(knife.anim)
			await _seconds(knife.anim_length(move) + 0.1)
		var tip_ok: bool = knife._tip.global_position.distance_to(knife._blade_root.global_position) > 0.15
		_check("%s: draw, attacks, takedown and inspect all play and end" % id, seen == ["draw", "attack_a", "attack_b", "thrust", "inspect"] \
				and knife.anim == "" and knife.out and tip_ok, [seen, knife.anim])
		knife.put_away()
		await _seconds(0.5)
	var swing := func(id: String) -> Array:
		var m: Dictionary = knife.Moves.moves(id)
		return m["anims"]["attack_a"]["hand"].map(func(k): return k[2])
	_check("each knife moves its own way", swing.call("needle") != swing.call("kunai") and swing.call("kunai") != swing.call("butterfly") \
			and knife.Moves.moves("kunai")["grip"] != Vector3.ZERO, "")
	knife.set_model("needle")

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


var stab_anims := []


func _stab(knife) -> void:
	await _ticks(int(knife.cooldown * 120) + 2)
	knife.stab()
	stab_anims.append(knife.anim)
	await _seconds(knife.stab_time + 0.05)


func _key(key: Key, down: bool) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = key
	k.pressed = down
	Input.parse_input_event(k)


func _click() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)


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
