extends SceneTree
## The detention collar (hymn.gd, shepherd.gd): while the Shepherd hunts her
## it pings where she is, its pulse locks her where she stands, and running
## from it stuns her. Biggie can get it off. Mature only.
##   godot --headless --path . -s res://tests/collar_test.gd

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

var run_node: Node
var player: CharacterBody3D
var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_collar_armory.cfg"
	for f in ["user://test_collar_armory.cfg", "user://test_collar_armory_vices.cfg", "user://test_collar_armory_hymn.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(60)
	player = run_node.player
	run_node.hush_pull.triggers._next = INF
	Vices.reset()
	Hymn.reset()
	_check("in the set, after the bell, before the Crown", Hymn.GEAR.find("collar") == Hymn.GEAR.find("bell") + 1 and Hymn.GEAR.back() == "crown", Hymn.GEAR)
	Hymn.gear = ["headphones", "cuff", "visor", "bridge", "gloves", "spine", "bell"]
	_check("the next capture puts it on", Hymn.processed() == "collar", Hymn.gear)
	Hymn.gear = ["bell", "collar"]
	preload("res://scripts/hub/wardrobe.gd").dress_eco(player, true)
	await _ticks(2)
	_check("on her, with its light", player.find_child("collar", true, false) != null and player.find_child("Light", true, false) != null, "")

	Hymn.hunted = true
	run_node.spawn_shepherd()
	await _ticks(2)
	var shep: CharacterBody3D = get_nodes_in_group("shepherd")[0]
	shep._dart_t = INF
	shep._pulse_t = INF
	# a ping tells it where she is, even out of sight
	shep._last_seen = Vector3(999, 0, 999)
	shep._ping_t = 0.0
	shep._collar(0.016, false, 30.0)
	_check("it pings where she is", shep._last_seen.distance_to(player.global_position) < 0.1, shep._last_seen)
	# its pulse locks her
	shep.pulse()
	_check("the pulse locks her", shep.locked() and player.entranced, player.entranced)
	await _until(func(): return not shep.locked(), Hymn.COLLAR_LOCK + 1.0)
	await _ticks(2)
	_check("then lets her go", not player.entranced, player.entranced)
	# running from it, in its sight and far off: a stun
	var before: float = shep.sedation
	player.velocity = Vector3(9, 0, 0)
	shep._stun_t = 0.05
	shep._collar(0.1, true, 20.0)
	_check("running from it: stunned", shep.locked() and shep.sedation > before and run_node.hud.toast_label.text.contains("collar bites"), run_node.hud.toast_label.text)
	shep._lock_left = 0.0
	shep._stun_t = 0.05
	player.velocity = Vector3(1, 0, 0)
	shep._collar(0.1, true, 20.0)
	_check("walking: no stun", not shep.locked(), shep._stun_t)
	shep.give_up()
	await _ticks(3)
	_check("lost her: nothing holds her", not player.entranced, player.entranced)

	# Biggie: the collar on his list
	Hymn.biggie_tried = false
	run_node.open_bench("gear_off")
	await _ticks(2)
	var table: CanvasLayer = run_node.bench
	_check("on Biggie's list", table._rows.has(["eco", "collar"]), table._rows)
	run_node.close_bench()

	Hymn.reset()
	Hymn.save()
	print("collar_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


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