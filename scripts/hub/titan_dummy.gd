extends StaticBody3D
## A scrap titan propped up in the hub's titan yard for target practice.
## Your titan's gun wears it down; at zero it topples, then she props it back up.

signal destroyed

const Art := preload("res://scripts/ps2/ps2_assets.gd")

const MAX_HP := 1500.0
const RESET_TIME := 4.0

var hp := MAX_HP
var down := false
var _model: Node3D
var _flash := 0.0


func _ready() -> void:
	add_to_group("titan_target")
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 7, 3)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 3.5
	add_child(col)
	_model = Art.titan("scrap", "scrap")
	add_child(_model)
	_model.set_param("paint", Color(0.85, 0.7, 0.55))
	_model.set_param("glow", 0.0)
	# A painted bullseye on its chest.
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.4, 1.4, 0.05)
	mesh.material = Art.material("light")
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.position = Vector3(0, 4.5, -1.6)
	ring.set_instance_shader_parameter("paint", Color(0.75, 0.2, 0.14))
	add_child(ring)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 6.0, 0.0)
		_model.set_param("flash", _flash * 0.6)


func take_damage(amount: float) -> void:
	if down:
		return
	hp -= amount
	_flash = 1.0
	if hp > 0.0:
		return
	hp = 0.0
	down = true
	destroyed.emit()
	var tween := create_tween()
	tween.tween_property(self, "rotation:x", deg_to_rad(80.0), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(RESET_TIME)
	tween.tween_property(self, "rotation:x", 0.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		hp = MAX_HP
		down = false)
