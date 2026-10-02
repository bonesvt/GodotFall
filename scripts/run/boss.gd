extends Node3D
## Placeholder enemy titan for the end-of-run fight.
## It lays down light suppressive fire and telegraphs ground slams under your
## titan: get out of the red circle (dash) before it lands.
## Replace with a real enemy once combat lands.

signal defeated

const Kit := preload("res://scripts/run/level_kit.gd")

const CHIP_DPS := 35.0
const SLAM_RADIUS := 7.0
const SLAM_DELAY := 1.2
const SLAM_EVERY := 3.5
const SLAM_DAMAGE := 400.0

@export var max_hp := 6000.0

var hp := 0.0
var active := false
var target: Node3D
var slam_cooldown := 2.0
var slam_timer := -1.0
var slam_pos := Vector3.ZERO
var _marker: MeshInstance3D


func _ready() -> void:
	hp = max_hp
	var body := Kit.box(self, Vector3(0, 4.5, 0), Vector3(4, 9, 4), Color(0.6, 0.2, 0.2))
	body.add_to_group("titan_target")
	Kit.label(self, Vector3(0, 10.5, 0), "ENEMY TITAN", 96)
	_marker = Kit.disc(self, Vector3.ZERO, SLAM_RADIUS, Color(1.0, 0.1, 0.1, 0.35))
	_marker.top_level = true
	_marker.visible = false


func slam_incoming() -> bool:
	return slam_timer >= 0.0


func take_damage(amount: float) -> void:
	if not active or hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		active = false
		_marker.visible = false
		defeated.emit()


func _physics_process(delta: float) -> void:
	if not active or target == null:
		return
	var to := target.global_position - global_position
	if Vector2(to.x, to.z).length() > 0.1:
		rotation.y = atan2(-to.x, -to.z)
	target.take_damage(CHIP_DPS * delta)

	if slam_timer < 0.0:
		slam_cooldown -= delta
		if slam_cooldown <= 0.0:
			slam_pos = target.global_position
			slam_timer = SLAM_DELAY
			_marker.global_position = slam_pos + Vector3(0, 0.05, 0)
			_marker.visible = true
	else:
		slam_timer -= delta
		if slam_timer <= 0.0:
			slam_timer = -1.0
			slam_cooldown = SLAM_EVERY
			_marker.visible = false
			var d := target.global_position - slam_pos
			if Vector2(d.x, d.z).length() < SLAM_RADIUS:
				target.take_damage(SLAM_DAMAGE)
