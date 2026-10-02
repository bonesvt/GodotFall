extends Node3D
## Root script of every model scene in assets/models.
## Sets per-object shader knobs (hit flash, glow, paint) on the meshes below it,
## and swings the "LegL"/"LegR" pivots while the body it belongs to walks.

## Metres covered by one full stride (both legs).
@export var stride := 1.6
@export var swing_degrees := 28.0

var _legs: Array[Node3D] = []
var _body: CharacterBody3D
var _phase := 0.0


func _ready() -> void:
	for leg_name in ["LegL", "LegR"]:
		var leg := find_child(leg_name, true, false) as Node3D
		if leg != null:
			_legs.append(leg)
	var n := get_parent()
	while n != null and not (n is CharacterBody3D):
		n = n.get_parent()
	_body = n
	set_process(_legs.size() == 2 and _body != null)


## Sets an instance uniform of ps2_surface.gdshader ("flash", "glow" or "paint")
## on every mesh in the model, or only on meshes whose name starts with `prefix`.
func set_param(param: StringName, value: Variant, prefix := "") -> void:
	for node in find_children("*", "GeometryInstance3D", true, false):
		if prefix == "" or String(node.name).begins_with(prefix):
			(node as GeometryInstance3D).set_instance_shader_parameter(param, value)


func _process(delta: float) -> void:
	var speed := Vector2(_body.velocity.x, _body.velocity.z).length()
	if not _body.is_on_floor():
		speed = 0.0
	_phase = fmod(_phase + speed * delta / stride * TAU, TAU)
	var amount := clampf(speed / 3.0, 0.0, 1.0)
	var target := sin(_phase) * deg_to_rad(swing_degrees) * amount
	_legs[0].rotation.x = lerpf(_legs[0].rotation.x, target, minf(delta * 12.0, 1.0))
	_legs[1].rotation.x = lerpf(_legs[1].rotation.x, -target, minf(delta * 12.0, 1.0))
