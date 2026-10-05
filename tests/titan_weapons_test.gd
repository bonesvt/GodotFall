extends SceneTree
## Each titan weapon fires in its own rhythm (titan_gun.gd), but must still
## deal its part's damage per second. Holds the trigger on a target for a few
## seconds per weapon and compares.
## Run: godot --headless --path . -s res://tests/titan_weapons_test.gd

const Titan := preload("res://scripts/run/titan.gd")
const TitanParts := preload("res://scripts/run/titan_parts.gd")
const Kit := preload("res://scripts/run/level_kit.gd")

const SECONDS := 4.0

var failures := 0


class Dummy extends Node3D:
	var dealt := 0.0

	func take_damage(amount: float) -> void:
		dealt += amount


func _initialize() -> void:
	if not InputMap.has_action("titan_fire"):
		InputMap.add_action("titan_fire")
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	Kit.box(world, Vector3(0, -0.5, 0), Vector3(200, 1, 200), Color(0.5, 0.5, 0.5))
	# The target's collider sits under the node that takes the damage, like the
	# enemy titan and the hub's practice dummies.
	var dummy := Dummy.new()
	world.add_child(dummy)
	var target := Kit.box(dummy, Vector3(0, 4.5, -40), Vector3(8, 9, 8), Color(0.6, 0.2, 0.2))
	target.add_to_group("titan_target")

	for weapon in TitanParts.CATALOG["weapon"] + [TitanParts.SCRAP["weapon"]]:
		var part := TitanParts.make_part("weapon", weapon, 1)
		var parts := {"weapon": part}
		dummy.dealt = 0.0
		var titan := Titan.new()
		titan.setup(TitanParts.assemble(parts))
		titan.stats["ramp"] = 0.0  # measure base damage, not the Splitter's ramp
		titan.parts = parts
		titan.boss = dummy
		world.add_child(titan)
		titan.global_position = Vector3(0, 0.1, 0)
		titan.dropping = false
		titan.piloted = true
		await _ticks(10)
		Input.action_press("titan_fire")
		await _ticks(int(SECONDS * 120))
		Input.action_release("titan_fire")
		var dps := dummy.dealt / SECONDS
		var want: float = part["dps"]
		# The Obelisk Rail loses a little to its stalls; everything else stays close.
		var low := 0.8 if weapon["id"] == "scrap" else 0.9
		_check("%s keeps its damage per second" % weapon["name"], dps > want * low and dps < want * 1.1, "%.0f of %.0f" % [dps, want])
		_check("%s shows shots" % weapon["name"], titan.gun.shots > 0, titan.gun.shots)
		titan.queue_free()
		await _ticks(5)

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
