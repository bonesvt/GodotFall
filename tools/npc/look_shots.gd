extends SceneTree
## Close-ups of the hub people (and Eco, as "eco") on a bare set, for checking
## their look (npc_look.gd, eco_toon.gdshaderinc) without building the hub:
## each one from the front and three-quarters, in the hub's sun and under a
## room lamp.
##   xvfb-run -a godot --audio-driver Dummy --path . -s res://tools/npc/look_shots.gd -- [out_dir] [who,who,...] [outfit]
## Needs a renderer (not --headless).

const Kit := preload("res://scripts/run/level_kit.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")

var out := "user://look_shots"
var whos := ["ophelia", "mom", "biggie", "town_rosa"]
var outfit := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		whos = Array(args[1].split(","))
	if args.size() > 2:
		outfit = args[2]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(720, 900)
	_go.call_deferred()


func _go() -> void:
	var set_ := Node3D.new()
	root.add_child(set_)
	# the hub's sky, ambient and sun (hub_builder.gd)
	Kit.environment(set_, Color(0.28, 0.5, 0.72), Color(0.78, 0.84, 0.86))
	var sun: DirectionalLight3D
	for node in set_.get_children():
		if node is WorldEnvironment:
			node.environment.ambient_light_energy = 0.4
			node.environment.adjustment_saturation = 1.1
		elif node is DirectionalLight3D:
			sun = node
			sun.rotation_degrees = Vector3(-62, 20, 0)
			sun.light_energy = 1.35
			sun.shadow_opacity = 1.0
	var floor_ := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_.mesh = plane
	set_.add_child(floor_)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.62)
	lamp.light_energy = 2.4
	lamp.omni_range = 5.0
	lamp.omni_attenuation = 1.4
	lamp.shadow_enabled = true
	lamp.position = Vector3(-0.9, 2.2, 1.2)
	lamp.visible = false
	set_.add_child(lamp)
	var cam := Camera3D.new()
	cam.fov = 32.0
	set_.add_child(cam)
	cam.current = true
	for who in whos:
		var npc: Node3D
		if who == "eco":
			npc = load("res://assets/models/eco.tscn").instantiate()
			npc.rotation.y = PI
		else:
			npc = HubNpc.create(who, Vector3.ZERO, 180.0)
		set_.add_child(npc)
		await _frames(4)
		if outfit != "":
			npc.wear(outfit)
		var head := _head(npc)
		for light in ["sun", "lamp"]:
			sun.visible = light == "sun"
			lamp.visible = light == "lamp"
			for view in [["front", 0.0], ["three", 35.0]]:
				var yaw := deg_to_rad(view[1])
				var dir := Vector3(sin(yaw), 0, cos(yaw))   # turned (180) to face +z
				# the whole of them, then their face
				cam.look_at_from_position(Vector3(0, 0.95, 0) + dir * 3.7, Vector3(0, 0.86, 0))
				await _frames(10)
				await _save("%s-%s-%s-full" % [who, light, view[0]])
				cam.look_at_from_position(head + dir * 0.95 - Vector3(0, 0.06, 0), head - Vector3(0, 0.12, 0))
				await _frames(6)
				await _save("%s-%s-%s-face" % [who, light, view[0]])
		npc.queue_free()
		await _frames(2)
	quit()


func _head(n: Node3D) -> Vector3:
	var skel := n.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel != null and skel.find_bone("J_Bip_C_Head") >= 0:
		return skel.global_transform * skel.get_bone_global_pose(skel.find_bone("J_Bip_C_Head")).origin + Vector3(0, 0.08, 0)
	return n.global_position + Vector3(0, 1.45, 0)


func _save(name: String) -> void:
	await _frames(2)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
