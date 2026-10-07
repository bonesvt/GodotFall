extends SceneTree
## Screenshots of the workbenches, their screens, the guns in hand and the
## loot out in the forest, for checking the look.
##   xvfb-run -a godot --path . -s res://tools/hub/bench_shots.gd -- [out_dir] [gunsmith|knives]
## "gunsmith" shoots only the gunsmith screen (much quicker); "knives" only the
## knife case, its screen and each knife in her hand.
## Needs a renderer (not --headless). Uses its own armory save, stocked up.

const Armory := preload("res://scripts/hub/armory.gd")
const PATH := "user://shots_armory.cfg"

var run_node
var out := "user://bench_shots"
var only_gunsmith := false
var only_knives := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	only_gunsmith = "gunsmith" in args
	only_knives = "knives" in args
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var a = Armory.open(PATH)
	a.stash = {"scrap": 2000, "alloy": 400, "circuits": 80, "lock_cores": 6}
	a.fit("rivet_cannon", "muzzle", "compensator")
	a.fit("rivet_cannon", "grip", "skeleton")
	a.set_finish("rivet_cannon", "midnight")
	a.fit("smart_pistol", "muzzle", "long_barrel")
	a.fit("smart_pistol", "mag", "extended")
	a.buy_refit("kit", "scrap")  # level 2: the hand cannon is one upgrade off
	a.set_start_part("chassis", "atlas")
	a.set_start_part("weapon", "xo16")
	a.equip("smart_pistol")
	root.size = Vector2i(1600, 900)
	# No tutorial cards in the shots, and none marked seen on your save.
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	run_node.armory_path = PATH
	root.add_child(run_node)
	_go.call_deferred()


func _go() -> void:
	if run_node.tutorial != null:
		run_node.tutorial.set_enabled(false)
	await _frames(20)
	if only_gunsmith:
		await _gunsmith_shots()
		quit()
		return
	if only_knives:
		await _knife_shots()
		quit()
		return
	await _shot("1-gunsmith-bench", Vector3(8.2, 1.2, 1.2), Vector3(11, 2.0, 0.4))
	await _shot("2-weapon-rack", Vector3(8.0, 1.2, -3.4), Vector3(11, 2.5, -3.4))
	await _shot("3-workshop", Vector3(-13, 0.2, 33), Vector3(-16, 3.5, 47))
	await _gunsmith_shots()
	run_node.open_bench("rack")
	run_node.bench.select(1)
	await _frames(12)
	await _save("6-screen-rack-locked")
	run_node.close_bench()
	run_node.open_bench("workshop")
	await _frames(12)
	await _save("7-screen-workshop")
	# Refits level Eco up: 3 unlocks the hand cannon, 6 the auto handgun.
	run_node.bench.switch_tab(1)
	run_node.bench.select(0)
	run_node.bench.confirm()
	await _frames(8)
	await _save("8-screen-refits-level-3")
	run_node.bench.confirm()
	run_node.bench.confirm()
	run_node.bench.select(1)
	run_node.bench.confirm()
	await _frames(8)
	await _save("8b-screen-refits-level-6")
	run_node.close_bench()
	await _frames(4)
	await _shot("8c-weapon-rack-unlocked", Vector3(8.0, 1.2, -3.4), Vector3(11, 2.5, -3.4))
	run_node.open_bench("rack")
	run_node.bench.select(1)
	await _frames(12)
	await _save("6b-screen-rack-unlocked")
	run_node.close_bench()
	# Guns in hand.
	for id in ["rivet_cannon", "machine_pistol"]:
		run_node.armory.equip(id)
		run_node.equip_loadout()
		await _shot("9-hand-" + id, Vector3(-20, 0.2, 10), Vector3(-30, 1.4, 10))
	# Smart rounds half done (what 6 lock cores buy), then fully upgraded: its
	# tier 5 model, in hand and on the bench.
	while run_node.armory.buy_upgrade("smart_pistol", "smart_rounds"):
		pass
	run_node.armory.equip("smart_pistol")
	run_node.equip_loadout()
	run_node.open_bench("gunsmith")
	await _frames(12)
	await _save("4a-screen-smart-rounds")
	run_node.close_bench()
	run_node.armory.stash["lock_cores"] = 40
	while run_node.armory.buy_upgrade("smart_pistol", "smart_rounds"):
		pass
	run_node.armory.equip("smart_pistol")
	run_node.equip_loadout()
	await _shot("9-hand-smart_pistol-tier5", Vector3(-20, 0.2, 10), Vector3(-30, 1.4, 10))
	run_node.open_bench("gunsmith")
	await _frames(12)
	await _save("4b-screen-gunsmith-tier5")
	run_node.close_bench()
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
	# A smart round locked on a grunt, a few dumb rounds left under the smart ones.
	var spawn: Vector3 = run_node.zone_info["spawn"]
	var mark = run_node.zone_info["grunts"][1]
	mark.passive = true
	mark.set_physics_process(false)  # stand still for the picture
	var forward := Vector3(-1, 0, 0)
	mark.global_position = spawn + forward * 9.0
	var weapon = run_node.player.get_node("Head/Camera3D/Weapon")
	weapon.smart_left = 6
	weapon.ammo = 9
	await _shot("13-smart-lock", spawn, spawn + forward * 9.0 + Vector3(0, 1.4, 0.9), false)
	await _frames(50)
	await _save("13-smart-lock")
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


