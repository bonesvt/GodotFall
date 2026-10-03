extends Node3D
## Small bits of life for the hub: a flickering fire light, cloth swaying in the
## breeze, birds wheeling overhead. Set `mode` and it animates its own node.

enum Mode { FLICKER, SWAY, ORBIT, SPIN }

@export var mode := Mode.SWAY
## FLICKER: base energy of the light. SWAY: degrees of swing. ORBIT: metres per second.
## SPIN: turns about its own Z axis (turbine blades) at `speed` radians per second.
@export var amount := 1.0
@export var speed := 1.0

var _t := 0.0
var _base := 0.0


func _ready() -> void:
	_t = randf() * 10.0
	match mode:
		Mode.FLICKER:
			_base = (get_parent() as Light3D).light_energy if get_parent() is Light3D else amount
		Mode.SWAY:
			_base = rotation.z


func _process(delta: float) -> void:
	_t += delta * speed
	match mode:
		Mode.FLICKER:
			var light := get_parent() as Light3D
			if light != null:
				light.light_energy = _base * (0.82 + 0.1 * sin(_t * 11.0) + 0.08 * sin(_t * 23.7))
		Mode.SWAY:
			rotation.z = _base + deg_to_rad(amount) * sin(_t * 1.7) * (0.7 + 0.3 * sin(_t * 0.43))
		Mode.ORBIT:
			# Wheel around the parent's origin; flap the wings ("WingL"/"WingR").
			rotate_y(delta * speed)
			for wing in get_children():
				if wing is Node3D and String(wing.name).begins_with("Wing"):
					var s := 1.0 if String(wing.name).ends_with("L") else -1.0
					wing.rotation.z = s * 0.5 * sin(_t * 9.0)
		Mode.SPIN:
			rotate_object_local(Vector3.FORWARD, delta * speed)
