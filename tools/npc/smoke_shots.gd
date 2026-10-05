extends SceneTree
## Plays the back step smoking date (scripts/hub/smoke_date.gd) on its own, on
## a bare alley set, beat by beat as the dialogue would. With Godot's movie
## maker every frame is a fixed step, however slow the render:
##   xvfb-run -a godot --audio-driver Dummy --path . --rendering-driver opengl3 --resolution 800x450 \
##       --fixed-fps 10 --write-movie /tmp/smoke/f.png -s res://tools/npc/smoke_shots.gd -- [--from=kiss] [--only=kiss,exhale]
##   ffmpeg -framerate 10 -i /tmp/smoke/f%08d.png -pix_fmt yuv420p smoke.mp4

const SmokeDate := preload("res://scripts/hub/smoke_date.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

## [beat, seconds it gets], in the dialogue's order.
const PLAN := [["arrive", 1.5], ["pack", 2.2], ["light", 5.6], ["first", 6.4], ["pass", 7.0], ["short", 2.6],
	["hand_last", 2.2], ["last_drag", 4.8], ["kiss", 3.2], ["kiss_hold", 3.2], ["exhale", 2.6], ["after", 2.4]]

var scene: Node3D
var plan: Array = []
var _i := -1
var _left := 0.0


func _initialize() -> void:
	var from := ""
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			from = a.trim_prefix("--from=")
		elif a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(","))
	var started := from == ""
	for p in PLAN:
		if p[0] == from:
			started = true
		if started and (only.is_empty() or only.has(p[0])):
			plan.append(p)
	root.size = Vector2i(800, 450)
	_build.call_deferred()


func _build() -> void:
	var set := Node3D.new()
	root.add_child(set)
	Art.environment(set, Color(0.2, 0.17, 0.22), Color(0.42, 0.36, 0.44))
	for node in set.get_children():
		if node is WorldEnvironment:
			node.environment.fog_enabled = false
		if node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-35, 70, 0)
			node.light_energy = 0.8
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	ground.mesh = plane
	ground.material_override = Art.material("concrete")
	set.add_child(ground)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.2, 3.2, 6.0)
	wall.mesh = box
	wall.position = Vector3(-1.2, 1.6, 0)
	wall.material_override = Art.material("concrete", Color(0.55, 0.45, 0.42))
	set.add_child(wall)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-0.9, 2.4, 0.3)
	lamp.light_color = Color(1.0, 0.8, 0.6)
	lamp.light_energy = 1.6
	lamp.omni_range = 5.0
	set.add_child(lamp)
	var oph: Node3D = HubNpc.create("ophelia", Vector3(0, 0, -1), 0.0)
	set.add_child(oph)
	scene = SmokeDate.new()
	set.add_child(scene)
	scene.setup(oph, Vector3(0, 0, 0.31), Vector3(0, 0, -1), null, "y2k")


func _process(delta: float) -> bool:
	if scene == null:
		_left -= 1.0
		return _left < -50.0   # never built (a script error): don't record forever
	_left -= delta
	if _left <= 0.0:
		_i += 1
		if _i >= plan.size():
			return true   # quit
		scene.play(plan[_i][0])
		_left = float(plan[_i][1])
		print("beat ", plan[_i][0])
	return false
