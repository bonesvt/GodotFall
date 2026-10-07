extends "res://scripts/hub/hub_npc.gd"
## One of the people of Solace (models: tools/town/build_townsfolk.py ->
## assets/models/npc/town_<name>.glb). Everything a hub NPC does (toon model,
## talk loop, mouth moving with their babble, turning to Eco), plus going
## about their day:
##   walk   back and forth along a route, stopping a while at its pause
##          points and for Eco when she's in the way
##   stand  in one spot, facing `home_yaw`
##   sit    on a bench (the "sit" loops), facing out from it
## townsfolk.gd places them and runs who says what; say_line() puts their
## babble on the air and their words in a caption over their head.

const Babble := preload("res://scripts/hub/babble.gd")

## Metres a second at a full stride (the walk loop covers about 1.3 m in 32 frames).
const STRIDE_SPEED := 1.22
## How close Eco can be in front of a walker before they stop for her.
const GIVE_WAY := 1.6
## How far away (m) a caption can still be read.
const CAPTION_RANGE := 16.0

var mode := "stand"
## The route (walkers): points on the ground, walked from first to last and back.
var route: Array = []
## Indices of route points where they stop a while, and for how long (s).
var pauses := {}
var pause_time := 4.0
var speed := 1.1
## The person they're talking with (they face each other while it lasts).
var partner: Node3D
## Pilot, for giving way and noticing her.
var pilot: Node3D

var _leg := 1
var _dir := 1
var _wait := 0.0
var _caption: Label3D
var _say_t := 0.0
var _say_times := PackedFloat32Array()
var _say_text := ""
var _say_left := 0.0


static func create_town(p_who: String, pos: Vector3, yaw_deg: float, p_mode := "stand") -> Node3D:
	var npc: Node3D = load("res://scripts/hub/townsperson.gd").new()
	npc.who = "town_" + p_who
	npc.name = "Town_" + p_who.capitalize()
	npc.mode = p_mode
	npc.position = pos
	npc.home_yaw = deg_to_rad(yaw_deg)
	npc.rotation.y = npc.home_yaw
	return npc


func _ready() -> void:
	super._ready()
	posed = mode == "sit"   # hub_npc: no turning on the spot, no switching to its talk loop
	_play(_rest_anim())
	_caption = Label3D.new()
	_caption.name = "Caption"
	_caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_caption.no_depth_test = true
	_caption.fixed_size = false
	_caption.pixel_size = 0.0042
	_caption.font_size = 30
	_caption.outline_size = 10
	_caption.outline_modulate = Color(0.05, 0.03, 0.06, 0.9)
	_caption.modulate = Color(1.0, 0.96, 0.88)
	_caption.width = 520.0
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_caption.position = Vector3(0, 2.1 if mode != "sit" else 1.6, 0)
	_caption.visible = false
	add_child(_caption)
	if mode == "walk" and route.size() >= 2:
		position = route[0]
		_leg = 1


## The person's short name ("pell"), without the model prefix.
func short_name() -> String:
	return who.trim_prefix("town_")


func walking() -> bool:
	return mode == "walk" and _wait <= 0.0 and not talking


## Says one line: babble in their voice, the words typed out over their head.
func say_line(text: String) -> float:
	var b := Babble.make(who, text)
	say(b["stream"])
	if mode == "sit":
		_play("sit_talk")
	_say_text = text
	_say_times = b["times"]
	_say_t = 0.0
	_say_left = float(b["length"]) + 1.6
	_caption.text = ""
	return float(b["length"])


## Stops talking (the caption lingers a moment, then clears).
func done_talking() -> void:
	hush()
	if mode == "sit":
		_play("sit")


## Holds them where they are for `seconds` (walkers stop to chat or to wait for Eco).
func hold(seconds: float) -> void:
	_wait = maxf(_wait, seconds)
	if mode == "walk":
		_play("idle")


func _rest_anim() -> String:
	if mode == "sit":
		return "sit"
	return "walk" if mode == "walk" else "idle"


func _play(anim: String, blend := 0.3) -> void:
	if _anim == null or not _anim.has_animation(anim) or _anim.current_animation == anim:
		return
	_anim.play(anim, blend)


func _process(delta: float) -> void:
	if mode == "walk":
		_walk(delta)
	elif partner != null and is_instance_valid(partner) and mode == "stand":
		var d := partner.global_position - global_position
		home_yaw = lerp_angle(home_yaw, atan2(-d.x, -d.z), minf(1.0, delta * 2.0))
	look_target = pilot if not walking() else null
	super._process(delta)
	_caption_tick(delta)


func _walk(delta: float) -> void:
	if route.size() < 2:
		return
	if _wait > 0.0 or talking:
		_wait -= delta
		if partner != null and is_instance_valid(partner):
			var d := partner.global_position - global_position
			home_yaw = atan2(-d.x, -d.z)
		if _wait <= 0.0 and not talking:
			_play("walk")
		return
	var target: Vector3 = route[_leg]
	var to := target - position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	# Eco in the way: stop and let her pass.
	if pilot != null and is_instance_valid(pilot):
		var e := pilot.global_position - global_position
		e.y = 0.0
		if e.length() < GIVE_WAY and e.normalized().dot(dir) > 0.5:
			hold(1.2)
			return
	var step := speed * delta
	if step >= dist:
		position = Vector3(target.x, position.y, target.z)
		if pauses.has(_leg):
			hold(float(pauses[_leg]) if float(pauses[_leg]) > 0.0 else pause_time)
		_next_leg()
	else:
		position += dir * step
	if dist > 0.05:
		home_yaw = atan2(-dir.x, -dir.z)   # the model faces -Z
	if _anim != null and _anim.current_animation == "walk":
		_anim.speed_scale = speed / STRIDE_SPEED


func _next_leg() -> void:
	if _leg + _dir >= route.size() or _leg + _dir < 0:
		_dir = -_dir
	_leg += _dir


func _caption_tick(delta: float) -> void:
	if _say_left <= 0.0:
		if _caption.visible:
			_caption.visible = false
		return
	_say_left -= delta
	_say_t += delta
	var shown := 0
	while shown < _say_times.size() - 1 and _say_times[shown] <= _say_t:
		shown += 1
	_caption.text = _say_text.substr(0, shown if _say_t < _say_times[_say_times.size() - 1] else _say_text.length())
	var near := pilot == null or not is_instance_valid(pilot) or pilot.global_position.distance_to(global_position) < CAPTION_RANGE
	_caption.visible = near and _say_left > 0.0 and _caption.text != ""
	if _anim != null and _anim.current_animation != "walk":
		_anim.speed_scale = 1.0
