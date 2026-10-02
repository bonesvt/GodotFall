extends Node3D
## Placeholder encounter guarding a salvage cache: stand in the ring until the
## uplink completes. Swap for a real fight (clear the grunts) once enemies land.

signal completed

const Kit := preload("res://scripts/run/level_kit.gd")

@export var radius := 4.0
@export var hold_time := 6.0

var target: Node3D
var cache: Node3D
var progress := 0.0
var done := false
var _label: Label3D
var _ring: MeshInstance3D


func _ready() -> void:
	_ring = Kit.disc(self, Vector3(0, 0.04, 0), radius, Color(0.85, 0.25, 0.25, 0.35))
	_label = Kit.label(self, Vector3(0, 3.0, 0), "", 64)
	_refresh()


func contains(pos: Vector3) -> bool:
	var d := pos - global_position
	return Vector2(d.x, d.z).length() < radius and absf(d.y) < 3.0


func _physics_process(delta: float) -> void:
	if done or target == null:
		return
	if contains(target.global_position):
		progress += delta
	else:
		progress = maxf(progress - delta * 0.5, 0.0)
	if progress >= hold_time:
		done = true
		if cache != null:
			cache.unlock()
		completed.emit()
	_refresh()


func _refresh() -> void:
	if done:
		_label.text = "UPLINK COMPLETE"
		(_ring.mesh.material as StandardMaterial3D).albedo_color = Color(0.3, 0.75, 0.4, 0.35)
	else:
		_label.text = "HOLD UPLINK %d%%" % roundi(progress / hold_time * 100.0)
