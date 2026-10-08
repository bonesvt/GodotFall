extends SceneTree
## Hymn (hymn.gd): the colony dispensary (dispensary_screen.gd) and its three
## choices, the Shepherd (shepherd.gd) hunting her after a refusal (darts,
## the pulse that fires a colony trigger word, bringing her in), the gear it
## puts on her (colony_gear.gd) and what each piece does: the headphones'
## words, the dose cuff's countdown, the clarity visor's clutter
## (visor_screen.gd). Mature only.
##   godot --headless --path . -s res://tests/hymn_test.gd

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const TriggerWords := preload("res://scripts/hub/trigger_words.gd")
const Shepherd := preload("res://scripts/hub/shepherd.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const Wardrobe := preload("res://scripts/hub/wardrobe.gd")

var run_node: Node
var player: CharacterBody3D
var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_hymn_armory.cfg"
	for f in ["user://test_hymn_armory.cfg", "user://test_hymn_armory_vices.cfg", "user://test_hymn_armory_hymn.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(60)
	player = run_node.player
	run_node.hush_pull.triggers._next = INF  # only the words this test fires
	_check("its own save next to her vices", Hymn.save_path.ends_with("test_hymn_armory_hymn.cfg"), Hymn.save_path)
	_check("starts clean", Hymn.level == 0.0 and Hymn.gear.is_empty() and not Hymn.hunted, [Hymn.level, Hymn.gear])
	var kiosk: Vector3 = run_node._dispensary_spot()
	_check("a dispensary in town", kiosk != Vector3.INF, kiosk)

	# Take the dose.
	run_node.open_bench("dispensary")
	await _ticks(2)
	_check("the dispensary opens", run_node.bench != null and run_node.bench.kind == "dispensary", run_node.bench)
	run_node.bench.take()
	await _until(func(): return run_node.bench == null, 4.0)
	_check("taking it: Hymn in her, done for today", Hymn.level == Hymn.DOSE and Hymn.dosed_today and not Hymn.hunted, [Hymn.level, Hymn.dosed_today])
	await _ticks(2)
	_check("the morning dose plays out", run_node.dose_scene.busy() and player.entranced, run_node.dose_scene.t)
	await _until(func(): return not run_node.dose_scene.busy(), 6.0)
	_check("and lets her go", not player.entranced, player.entranced)
	run_node.open_bench("dispensary")
	await _ticks(2)
	_check("once a day", run_node.bench._status.text == run_node.bench.DONE, run_node.bench._status.text)
	run_node.close_bench()

	# Palming: in the window it works, and the window narrows each time.
	Hymn.dosed_today = false
	var w0 := Hymn.window()
	_check("palmed inside the window", Hymn.palm(0.5 + w0 * 0.5, 0.5), Hymn.fakes)
	_check("narrower next time", Hymn.window() < w0 and Hymn.dosed_today and not Hymn.hunted, Hymn.window())
	Hymn.dosed_today = false
	_check("missed: caught, hunted", not Hymn.palm(0.1, 0.5) and Hymn.hunted, Hymn.hunted)
	Hymn.hunted = false

	# Refuse: the Shepherd comes.
	_place(kiosk + Vector3(2.0, 0.1, 0))
	await _ticks(10)
	run_node.open_bench("dispensary")
	await _ticks(2)
	run_node.bench.refuse()
	await _until(func(): return run_node.bench == null, 4.0)
	await _ticks(2)
	var hunters := get_nodes_in_group("shepherd")
	_check("refusing sets the Shepherd on her", Hymn.hunted and hunters.size() == 1, hunters.size())
	var shep: CharacterBody3D = hunters[0]
	shep._dart_t = INF
	shep._pulse_t = INF
	_check("it comes out by the dispensary", shep.global_position.distance_to(kiosk) < 6.0, shep.global_position)

	# A dart: Hymn in her, a step of sedation.
	_place(shep.global_position + Vector3(6.0, 0, 0))
	await _ticks(5)
	var before := Hymn.level
	shep.fire_dart()
	await _ticks(int(Engine.physics_ticks_per_second * 0.6))
	_check("a dart lands: Hymn up, sedated a step", Hymn.level == before + Hymn.DART and shep.sedation > 0.0, [Hymn.level, shep.sedation])

	# The pulse: one of the colony's words, locking her up.
	shep.pulse()
	await _ticks(2)
	var tw: Node = run_node.hush_pull.triggers
	_check("the pulse fires a colony word", tw.busy() and tw.phrase in TriggerWords.COLONY_PHRASES and player.entranced, tw.phrase)
	for i in TriggerWords.TAPS:
		await _press("interact")
	await _ticks(2)
	_check("she can shake it off", not tw.busy() and not player.entranced, tw.step)

	# It loses her: off it goes.
	shep.give_up()
	await _ticks(3)
	_check("out of sight long enough, it gives up", not Hymn.hunted and get_nodes_in_group("shepherd").is_empty(), Hymn.hunted)

	# Brought in: processed, the first piece of gear on, back at the dispensary.
	Hymn.hunted = true
	run_node.spawn_shepherd()
	await _ticks(2)
	shep = get_nodes_in_group("shepherd")[0]
	shep._dart_t = INF
	shep._pulse_t = INF
	_place(shep.global_position + Vector3(0.9, 0, 0))
	await _until(func(): return get_nodes_in_group("shepherd").is_empty(), 8.0)
	await _ticks(2)
	var fitting: Node = run_node.fitting_scene
	_check("the fitting plays in the back room", fitting.busy() and fitting.piece == "headphones" and player.entranced, fitting.piece)
	await _until(func(): return fitting._said.has("lock"), 14.0)
	var pin: Node3D = fitting._gear.get_node("Pin_L") if fitting._gear != null else null
	_check("the pins go into her ears", pin != null and pin.scale.y > 0.9, pin.scale if pin != null else null)
	await _until(func(): return not fitting.busy(), 8.0)
	_check("caught: processed, the headphones on", Hymn.gear == ["headphones"] and Hymn.captures == 1 and not Hymn.hunted, Hymn.gear)
	_check("she wakes at the dispensary", player.global_position.distance_to(kiosk) < 2.5 and not player.entranced, player.global_position)
	_check("the gear shows on her", player.find_child("ColonyGear", true, false) != null, player.find_child("ColonyGear", true, false))

	# The headphones: their words from any Hold, twice as often, less time.
	Vices.hold = 0.0
	_check("headphones: words from any Hold", TriggerWords.can_trigger(), Vices.hold)
	_check("headphones: twice as often, less time", is_equal_approx(TriggerWords.gap(), TriggerWords.GAP_LIGHT * 0.5) and TriggerWords.window() < TriggerWords.WINDOW, TriggerWords.gap())

	# The dose cuff: skip the line and it counts down, then doses her.
	Hymn.gear.append("cuff")
	Hymn.dosed_today = false
	Hymn.cuff_left = 0.5
	before = Hymn.level
	await _ticks(10)
	_check("the cuff's countdown on the HUD", run_node.hud.cuff_label.visible and run_node.hud.cuff_label.text.begins_with("DOSE CUFF"), run_node.hud.cuff_label.text)
	await _ticks(int(Engine.physics_ticks_per_second * 0.7))
	_check("time's up: the cuff doses her", Hymn.dosed_today and Hymn.level > before and not run_node.hud.cuff_label.visible, Hymn.level)

	# The clarity visor: her view crowded with orders.
	Hymn.gear.append("visor")
	var visor: CanvasLayer = run_node.get_node("VisorScreen")
	await _ticks(int(Engine.physics_ticks_per_second * 1.5))
	_check("the visor clutters her view", visor.strength() > 0.0 and visor._draw_on.visible and not visor._words.is_empty(), visor._words.size())
	run_node.open_bench("dispensary")
	await _ticks(2)
	_check("not over a screen", visor.strength() == 0.0, visor.strength())
	run_node.close_bench()

	# The rest of the set: each capture the next piece, in order, each on her.
	Hymn.gear = ["headphones", "cuff", "visor"]
	for want in ["bridge", "gloves", "spine", "bell"]:
		_check("next capture: %s" % want, Hymn.processed() == want, Hymn.gear)
	Wardrobe.dress_eco(player, true)
	await _ticks(2)
	for part in ["bridge", "UpperL", "HandR", "Seg_0", "Seg_8", "Bell"]:
		_check("%s on her" % part, player.find_child(part, true, false) != null, part)
	_check("gloves: numb hands, slower reloads", Hymn.reload_scale() == Hymn.RELOAD_SLOW, Hymn.reload_scale())
	_check("spine: a heavier step", Hymn.speed_scale() == Hymn.SPINE_SPEED, Hymn.speed_scale())
	Hymn.level = 50.0
	Hymn._puff = Hymn.BRIDGE_EVERY
	before = Hymn.level
	_check("bridge: a puff a minute", not Hymn.tick_bridge(Hymn.BRIDGE_EVERY * 0.5) and Hymn.tick_bridge(Hymn.BRIDGE_EVERY * 0.6) and Hymn.level > before, Hymn.level)
	# first person: her full copy only casts shadows, so its gear mustn't hang in view
	var shadow_copy: Node = player.get_node("EcoBody/Shadow")
	var floating := shadow_copy.find_child("ColonyGear*", true, false).find_children("*", "MeshInstance3D", true, false).filter(func(m): return m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	_check("first person: no gear floating in view", floating.is_empty(), floating.size())
	# the bell: rings moving fast, enemies near hear it, slow she's quiet
	_check("bell quiet walking", not Hymn.tick_bell(1.0, 2.0), "")
	_check("bell rings running", Hymn.tick_bell(1.0, 8.0) and not Hymn.tick_bell(0.1, 8.0) and Hymn.tick_bell(1.0, 8.0), "")
	_check("nothing left to put on her", Hymn.processed() == "", Hymn.gear.size())

	# Biggie's table: one try a visit; a clean job takes it off, a slip shocks her.
	Hymn.gear = ["headphones", "visor"]
	Hymn.biggie_tried = false
	Hymn.level = 30.0
	run_node.open_bench("gear_off")
	await _ticks(2)
	var table: CanvasLayer = run_node.bench
	_check("Biggie's table opens", table != null and table.kind == "gear_off" and table.can_try(), table)
	table.pick("headphones")
	_check("his band is narrower for the visor", Hymn.steady("visor") < Hymn.steady("headphones"), [Hymn.steady("visor"), Hymn.steady("headphones")])
	for i in Hymn.HOLDS:
		table._at = 0.5
		table.hold_now()
	_check("three clean holds: the headphones are off", not ("headphones" in Hymn.gear) and table.removed == "headphones", Hymn.gear)
	await _until(func(): return run_node.bench == null, 4.0)
	await _ticks(2)
	_check("and off her model", player.find_child("Cup_L", true, false) == null, player.find_child("Cup_L", true, false))
	run_node.open_bench("gear_off")
	await _ticks(2)
	_check("once a visit", not run_node.bench.can_try(), Hymn.biggie_tried)
	run_node.close_bench()
	Hymn.biggie_tried = false
	before = Hymn.level
	run_node.open_bench("gear_off")
	await _ticks(2)
	table = run_node.bench
	table.pick("visor")
	table._at = 0.05
	table.hold_now()
	_check("a slip: it stays on and shocks her", "visor" in Hymn.gear and Hymn.level == before + Hymn.SLIP and table.slipped == "visor", [Hymn.gear, Hymn.level])
	await _until(func(): return run_node.bench == null, 4.0)
	Hymn.run_over()
	_check("another try after the next run", not Hymn.biggie_tried, Hymn.biggie_tried)

	# A new day after a run; Teen: none of it.
	Hymn.run_over()
	_check("a run over: tomorrow's dose waiting", not Hymn.dosed_today, Hymn.dosed_today)
	ContentRating.set_rating("T", false)
	_check("teen: no Hymn, no gear", not Hymn.allowed() and not Hymn.has("visor") and visor.strength() == 0.0, Hymn.allowed())
	ContentRating.set_rating("M", false)
	Hymn.reset()
	Hymn.save()

	print("hymn_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _place(pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO


func _press(action: String) -> void:
	await physics_frame
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _until(ok: Callable, seconds: float) -> void:
	var left := int(Engine.physics_ticks_per_second * seconds)
	while left > 0 and not ok.call():
		await physics_frame
		left -= 1


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
