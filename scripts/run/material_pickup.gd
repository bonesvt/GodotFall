extends Node3D
## A bit of loot on the ground: scrap, alloy or circuits. It pops out, lands,
## spins and bobs with a glow, and once the pilot comes within MAGNET it flies
## to her and is collected (the run manager is in the "loot_collector" group
## and counts it).

const LootArt := preload("res://scripts/run/loot_art.gd")
const SFX := preload("res://scripts/sfx.gd")

const MAGNET := 5.0
const COLLECT := 0.9
const GRAVITY := 14.0
## Seconds before a fresh drop can be picked up, so you see it spill out.
const ARM_TIME := 0.35

var kind := "scrap"
var amount := 1
var velocity := Vector3.ZERO
var _model: Node3D
var _grounded := false
var _age := 0.0
var _rest_y := 0.0


func _ready() -> void:
	_model = LootArt.model(kind)
	_model.scale = Vector3.ONE * 1.6
	add_child(_model)
	var glow := OmniLight3D.new()
	glow.light_color = LootArt.COLORS[kind]
	glow.light_energy = 0.8
	glow.omni_range = 1.4
	glow.position.y = 0.25
	add_child(glow)
	for mi in _model.find_children("*", "GeometryInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if String(mi.name).ends_with("__light"):
			mi.set_instance_shader_parameter("paint", LootArt.COLORS[kind])
			mi.set_instance_shader_parameter("glow", 3.0)


func _physics_process(delta: float) -> void:
	_age += delta
	var collector := get_tree().get_first_node_in_group("loot_collector")
	var pilot: Node3D = collector.player if collector != null else null
	if pilot != null and _age > ARM_TIME and pilot.is_inside_tree():
		var to := pilot.global_position + Vector3(0, 0.9, 0) - global_position
		if to.length() < COLLECT:
			collector.collect_material(kind, amount)
			SFX.play(collector, "ui_click", -8.0, 1.3 + randf() * 0.2)
			queue_free()
			return
		var magnet = pilot.get("loot_magnet")  # Eco's suit pouches (player.gd)
		if to.length() < MAGNET * (magnet if magnet != null else 1.0):
			_grounded = false
			velocity = velocity.lerp(to.normalized() * 14.0, 1.0 - exp(-10.0 * delta))
			global_position += velocity * delta
			return
	if _grounded:
		_model.position.y = 0.12 + sin(_age * 3.0) * 0.06
		_model.rotation.y += delta * 2.0
		return
	velocity.y -= GRAVITY * delta
	var next := global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.1, 0), next)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and velocity.y < 0.0:
		global_position = hit.position
		_grounded = true
		velocity = Vector3.ZERO
	else:
		global_position = next
	if global_position.y < -200.0:
		queue_free()