## The knife case by the door, its screen, and each knife in her hand: held
## ready, and caught mid-flip on the draw (the Butterfly's handle swings open).
func _knife_shots() -> void:
	await _shot("k1-knife-case", Vector3(7.4, 1.2, 7.0), Vector3(10.6, 1.9, 4.0))
	await _shot("k2-knife-case-close", Vector3(9.25, 1.2, 4.8), Vector3(10.6, 2.0, 4.8))
	run_node.open_bench("knives")
	run_node.bench.select(1)
	await _frames(12)
	await _save("k3-screen-knife-case")
	run_node.close_bench()
	var knife = run_node.player.get_node("Head/Camera3D/Knife")
	var weapon = run_node.player.get_node("Head/Camera3D/Weapon")
	for id in run_node.Armory.KNIVES:
		run_node.armory.set_knife(id)
		run_node.equip_loadout()
		knife.set_physics_process(false)
		knife.set_process(false)
		knife.draw_knife()
		knife._ready_blend = 1.0
		for pose in [["ready", "", 0.0], ["attack", "attack_a", knife.hit_time], ["show", "inspect", 0.5]]:
			knife.anim = pose[1]
			knife.anim_time = pose[2]
			knife._process(0.0)
			await _shot("k4-hand-%s-%s" % [id, pose[0]], Vector3(-20, 0.2, 10), Vector3(-30, 1.4, 10))
		knife.anim = ""
		knife.put_away()
		knife.set_process(true)
		knife.set_physics_process(true)
	run_node.armory.set_knife("needle")
	run_node.equip_loadout()


## The gunsmith: the pistol in 3D with its part markers, a part picked, a
## locked grip tried on, then the other two guns once a level up unlocks them.
func _gunsmith_shots() -> void:
	run_node.open_bench("gunsmith")
	await _frames(12)
	await _save("4-screen-gunsmith")
	run_node.bench.select_part("muzzle")
	run_node.bench._yaw += 0.9
	await _frames(8)
	await _save("5-screen-gunsmith-muzzle")
	run_node.bench.select_part("grip")
	run_node.bench.choose(run_node.bench.options.map(func(o): return o["id"]).find("wrap"))
	run_node.bench._yaw -= 1.6
	run_node.bench._pitch = 0.25
	await _frames(8)
	await _save("5a-screen-gunsmith-grip-preview")
	run_node.close_bench()
	var a = run_node.armory
	var saved: Dictionary = a.refits.duplicate(true)
	a.refits["shot:levels"] = 6  # level 7 for the shots, put back after
	run_node.open_bench("gunsmith")
	a.buy_upgrade("rivet_cannon", "punch_through")
	a.buy_upgrade("machine_pistol", "hot_streak")
	run_node.bench.select_weapon("rivet_cannon")
	run_node.bench.select_part("barrel")
	await _frames(12)
	await _save("5b-screen-gunsmith-revolver")
	run_node.bench.select_weapon("machine_pistol")
	run_node.bench.select_part("barrel")
	await _frames(12)
	await _save("5c-screen-gunsmith-auto-handgun")
	run_node.close_bench()
	a.refits = saved


func _frames(n: int) -> void:
	for i in n:
		await process_frame
