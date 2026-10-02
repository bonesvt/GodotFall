extends SceneTree
## Side views of every sidearm, stock and with attachments and finishes, for
## checking the models.
##   xvfb-run -a godot --path . -s res://tools/pistol/sidearm_sheet.gd -- out.png
## Needs a renderer (not --headless).

const Weapon := preload("res://scripts/weapon.gd")
const Armory := preload("res://scripts/hub/armory.gd")

const ROWS := [
	["smart_pistol", {}, "dads"],
	["smart_pistol", {"muzzle": "long_barrel", "mag": "extended", "grip": "wrap"}, "bubblegum"],
	["rivet_cannon", {}, "dads"],
	["rivet_cannon", {"muzzle": "compensator", "mag": "speed", "grip": "skeleton"}, "midnight"],
	["machine_pistol", {}, "dads"],
	["machine_pistol", {"muzzle": "compensator", "mag": "extended", "grip": "wrap"}, "jungle"],
]


func _initialize() -> void:
	var out := "user://sidearms.png"
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.15, 0.18)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -60, 0)
	world.add_child(sun)
	for i in ROWS.size():
		var row: Array = ROWS[i]
		var profile: Dictionary = Armory.WEAPONS[row[0]].duplicate()
		profile["attachments"] = row[1]
		profile["finish"] = Armory.finish(row[2])
		var gun := Weapon.gun_model(profile)
		world.add_child(gun)
		gun.position = Vector3((i % 2) * 0.42 - 0.21, 0.42 - (i / 2) * 0.3, 0)
		gun.rotation_degrees = Vector3(0, 90, 0)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.95
	cam.position = Vector3(0, 0.12, 2)
	world.add_child(cam)
	cam.make_current()
	root.size = Vector2i(1400, 1400)
	_save.call_deferred(out)


func _save(out: String) -> void:
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	print("wrote ", out)
	quit()
