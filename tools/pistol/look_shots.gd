extends SceneTree
## Side and three-quarter views of the hand weapons in a level's sky and sun
## (the hub's), for checking their look in the current look (Anime by
## default): every smart pistol tier, the machine pistol, the rivet cannon
## (stock and in a finish) and the three knives.
##   xvfb-run -a godot --audio-driver Dummy --path . -s res://tools/pistol/look_shots.gd -- [out_dir] [id,id,...]
## Needs a renderer (not --headless). Writes <out_dir>/<id>-side.png and -three.png.

const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const Weapon := preload("res://scripts/weapon.gd")
const Knife := preload("res://scripts/knife.gd")
const Armory := preload("res://scripts/hub/armory.gd")

## id: [model, finish id, is a knife]
const GUNS := {
	"pistol_t0": ["pistol", "", false],
	"pistol_t3": ["pistol_t3", "", false],
	"pistol_t5": ["pistol_t5", "", false],
	"pistol_t5_bubblegum": ["pistol_t5", "bubblegum", false],
	"machine_pistol": ["machine_pistol", "dads", false],
	"rivet_cannon": ["rivet_cannon", "dads", false],
	"rivet_cannon_midnight": ["rivet_cannon", "midnight", false],
	"needle": ["needle", "", true],
	"kunai": ["kunai", "", true],
	"butterfly": ["butterfly", "", true],
}

var out := "user://weapon_look_shots"
var ids: Array = GUNS.keys()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		ids = Array(args[1].split(","))
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1200, 700)
	_go.call_deferred()


func _go() -> void:
	var set_ := Node3D.new()
	root.add_child(set_)
	# the hub's sky, ambient and sun (hub_builder.gd)
	Kit.environment(set_, Color(0.3, 0.56, 0.88), Color(0.88, 0.9, 0.9))
	for node in set_.get_children():
		if node is WorldEnvironment:
			node.environment.ambient_light_energy = 0.4
			node.environment.fog_enabled = false
		elif node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-50, 60, 0)  # from behind its right shoulder
			node.light_energy = 1.35
	var cam := Camera3D.new()
	cam.fov = 24.0
	cam.near = 0.01
	set_.add_child(cam)
	cam.current = true
	for id in ids:
		var spec: Array = GUNS[id]
		var gun: Node3D
		if spec[2]:
			gun = Knife.knife_model(spec[0])
		else:
			gun = Art.model(spec[0])
			var arm := gun.get_node_or_null("Arm")
			if arm != null:
				arm.free()
			if spec[1] != "":
				for f in Armory.FINISHES:
					if f["id"] == spec[1]:
						Weapon._apply_finish(gun, f)
		set_.add_child(gun)
		await _frames(2)
		var box := _bounds(gun)
		var c := box.get_center()
		var reach := maxf(box.size.z, box.size.y * 1.8) * 0.45 / tan(deg_to_rad(cam.fov * 0.5))
		# side on from its right (the barrel, down -z, points right), then
		# from the front-right and above
		cam.look_at_from_position(c + Vector3(reach, 0, 0), c)
		await _frames(8)
		_save("%s-side" % id)
		cam.look_at_from_position(c + Vector3(0.8, 0.35, -0.5).normalized() * reach, c)
		await _frames(8)
		_save("%s-three" % id)
		gun.queue_free()
		await _frames(2)
	quit()


func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _save(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
