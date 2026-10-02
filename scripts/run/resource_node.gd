extends Node3D
## An alloy node: a titan wreck half sunk in the ground with raw alloy glowing
## through the cracks. Hold F to mine it with Eco's breaker bar; when the bar
## fills, the veins go dark and the alloy spills out as pickups. Progress
## stays if you let go. Placed by loot.gd; the run manager drives the mining.

const LootArt := preload("res://scripts/run/loot_art.gd")
const SFX := preload("res://scripts/sfx.gd")
const FX := preload("res://scripts/fx.gd")

const INTERACT_RANGE := 3.0
## Seconds of holding F to mine one out.
const MINE_TIME := 1.8
## A strike (sparks, a clank, a shake) every this many seconds while mining.
const STRIKE_EVERY := 0.3
const VEIN := Color(0.45, 0.85, 1.0)

## material -> amount it yields.
var loot := {}
var kill_y := -100.0
var progress := 0.0
var depleted := false
var _model: Node3D
var _settled := false
var _since_strike := 0.0
var _shake := 0.0


func _ready() -> void:
	_model = LootArt.model("alloy_node")
	add_child(_model)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = CylinderShape3D.new()
	col.shape.radius = 0.9
	col.shape.height = 1.2
	col.position.y = 0.6
	body.add_child(col)
	add_child(body)
	_veins(VEIN, 2.0)


func _physics_process(_delta: float) -> void:
	if _settled:
		return
	_settled = true
	var rid: RID = (get_child(get_child_count() - 1) as StaticBody3D).get_rid()
	var at = LootArt.ground_under(get_world_3d(), global_position, kill_y, [rid])
	if at == null:
		queue_free()
	else:
		global_position = at - Vector3(0, 0.1, 0)


func _process(delta: float) -> void:
	_shake = maxf(_shake - delta * 6.0, 0.0)
	_model.position = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.03 * _shake
	if not depleted:
		var pulse := 1.6 + 0.6 * sin(Time.get_ticks_msec() / 1000.0 * 2.5) + progress * 3.0
		_veins(VEIN, pulse)


func in_range(pos: Vector3) -> bool:
	return not depleted and global_position.distance_to(pos) < INTERACT_RANGE


func prompt() -> String:
	if progress > 0.0:
		return "[Hold F] Mining alloy  %d%%" % roundi(progress / MINE_TIME * 100.0)
	return "[Hold F] Mine the alloy"


## One frame of holding F. Returns the yield when it's mined out, else {}.
func mine(delta: float) -> Dictionary:
	if depleted:
		return {}
	progress += delta
	_since_strike += delta
	if _since_strike >= STRIKE_EVERY:
		_since_strike = 0.0
		_shake = 1.0
		var at := global_position + Vector3(randf_range(-0.4, 0.4), randf_range(0.4, 0.9), randf_range(-0.4, 0.4))
		FX.star(get_parent(), at, Color(VEIN, 0.9), 0.18, 0.06, 6)
		FX.debris(get_parent(), at, Vector3.UP, Color(0.5, 0.55, 0.6), 3, 2.5, 0.04, 0.35)
		SFX.play_at(get_parent(), at, "impact", -4.0, randf_range(1.3, 1.6))
	if progress < MINE_TIME:
		return {}
	depleted = true
	_veins(Color(0.25, 0.3, 0.32), 0.0)
	FX.blast(get_parent(), global_position + Vector3(0, 0.6, 0), VEIN, 1.2, 0.3)
	SFX.play_at(get_parent(), global_position, "ricochet", -2.0, 0.7)
	return loot


func _veins(color: Color, glow: float) -> void:
	for mi in _model.find_children("veins__*", "GeometryInstance3D", true, false):
		mi.set_instance_shader_parameter("paint", color)
		mi.set_instance_shader_parameter("glow", glow)
