extends SceneTree
## Headless test for the tutorial hints (scripts/run/tutorial.gd).
## Run: godot --headless --path . -s res://tests/tutorial_test.gd

const Tutorial := preload("res://scripts/run/tutorial.gd")
const SETTINGS := "user://test_tutorial_settings.cfg"

var run_node
var tut
var failures := 0


func _initialize() -> void:
	Tutorial.settings_path = SETTINGS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	run_node.start_in_hub = false
	run_node.armory_path = "user://test_tutorial_armory.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_node.armory_path))
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(10)
	tut = run_node.tutorial
	var player = run_node.player
	var info: Dictionary = run_node.zone_info
	_check("tutorial is on for a fresh save", tut.enabled and tut.level == "zone0", tut.level)

	# The first alloy node and crate sit in the clearing by the spawn.
	var node = tut._first_loot(true)
	var crate = tut._first_loot(false)
	_check("first alloy node by the spawn", node != null and node.global_position.distance_to(info["spawn"]) < 12.0, node.global_position if node else null)
	_check("first crate by the spawn", crate != null and crate.global_position.distance_to(info["spawn"]) < 12.0, crate.global_position if crate else null)

	await _wait_for("welcome", 3.0)
	_check("welcome card shows first", tut.current.get("id", "") == "welcome" and tut._card.visible, tut.current.get("id", ""))

	# Skip ahead: the node is in view from the spawn, so its card comes next.
	tut._shown_for = 99.0
	await _wait_for("alloy_node", 2.0)
	_check("alloy node card", tut.current.get("id", "") == "alloy_node", tut.current.get("id", ""))
	var outlined := _meshes(node).filter(func(m): return m.material_overlay != null)
	_check("alloy node is outlined", outlined.size() > 0 and outlined.size() == _meshes(node).size(), "%d/%d" % [outlined.size(), _meshes(node).size()])
	_check("alloy node is tagged", node.find_children("*", "Label3D", true, false).any(func(l): return "ALLOY NODE" in l.text), "")
	_check("card says what it's for", "workshop" in tut._body.text and "[lb]F[rb]" in tut._body.text, tut._body.text)

	# Mine it out: the card and the outline go once it's done.
	player.global_position = node.global_position + Vector3(2.0, 0.5, 0)
	var got: Dictionary = node.mine(5.0)
	_check("mined", node.depleted and got.has("alloy"), got)
	run_node.tutorial.event("loot")
	tut._shown_for = 99.0
	await _ticks(4)
	_check("outline removed once mined", _meshes(node).all(func(m): return m.material_overlay == null), "")
	await _wait_for("materials", 2.0)
	_check("materials card after loot spills", tut.current.get("id", "") == "materials", tut.current.get("id", ""))

	# Seen hints stick to the save.
	var again := Tutorial.new()
	again._load()
	_check("seen hints are saved", again.seen.has("welcome") and again.seen.has("alloy_node") and again.seen.has("materials"), again.seen.keys())
	again.free()

	# F1 off hides the card and nothing new shows.
	tut.set_enabled(false)
	_check("off hides the card", not tut._card.visible and tut.current.is_empty(), "")
	player.global_position = crate.global_position + Vector3(1.5, 0.5, 0)
	await _ticks(20)
	_check("off shows nothing", tut.current.is_empty(), tut.current.get("id", ""))
	var off := Tutorial.new()
	off._load()
	_check("off is saved", not off.enabled, off.enabled)
	off.free()
	tut.set_enabled(true)
	await _wait_for("supply_crate", 2.0)
	_check("crate card when close", tut.current.get("id", "") == "supply_crate", tut.current.get("id", ""))

	# A fall is urgent: it replaces whatever is up.
	tut.event("fell")
	await _ticks(3)
	_check("fall card is urgent", tut.current.get("id", "") == "fall", tut.current.get("id", ""))

	# The ravine: all four ways over light up.
	tut._finish()
	var lip: Vector3 = info["crossing"]["lip"]
	_check("ravine targets", tut._crossing_targets(["wallrun", "grapple", "pillars", "log"]).size() >= 5, "")
	_mark_seen_except(["ravine"])
	player.global_position = lip + Vector3(0, 0.5, 0)
	await _wait_for("ravine", 2.0)
	_check("ravine card at the lip", tut.current.get("id", "") == "ravine", tut.current.get("id", ""))
	var grapple: Node3D = info["crossing"]["grapple"][0]
	_check("grapple anchor outlined", _meshes(grapple).all(func(m): return m.material_overlay != null), "")

	# Zones 2 and 3 carry their own beats and crossings.
	for z in [1, 2]:
		run_node.load_zone(z)
		await _ticks(5)
		var cr: Dictionary = run_node.zone_info.get("crossing", {})
		_check("zone %d crossing pieces" % (z + 1), cr.get("wallrun", []).size() > 0 and cr.get("grapple", []).size() == 1 and cr.get("pillars", []).size() >= 2 and cr.get("log", []).size() > 0, cr.keys())
		_check("zone %d beats" % (z + 1), tut.level == "zone%d" % z and tut.beats.size() >= 6, tut.beats.size())
		var ids: Array = tut.beats.map(func(b): return b["id"])
		_check("zone %d teaches something new" % (z + 1), ("knife" in ids and "routes" in ids) if z == 1 else ("titan_build" in ids and "wallrun" in ids), ids)
	_mark_seen_except(["wallrun"])
	run_node.player.global_position = run_node.zone_info["crossing"]["lip"] + Vector3(0, 0.5, 0)
	await _wait_for("wallrun", 2.0)
	_check("boneyard wallrun card", tut.current.get("id", "") == "wallrun", tut.current.get("id", ""))

	# The arena teaches the titan.
	run_node.load_zone(3)
	await _ticks(5)
	_check("arena beats", tut.level == "arena" and tut.beats.map(func(b): return b["id"]).has("call_titan"), tut.level)

	# Shift+F1 forgets everything.
	tut.reset_seen()
	_check("reset forgets seen hints", tut.seen.is_empty(), tut.seen.size())

	print("\n%s: %d failure(s)" % ["PASSED" if failures == 0 else "FAILED", failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	quit(1 if failures > 0 else 0)


func _mark_seen_except(keep: Array) -> void:
	for b in tut.beats:
		if not b["id"] in keep:
			tut.seen[b["id"]] = true
	tut._finish()


func _wait_for(id: String, seconds: float) -> void:
	var left := int(seconds * 120)
	while left > 0 and tut.current.get("id", "") != id:
		await physics_frame
		left -= 1


func _meshes(n: Node) -> Array:
	return tut._meshes(n).filter(func(m): return not m.has_meta("ring"))


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
