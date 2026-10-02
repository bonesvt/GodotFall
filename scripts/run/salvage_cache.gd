extends Node3D
## Salvage cache: walk up and press F to pick one titan part from its offer.
## A guarded cache stays locked until its hold objective completes.

const Kit := preload("res://scripts/run/level_kit.gd")

const INTERACT_RANGE := 3.0
const READY_COLOR := Color(1.0, 0.75, 0.2)
const LOCKED_COLOR := Color(0.85, 0.25, 0.25)
const OPENED_COLOR := Color(0.35, 0.35, 0.38)

var locked := false
var opened := false
var _label: Label3D
var _mat: StandardMaterial3D


func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.6, 1.0, 1.0)
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled = true
	mesh.material = _mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = 0.5
	add_child(mi)
	_label = Kit.label(self, Vector3(0, 2.2, 0), "", 64)
	_refresh()


func can_open() -> bool:
	return not locked and not opened


func in_range(pos: Vector3) -> bool:
	return global_position.distance_to(pos) < INTERACT_RANGE


func unlock() -> void:
	locked = false
	_refresh()


func set_locked(value: bool) -> void:
	locked = value
	_refresh()


func mark_opened() -> void:
	opened = true
	_refresh()


func _refresh() -> void:
	if _label == null:
		return
	var color := READY_COLOR
	_label.text = "SALVAGE"
	if opened:
		color = OPENED_COLOR
		_label.text = "EMPTY"
	elif locked:
		color = LOCKED_COLOR
		_label.text = "SALVAGE (LOCKED)"
	_mat.albedo_color = color
	_mat.emission = color * 0.4
	_label.modulate = color.lightened(0.3)
