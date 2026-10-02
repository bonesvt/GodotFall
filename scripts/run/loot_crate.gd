extends Node3D
## A small militia supply crate tucked beside a route. Press F to pry the lid
## off; what's inside (scrap, sometimes circuits) spills out as pickups.
## Placed by loot.gd; the run manager opens it and drops the loot.

const LootArt := preload("res://scripts/run/loot_art.gd")
const SFX := preload("res://scripts/sfx.gd")
const FX := preload("res://scripts/fx.gd")

const INTERACT_RANGE := 2.4

## material -> amount inside.
var loot := {}
var kill_y := -100.0
var opened := false
var _model: Node3D
var _settled := false


func _ready() -> void:
	_model = LootArt.model("supply_crate")
	add_child(_model)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(0.9, 0.5, 0.55)
	col.position.y = 0.25
	body.add_child(col)
	add_child(body)
	_tag(Color(1.0, 0.8, 0.3), 2.5)


func _physics_process(_delta: float) -> void:
	if _settled:
		return
	_settled = true
	var at = LootArt.ground_under(get_world_3d(), global_position, kill_y, [_body_rid()])
	if at == null:
		queue_free()
	else:
		global_position = at


func _body_rid() -> RID:
	for child in get_children():
		if child is StaticBody3D:
			return child.get_rid()
	return RID()


func in_range(pos: Vector3) -> bool:
	return not opened and global_position.distance_to(pos) < INTERACT_RANGE


func prompt() -> String:
	return "[F] Pry open the crate"


## Pops the lid off and returns what was inside (empty if already opened).
func open() -> Dictionary:
	if opened:
		return {}
	opened = true
	var lid := _model.find_child("lid__wood", true, false) as Node3D
	if lid != null:
		var t := create_tween().set_parallel()
		t.tween_property(lid, "position", lid.position + Vector3(0.5, 0.35, 0.1), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(lid, "rotation", Vector3(0.4, 0.3, -1.1), 0.35)
	_tag(Color(0.4, 0.4, 0.42), 0.0)
	SFX.play_at(get_parent(), global_position, "bench", -2.0, 0.8)
	FX.puff(get_parent(), global_position + Vector3(0, 0.5, 0), Color(0.75, 0.68, 0.55, 0.5), 0.3, 0.6)
	return loot


func _tag(color: Color, glow: float) -> void:
	for mi in _model.find_children("tag__*", "GeometryInstance3D", true, false):
		mi.set_instance_shader_parameter("paint", color)
		mi.set_instance_shader_parameter("glow", glow)
