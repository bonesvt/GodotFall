extends StaticBody3D
## A pop-up target on the hub's shooting range: a painted board on a post with
## a small head plate. The pistol knocks it flat; it springs back up after a moment.

signal hit(head: bool)

const Art := preload("res://scripts/ps2/ps2_assets.gd")

const HEIGHT := 1.9
## Hits above this (from the base) count as headshots, like a grunt's head.
const HEAD_Y := 1.55
const RESET_TIME := 2.0
const BOARD := Color(0.92, 0.88, 0.8)
const RING := Color(0.8, 0.22, 0.16)

var down := false
var _pivot: Node3D
var _meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	var wood := Art.material("wood")
	_part(Vector3(0, 0.55, 0), Vector3(0.12, 1.1, 0.12), wood)
	_part(Vector3(0, 1.15, 0), Vector3(0.8, 0.8, 0.06), Art.material("light"), BOARD)
	_part(Vector3(0, 1.15, 0.035), Vector3(0.44, 0.44, 0.02), Art.material("light"), RING)
	_part(Vector3(0, 1.15, 0.045), Vector3(0.16, 0.16, 0.02), Art.material("light"), BOARD)
	_part(Vector3(0, 1.72, 0), Vector3(0.36, 0.34, 0.06), Art.material("light"), RING)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, HEIGHT - 0.75, 0.3)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.75 + shape.size.y * 0.5
	add_child(col)


func _part(pos: Vector3, size: Vector3, material: Material, paint := Color.WHITE) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	_pivot.add_child(mi)
	if paint != Color.WHITE:
		mi.set_instance_shader_parameter("paint", paint * 0.8)
	_meshes.append(mi)


func is_headshot(pos: Vector3) -> bool:
	return pos.y - global_position.y > HEAD_Y


## Same shape as a grunt's take_damage, so the pistol treats it like one.
## Returns true when it knocks the target down.
func take_damage(_amount: float, pos: Vector3, head := false) -> bool:
	if down:
		return false
	down = true
	hit.emit(head)
	for mi in _meshes:
		mi.set_instance_shader_parameter("flash", 0.8)
	var tween := create_tween()
	tween.tween_property(_pivot, "rotation:x", -PI / 2.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		for mi in _meshes:
			mi.set_instance_shader_parameter("flash", 0.0))
	tween.tween_interval(RESET_TIME)
	tween.tween_property(_pivot, "rotation:x", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): down = false)
	return true
