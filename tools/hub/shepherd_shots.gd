extends SceneTree
## Stills of Hymn in town (hymn.gd): the Shepherd coming up Lantern Row at
## Eco, the Shepherd close, Eco by the dispensary in all three pieces of its
## gear, and her first-person view through the clarity visor while one of its
## words has her (visor_screen.gd).
##   godot --path . --resolution 1280x720 -s res://tools/hub/shepherd_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/shepherd_gear.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const Shepherd := preload("res://scripts/hub/shepherd.gd")
const CELL := Vector2i(960, 540)

var out := "user://shepherd_shots"
var sheet: Image
var shot := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	var run_node: Node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_hymn_armory.cfg"
	root.add_child(run_node)
	_go.call_deferred(run_node)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab() -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(CELL.x, CELL.y)
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (shot % 2), CELL.y * (shot / 2)))
	print("shot ", shot)
	shot += 1


func _go(run_node: Node) -> void:
	await _frames(90)
	Vices.reset()
	Hymn.reset()
	sheet = Image.create(CELL.x * 2, CELL.y * 2, false, Image.FORMAT_RGBA8)
	var player: Node3D = run_node.player
	run_node.hush_pull.triggers._next = INF
	var kiosk: Vector3 = run_node._dispensary_spot()
	var eco_at := kiosk + Vector3(2.2, 0.05, 1.0)
	run_node.place_player(eco_at)
	player.rotation.y = PI  # facing +Z, up the street
	var view: Node = player.get_node_or_null("ViewCam")
	if view != null:
		view.set_third_person(true)
	run_node.hud.visible = false
	run_node.pilot_hud.visible = false
	# the Shepherd, up the street, coming for her
	Hymn.hunted = true
	var shep: CharacterBody3D = Shepherd.create(run_node, eco_at + Vector3(0.6, 0.1, 7.0))
	run_node.zone_root.add_child(shep)
	shep.set_physics_process(false)
	shep.rotation.y = 0.0  # facing -Z, at her
	var cam := Camera3D.new()
	run_node.zone_root.add_child(cam)
	cam.fov = 50
	cam.look_at_from_position(eco_at + Vector3(-0.9, 1.7, -2.4), eco_at + Vector3(0.4, 1.3, 6.0))
	cam.make_current()
	await _frames(30)
	_grab()
	# the Shepherd, close
	cam.fov = 35
	cam.look_at_from_position(shep.global_position + Vector3(-1.4, 1.6, -3.2), shep.global_position + Vector3(0, 1.4, 0))
	await _frames(15)
	_grab()
	shep.queue_free()
	# Eco by the dispensary in all its gear
	Hymn.gear = Hymn.GEAR.duplicate()
	run_node.Wardrobe.dress_eco(player, true)
	player.rotation.y = -PI * 0.75  # three-quarter from behind: the spine and gloves show
	await _frames(5)
	cam.fov = 30
	cam.look_at_from_position(eco_at + Vector3(2.6, 1.5, 1.3), eco_at + Vector3(0, 1.2, 0))
	await _frames(20)
	_grab()
	# through the visor, first person, while one of its words has her
	cam.queue_free()
	if view != null:
		view.set_third_person(false)
	player.rotation.y = PI
	player.get_node("Head/Camera3D").make_current()
	run_node.hud.visible = true
	run_node.pilot_hud.visible = true
	run_node.hush_pull.triggers.fire(false, true)
	await _frames(70)
	_grab()
	sheet.save_png(out.path_join("shepherd_gear.png"))
	print("wrote shepherd_gear.png")
	Hymn.reset()
	Hymn.save()
	quit()
