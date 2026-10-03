extends "res://scripts/threats/creature.gd"
## LAMPJAW: a 2.8 m marsh ambush predator. It lies low in black water with
## only its eyes and its lantern lure showing, and turns to follow anything
## that comes near. Too close and it lunges: the spots down its flanks flare
## and the jaw drops open just before it goes, and one bite takes most of
## Eco's health. Then it slinks back to its spot to wait again.

enum State { LURK, LUNGE, RETURN }

@export var notice_range := 10.0
@export var strike_range := 5.0
@export var bite_damage := 55.0
@export var tell_time := 0.35
@export var cooldown := 3.0
## How far it sits below its post while lurking (only the back shows).
@export var sink := 0.3

var state := State.LURK
var _t := 0.0
var _cool := 0.0
var _bit := false


func _init() -> void:
	max_health = 160.0
	move_speed = 3.0


func _build() -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = 0.75
	cap.height = 3.4
	_body(cap, Vector3(0, 0.6, 0.3))
	get_child(0).rotation.x = PI / 2.0
	_model("lampjaw", "scuttle")
	model.position.y = -sink


func is_headshot(pos: Vector3) -> bool:
	return (global_basis.inverse() * (pos - global_position)).z < -0.9


func _physics_process(delta: float) -> void:
	if dead:
		return
	_cool -= delta
	var want := Vector3.ZERO
	var tell := 0.0
	var open := 0.0
	if not passive and target != null:
		var to := to_pilot()
		var dist := to.length()
		match state:
			State.LURK:
				alerted = false
				if dist < notice_range:
					face(to, delta, 2.0)
					tell = 0.25 * (1.0 - dist / notice_range)
				if dist < strike_range and _cool <= 0.0 and absf(target.global_position.y - global_position.y) < 2.5:
					state = State.LUNGE
					_t = 0.0
					_bit = false
					alerted = true
			State.LUNGE:
				_t += delta
				open = clampf(_t / tell_time, 0.0, 1.0)
				tell = 1.0
				if _t < tell_time:
					face(to, delta, 10.0)
				else:
					if _t - delta < tell_time:
						sound("lampjaw_snap", 2.0, 0.6)
						velocity = -global_basis.z * 11.0 + Vector3.UP * 2.0
					move_speed = 11.0
					want = -global_basis.z
					if not _bit and dist < 2.4:
						_bit = true
						target.take_damage(bite_damage, global_position)
						FX.spark(get_parent(), target.global_position + Vector3.UP, Color(1.0, 0.85, 0.4), 0.3, 0.12)
					if _t > tell_time + 0.4:
						state = State.RETURN
						_cool = cooldown
						move_speed = 3.0
			State.RETURN:
				var home := post - global_position
				home.y = 0.0
				if home.length() < 0.6:
					state = State.LURK
				else:
					face(-home, delta, 4.0)  # backs into its spot facing out
					want = home.normalized() * 0.6
	if model != null:
		model.tell = tell
		model.open = open
		model.position.y = lerpf(model.position.y, 0.0 if state == State.LUNGE else -sink, minf(delta * 6.0, 1.0))
	walk(want, delta, 30.0 if state == State.LUNGE else 10.0)


func _hurt(_pos: Vector3) -> void:
	if state == State.LURK and target != null and to_pilot().length() < strike_range * 1.6:
		_cool = 0.0
		state = State.LUNGE
		_t = tell_time * 0.5
		_bit = false
