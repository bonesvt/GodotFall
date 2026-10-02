extends SceneTree
## Screenshots of the workbenches, their screens, the guns in hand and the
## loot out in the forest, for checking the look.
##   xvfb-run -a godot --path . -s res://tools/hub/bench_shots.gd -- [out_dir]
## Needs a renderer (not --headless). Uses its own armory save, stocked up.

const Armory := preload("res://scripts/hub/armory.gd")
const PATH := "user://shots_armory.cfg"

var run_node
var out := "user://bench_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var a = Armory.open(PATH)
	a.stash = {"scrap": 900, "alloy": 400, "circuits": 40}
	a.buy_weapon("rivet_cannon")
	a.buy_weapon("machine_pistol")
	a.fit("rivet_cannon", "muzzle", "compensator")
	a.fit("rivet_cannon", "grip", "skeleton")
	a.set_finish("rivet_cannon", "midnight")
	a.fit("smart_pistol", "muzzle", "long_barrel")
	a.fit("smart_pistol", "mag", "extended")
	a.buy_upgrade("smart_pistol", "calibre")
	a.set_start_part("chassis", "atlas")
	a.set_start_part("weapon", "xo16")
	a.equip("smart_pistol")
	root.size = Vector2i(1600, 900)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	run_node.armory_path = PATH
	root.add_child(run_node)
	_go.call_deferred()


func _go() -> void:
	await _frames(20)
	await _shot("1-gunsmith-bench", Vector3(8.2, 1.2, 1.2), Vector3(11, 2.0, 0.4))
	await _shot("2-weapon-rack", Vector3(8.0, 1.2, -3.4), Vector3(11, 2.5, -3.4))
	await _shot("3-workshop", Vector3(-13, 0.2, 33), Vector3(-16, 3.5, 47))
	run_node.open_bench("gunsmith")
	await _frames(12)
	await _save("4-screen-gunsmith-upgrades")
	run_node.bench.switch_tab(1)
	run_node.bench.select(0)
	run_node.bench.step(1)
	await _frames(12)
	await _save("5-screen-gunsmith-attachments")
	run_node.close_bench()
	run_node.open_bench("rack")
	run_node.bench.select(1)
	await _frames(12)
	await _save("6-screen-rack")
	run_node.close_bench()
	run_node.open_bench("workshop")
	await _frames(12)
	await _save("7-screen-workshop")
	run_node.bench.switch_tab(1)
	await _frames(8)
	await _save("8-screen-refits")
	run_node.close_bench()
	# Guns in hand.
	for id in ["rivet_cannon", "machine_pistol"]:
		run_node.armory.equip(id)
		run_node.equip_loadout()
		await _shot("9-hand-" + id, Vector3(-20, 0.2, 10), Vector3(-30, 1.4, 10))
	# Loot in the forest.
	run_node.start_run(1234)
	await _frames(20)
	var loot: Array = run_node.zone_info["loot"].filter(func(n): return is_instance_valid(n))
	var crate = loot.filter(func(n): return n.has_method("open"))[0]
	var node = loot.filter(func(n): return n.has_method("mine"))[0]
	await _shot("10-crate", crate.global_position + Vector3(2.2, 0.2, 2.2), crate.global_position + Vector3(0, 0.3, 0))
	crate.open()
	run_node.Loot.drop(run_node.zone_root, crate.global_position + Vector3(0, 0.4, 0), {"scrap": 9, "circuits": 2}, run_node.loot_rng)
	await _frames(25)
	await _shot("11-crate-open", crate.global_position + Vector3(2.6, 0.2, 2.6), crate.global_position + Vector3(0, 0.3, 0), false)
	await _shot("12-alloy-node", node.global_position + Vector3(-4.0, 0.6, 1.0), node.global_position + Vector3(0, 0.7, 0))
	quit()


func _shot(name: String, at: Vector3, look: Vector3, settle := true) -> void:
	var player = run_node.player
	player.global_position = at
	player.velocity = Vector3.ZERO
	var eye := at + Vector3(0, 1.6, 0)
	var d := look - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Head").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	if settle:
		await _frames(14)
	await _save(name)


func _save(name: String) -> void:
	await _frames(2)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
