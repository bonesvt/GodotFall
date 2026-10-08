extends SceneTree
## The dose cuff's Hymn bell (hymn.gd tick_bell, colony_gear.gd): it hangs off
## the cuff, rings when she sprints or lands from a fall, not when she walks,
## not without the cuff, and not on Teen. Mature only.
##   godot --headless --path . --audio-driver Dummy -s res://tests/bell_test.gd

const Hymn := preload("res://scripts/hub/hymn.gd")
const ColonyGear := preload("res://scripts/hub/colony_gear.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	ContentRating.set_rating("M", false)
	_run.call_deferred()


func _run() -> void:
	Hymn.reset()
	_check("no cuff, no bell", not Hymn.tick_bell(0.1, 11.0, true))
	Hymn.gear = ["headphones", "cuff"]
	_check("walking: quiet", _ticks(3.0, 7.0, true) == 0)
	_check("sprinting: it rings", _ticks(0.5, 10.5, true) >= 1)
	var rings := _ticks(5.0, 10.5, true)
	_check("about once a second while she sprints", rings >= 4 and rings <= 5, rings)
	Hymn.reset()
	Hymn.gear = ["cuff"]
	_ticks(0.2, 0.0, false)  # a hop
	_check("a short hop lands quiet", _ticks(0.02, 0.0, true) == 0)
	_ticks(0.8, 0.0, false)  # a fall
	_check("a fall lands with a ring", _ticks(0.02, 0.0, true) == 1)

	_check("it has its sound", preload("res://scripts/sfx.gd").stream("hymn_bell") != null)

	var eco: Node = load("res://assets/models/eco.tscn").instantiate()
	root.add_child(eco)
	await process_frame
	ColonyGear.apply(eco, ["cuff"])
	_check("the bell hangs off the cuff", eco.find_child("Bell", true, false) != null)
	_check("no collar: nothing on her neck", eco.find_children("*", "BoneAttachment3D", true, false).all(
		func(a): return a.bone_name != "J_Bip_C_Neck"))

	ContentRating.set_rating("T", false)
	_check("Teen: no bell", not Hymn.tick_bell(2.0, 11.0, true))
	ContentRating.set_rating("M", false)
	Hymn.reset()
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


## Ticks the bell for `seconds` at speed; how many times it rang.
func _ticks(seconds: float, speed: float, grounded: bool) -> int:
	var n := 0
	var t := 0.0
	while t < seconds - 0.0001:
		if Hymn.tick_bell(1.0 / 60.0, speed, grounded):
			n += 1
		t += 1.0 / 60.0
	return n


func _check(what: String, ok: bool, detail = null) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + what + ("" if ok else "  (%s)" % str(detail)))
