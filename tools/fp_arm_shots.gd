extends SceneTree
## Quick shots of Eco's first-person arm on the gun (scripts/eco_fp_arms.gd),
## without loading a level: the player's view, and the rig from the side and
## from above with her full model stood where her first-person body would be
## (neck under the camera, as scripts/eco_fp_body.gd places it), to check the
## arm comes out of her shoulder.
##   xvfb-run -a godot --path . -s res://tools/fp_arm_shots.gd -- [out_dir] [--outfit=suit_ghost] [--tier=3]
## Needs a renderer (not --headless).

const Art := preload("res://scripts/ps2/ps2_assets.gd")
const EcoArms := preload("res://scripts/eco_fp_arms.gd")
const ECO := preload("res://assets/models/eco.tscn")
const Weapon := preload("res://scripts/weapon.gd")

var out := "user://fp_arm_shots"
var outfit := "suit"
var tier := 0
## --pos=x,y,z tries another gun spot (camera space) instead of weapon.gd VIEW_POS.
var gun_pos := Weapon.VIEW_POS


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--outfit="):
			outfit = a.trim_prefix("--outfit=")
		elif a.begins_with("--tier="):
			tier = int(a.trim_prefix("--tier="))
		elif a.begins_with("--pos="):
			var p := a.trim_prefix("--pos=").split_floats(",")
			gun_pos = Vector3(p[0], p[1], p[2])
		elif not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(shot_name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join(shot_name + ".png"))
	print("shot ", shot_name)


func _go() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.75)
	env.environment.ambient_light_energy = 0.8
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(20, 20)
	world.add_child(floor_mesh)

	# her full model stood so her neck is under the eye, as the player's is
	var eco := ECO.instantiate()
	world.add_child(eco)
	eco.set("idle_motion", false)
	eco.wear(outfit)
	eco.suit_tier = tier
	await _frames(2)
	var sk: Skeleton3D = eco.skeleton
	var neck := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("J_Bip_C_Neck")).origin
	var eye := neck + Vector3(0, 0.17, -0.1)

	var cam := Camera3D.new()
	cam.fov = 90.0
	world.add_child(cam)
	cam.global_position = eye
	var view := Node3D.new()
	cam.add_child(view)
	view.position = gun_pos
	var pistol := Art.model("pistol")
	view.add_child(pistol)
	var old := pistol.get_node_or_null("Arm")
	if old != null:
		old.free()
	var arm := EcoArms.new()
	arm.name = "Arm"
	arm.gun_at = gun_pos
	pistol.add_child(arm)
	arm.follow(eco)
	cam.current = true
	eco.visible = false
	await _frames(10)
	_save("a_view")
	eco.visible = true
	var side := Camera3D.new()
	side.fov = 40.0
	world.add_child(side)
	side.look_at_from_position(eye + Vector3(1.8, -0.2, -0.3), eye + Vector3(0, -0.2, -0.2))
	side.current = true
	await _frames(3)
	_save("b_side")
	side.look_at_from_position(eye + Vector3(0.3, 1.6, -0.2), eye + Vector3(0.1, -0.2, -0.2), Vector3.FORWARD)
	await _frames(3)
	_save("c_top")
	side.look_at_from_position(eye + Vector3(0.5, -0.1, -1.2), eye + Vector3(0.15, -0.2, -0.3))
	await _frames(3)
	_save("d_front")
	# close-ups of her grip, from her right and her left
	eco.visible = false
	var g := pistol.global_transform
	side.fov = 30.0
	side.look_at_from_position(g * Vector3(0.45, 0.05, 0.05), g * Vector3(0, -0.05, 0.05))
	await _frames(3)
	_save("e_grip_right")
	side.look_at_from_position(g * Vector3(-0.45, 0.05, 0.05), g * Vector3(0, -0.05, 0.05))
	await _frames(3)
	_save("f_grip_left")
	quit()
