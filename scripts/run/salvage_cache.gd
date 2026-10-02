extends Node3D
## Salvage cache: walk up and press F to pick one titan part from its offer.
## A guarded cache stays locked until its hold objective completes.

const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

const INTERACT_RANGE := 3.0
const READY_COLOR := Color(1.0, 0.75, 0.2)
const LOCKED_COLOR := Color(0.85, 0.25, 0.25)
const OPENED_COLOR := Color(0.35, 0.35, 0.38)

var locked := false
var opened := false
var _label: Label3D
var _model: Node3D


func _ready() -> void:
	_model = Art.model("salvage_cache")
	add_child(_model)
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
	_model.set_param("paint", color, "Light")
	_label.modulate = color.lightened(0.3)
