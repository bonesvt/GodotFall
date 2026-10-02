extends Node3D
## Grunt squad guarding a salvage cache: the cache unlocks once every grunt
## in the squad is dead.

signal completed

const Kit := preload("res://scripts/run/level_kit.gd")

var cache: Node3D
var grunts: Array = []
var done := false
var _label: Label3D


func _ready() -> void:
	_label = Kit.label(self, Vector3(0, 3.5, 0), "", 64)
	_refresh()


## Hands the squad over; call once after the grunts are in the tree.
func set_squad(squad: Array) -> void:
	grunts = squad
	for g in grunts:
		g.died.connect(_on_grunt_died)
	_refresh()


func alive() -> int:
	return grunts.filter(func(g): return is_instance_valid(g) and not g.dead).size()


func _on_grunt_died(_g: Node) -> void:
	if done or alive() > 0:
		_refresh()
		return
	done = true
	if cache != null:
		cache.unlock()
	completed.emit()
	_refresh()


func _refresh() -> void:
	if _label == null:
		return
	_label.text = "CACHE UNLOCKED" if done else "GUARDED: %d HOSTILES" % alive()
	_label.modulate = Color(0.4, 1.0, 0.5) if done else Color(1.0, 0.45, 0.4)
