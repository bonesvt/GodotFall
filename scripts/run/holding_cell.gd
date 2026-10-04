extends Node3D
## Ophelia's cell in the colony's holding block (Level 2, levels.gd "rescue"):
## a concrete cell open to the street behind a humming energy screen, with her
## sat on the floor inside, arms round her knees. The squad posted round the
## block (squad_objective.gd) keeps the screen up; once they're down, F drops
## it and she's out (run_manager rescue()).
## Same locked / unlock() / set_locked() as a salvage cache, so a
## SquadObjective can guard it. The cell opens toward local +z.

signal freed

const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const K := preload("res://scripts/hub/hub_kit.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const NpcIdles := preload("res://scripts/hub/npc_idles.gd")

const INTERACT_RANGE := 3.4
## Inside: across the front, height, front to back (m).
const SIZE := Vector3(5.0, 3.2, 4.2)
const WALL := 0.4
const SCREEN := Color(0.35, 0.85, 1.0)
const LOCKED_COLOR := Color(1.0, 0.45, 0.4)
const OPEN_COLOR := Color(0.4, 1.0, 0.5)

var locked := false
## She's out.
var opened := false
var ophelia: Node3D
var _screen: StaticBody3D
var _label: Label3D
var _light: OmniLight3D


func _ready() -> void:
	_build()
	ophelia = HubNpc.create("ophelia", Vector3(0.4, 0.08, -SIZE.z * 0.55), 180.0)
	add_child(ophelia)
	ophelia.wear("hoodie")
	_sit.call_deferred()
	_refresh()


## On the floor, arms round her knees, a thin pad under her.
func _sit() -> void:
	if ophelia == null or ophelia._anim == null:
		return
	NpcIdles._load_poses(ophelia)
	var name := NpcIdles.LIB + "/scene_sit"
	if ophelia._anim.has_animation(name):
		ophelia._anim.play(name, 0.0)
	ophelia.posed = true
	ophelia.mood(["sad", "down"])


func _build() -> void:
	var concrete := Art.material("concrete")
	var w := SIZE.x
	var d := SIZE.z
	var h := SIZE.y
	# Floor slab, back and side walls, roof, and a lip over the front.
	Kit.box(self, Vector3(0, 0.04, -d * 0.5), Vector3(w + WALL * 2.0, 0.08, d), Color(0.4, 0.41, 0.42), Vector3.ZERO, concrete)
	Kit.box(self, Vector3(0, h * 0.5, -d - WALL * 0.5), Vector3(w + WALL * 2.0, h, WALL), Color(0.5, 0.51, 0.52), Vector3.ZERO, concrete)
	for sx in [-1.0, 1.0]:
		Kit.box(self, Vector3(sx * (w + WALL) * 0.5, h * 0.5, -d * 0.5), Vector3(WALL, h, d + WALL), Color(0.5, 0.51, 0.52), Vector3.ZERO, concrete)
	Kit.box(self, Vector3(0, h + 0.2, -d * 0.5 + 0.2), Vector3(w + WALL * 2.0 + 0.4, 0.4, d + WALL + 0.8), Color(0.3, 0.31, 0.33), Vector3.ZERO, concrete)
	# A thin grey pad on the floor and a steel bucket: all they gave her.
	K.mesh(self, Vector3(0.4, 0.1, -d * 0.55), Vector3(1.0, 0.05, 1.9), Art.material("canvas", Color(0.32, 0.33, 0.34)))
	K.mesh(self, Vector3(-w * 0.5 + 0.5, 0.28, -d + 0.5), Vector3(0.4, 0.45, 0.4), Art.material("gunmetal"))
	# Emitter rails top and bottom, and the screen between them.
	var rail := Art.material("gunmetal")
	K.mesh(self, Vector3(0, 0.12, 0.05), Vector3(w, 0.24, 0.3), rail)
	K.mesh(self, Vector3(0, h - 0.12, 0.05), Vector3(w, 0.24, 0.3), rail)
	_screen = StaticBody3D.new()
	_screen.name = "Screen"
	add_child(_screen)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, h, 0.2)
	shape.shape = box
	shape.position = Vector3(0, h * 0.5, 0.05)
	_screen.add_child(shape)
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.albedo_color = Color(SCREEN, 0.28)
	var sheet := MeshInstance3D.new()
	var quad := BoxMesh.new()
	quad.size = Vector3(w, h - 0.48, 0.04)
	sheet.mesh = quad
	sheet.material_override = glass
	sheet.position = Vector3(0, h * 0.5, 0.05)
	_screen.add_child(sheet)
	# Bright bars through the screen so it reads as a cage from a distance.
	var bar_mat := Kit.glow(SCREEN)
	var n := 9
	for i in n:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, h - 0.48, 0.05)
		bar.mesh = bm
		bar.material_override = bar_mat
		bar.position = Vector3(-w * 0.5 + w * (i + 0.5) / n, h * 0.5, 0.05)
		_screen.add_child(bar)
	_light = OmniLight3D.new()
	_light.light_color = SCREEN
	_light.light_energy = 1.2
	_light.omni_range = 6.0
	_light.position = Vector3(0, h * 0.6, 0.6)
	add_child(_light)
	_label = Kit.label(self, Vector3(0, h + 1.2, 0.4), "", 64)


func can_open() -> bool:
	return not locked and not opened


func in_range(pos: Vector3) -> bool:
	var front := global_transform * Vector3(0, 0, 1.0)
	return Vector2(front.x - pos.x, front.z - pos.z).length() < INTERACT_RANGE and absf(front.y - pos.y) < 2.5


func unlock() -> void:
	locked = false
	_refresh()


func set_locked(value: bool) -> void:
	locked = value
	_refresh()


## Drops the screen and gets her up. Returns false if it's still held shut.
func release() -> bool:
	if not can_open():
		return false
	opened = true
	_screen.queue_free()
	_screen = null
	_light.light_energy = 0.3
	if ophelia != null and ophelia._anim != null:
		ophelia.posed = false
		if ophelia._anim.has_animation("idle"):
			ophelia._anim.play("idle", 0.6)
		ophelia.mood(["surprised"])
	_refresh()
	freed.emit()
	return true


func _refresh() -> void:
	if _label == null:
		return
	if opened:
		_label.text = "HOLDING CELL (OPEN)"
		_label.modulate = OPEN_COLOR
	elif locked:
		_label.text = "OPHELIA\nSCREEN HELD BY THE GUARDS"
		_label.modulate = LOCKED_COLOR
	else:
		_label.text = "OPHELIA\n[F] DROP THE SCREEN"
		_label.modulate = SCREEN
