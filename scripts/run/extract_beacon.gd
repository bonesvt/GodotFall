extends Node3D
## End-of-zone extraction beacon. Step into the beam to move on.

const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

const RADIUS := 2.5

var text := "EXTRACT"


func _ready() -> void:
	var beam := CylinderMesh.new()
	beam.top_radius = RADIUS
	beam.bottom_radius = RADIUS
	beam.height = 30.0
	beam.material = Kit.glow(Color(0.3, 0.9, 0.6, 0.25))
	var mi := MeshInstance3D.new()
	mi.mesh = beam
	mi.position.y = 15.0
	add_child(mi)
	var model := Art.model("extract_beacon")
	add_child(model)
	model.set_param("paint", Color(0.3, 1.0, 0.6), "Light")
	Kit.label(self, Vector3(0, 4.0, 0), text, 96)


func contains(pos: Vector3) -> bool:
	var d := pos - global_position
	return Vector2(d.x, d.z).length() < RADIUS and d.y > -1.0 and d.y < 5.0
