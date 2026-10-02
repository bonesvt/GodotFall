extends "res://scripts/ps2/ps2_model.gd"
## Root script of assets/models/eco.tscn, the heroine (rigged mesh from
## assets/models/eco/eco.glb). Plays her idle loop while she stands and her
## walk cycle, sped up to match, while the CharacterBody3D she belongs to
## moves. Drop the scene in anywhere: on her own she just idles.

## Play the idle loop (breathing, glancing around) while standing.
@export var idle_motion := true
## Ground speed (m/s) the walk animation is authored at.
@export var walk_speed := 1.3

var _anim: AnimationPlayer


func _ready() -> void:
	super()
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	set_process(_anim != null)
	if _anim != null and idle_motion:
		_anim.play("idle")


func _process(_delta: float) -> void:
	var speed := 0.0
	if _body != null and _body.is_on_floor():
		speed = Vector2(_body.velocity.x, _body.velocity.z).length()
	if speed > 0.3:
		if _anim.current_animation != "walk":
			_anim.play("walk", 0.25)
		_anim.speed_scale = speed / walk_speed
	elif idle_motion:
		if _anim.current_animation != "idle":
			_anim.play("idle", 0.4)
		_anim.speed_scale = 1.0
	elif _anim.is_playing():
		_anim.pause()
