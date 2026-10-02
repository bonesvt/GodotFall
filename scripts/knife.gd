extends Node3D
## Eco's stiletto: a quick melee stab (V or F). It snaps out from her left
## hand, punches forward and tucks away again. On a grunt that hasn't noticed
## her it's a silent takedown that kills outright; on anyone else it's a
## solid hit that alerts them.

const FX := preload("res://scripts/fx.gd")
const SFX := preload("res://scripts/sfx.gd")

## Emitted on every stab: "miss", "hit", "kill" or "takedown".
signal stabbed(kind: String)

## Damage to an enemy that already knows she's there.
@export var damage := 30.0
## How far in front of the camera the blade reaches, in metres.
@export var reach := 2.4
## Targets within this many degrees of the crosshair can be stabbed.
@export var reach_angle := 40.0
## Seconds from the button to the blade landing, and for the whole stab.
@export var hit_time := 0.09
@export var stab_time := 0.42
@export var cooldown := 0.55

var player: CharacterBody3D
var weapon: Node
var stab_timer := -1.0
var cooldown_timer := 0.0
var takedowns := 0
var _struck := false
var _blade_root: Node3D

# Viewmodel poses, relative to the camera: tucked out of sight, then thrust.
const REST := Vector3(-0.34, -0.46, -0.12)
const THRUST := Vector3(-0.14, -0.17, -0.4)
const REST_ROT := Vector3(0.9, 0.5, 0.6)
const THRUST_ROT := Vector3(0.12, -0.55, -0.35)


func _ready() -> void:
	var n: Node = get_parent()
	while n != null and not (n is CharacterBody3D):
		n = n.get_parent()
	player = n
	weapon = get_parent().get_node_or_null("Weapon")
	_build_blade()


func _physics_process(delta: float) -> void:
	cooldown_timer -= delta
	if stab_timer < 0.0:
		return
	stab_timer += delta
	if not _struck and stab_timer >= hit_time:
		_struck = true
		_strike()
	if stab_timer >= stab_time:
		stab_timer = -1.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("melee", false, true):
		stab()


func _process(_delta: float) -> void:
	if stab_timer < 0.0:
		_blade_root.visible = false
		return
	_blade_root.visible = true
	# Snap out fast, hold a beat, ease back.
	var t := stab_timer
	var k := 0.0
	if t < hit_time:
		k = ease(t / hit_time, 0.4)
	elif t < hit_time + 0.08:
		k = 1.0
	else:
		k = 1.0 - ease((t - hit_time - 0.08) / (stab_time - hit_time - 0.08), 2.2)
	_blade_root.position = REST.lerp(THRUST, k)
	_blade_root.rotation = REST_ROT.lerp(THRUST_ROT, k)


func is_stabbing() -> bool:
	return stab_timer >= 0.0


## Starts a stab if the knife is ready. Returns false while on cooldown.
func stab() -> bool:
	if cooldown_timer > 0.0 or stab_timer >= 0.0:
		return false
	stab_timer = 0.0
	cooldown_timer = cooldown
	_struck = false
	SFX.play(self, "knife_swish", -4.0, SFX.vary(0.06))
	if weapon != null:
		# The pistol hand swings aside and can't fire mid-stab.
		weapon.cooldown = maxf(weapon.cooldown, stab_time * 0.8)
		if weapon.has_method("stop_inspect"):
			weapon.stop_inspect()
		weapon._kick_vel += Vector3(0.6, -0.8, 0.4)
	return true


## The enemy the blade would hit right now, or null.
func find_target() -> Node3D:
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var fwd: Vector3 = -player.head.global_basis.z
	var best: Node3D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.has_method("take_damage") or ("dead" in e and e.dead):
			continue
		var chest: Vector3 = e.global_position + Vector3.UP * 1.1
		var to := chest - from
		# Measure to the body's surface, not its centre.
		var d := maxf(to.length() - 0.35, 0.0)
		if d > reach or d >= best_d:
			continue
		if to.length() > 0.5 and rad_to_deg(fwd.angle_to(to)) > reach_angle:
			continue
		var query := PhysicsRayQueryParameters3D.create(from, chest)
		query.exclude = [player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider != e:
			continue  # something solid in the way
		best = e
		best_d = d
	return best


func _strike() -> void:
	var target := find_target()
	if target == null:
		stabbed.emit("miss")
		return
	var at: Vector3 = target.global_position + Vector3.UP * 1.2
	var fx_parent: Node = player.get_parent()
	var takedown: bool = target.has_method("is_unaware") and target.is_unaware()
	var killed: bool
	if takedown:
		killed = target.take_damage(target.health * 10.0 + 1000.0, at, false)
	else:
		killed = target.take_damage(damage, at, false)
	var kind := "takedown" if takedown and killed else ("kill" if killed else "hit")
	if takedown and killed:
		takedowns += 1
	stabbed.emit(kind)
	if weapon != null:
		weapon.hit_confirmed.emit("kill" if killed else "body")
	SFX.play(self, "knife_hit", 0.0, SFX.vary(0.08))
	if killed:
		SFX.play(self, "kill", -2.0)
	var dir: Vector3 = (at - player.camera.global_position).normalized()
	FX.star(fx_parent, at - dir * 0.3, Color(1.0, 0.9, 0.6), 0.3 if killed else 0.18, 0.06, 6)
	FX.debris(fx_parent, at - dir * 0.3, -dir, Color(0.42, 0.45, 0.4), 4, 3.0, 0.03, 0.35)
	if takedown:
		# A silent kill: a cold glint instead of a bang.
		FX.shock_ring(fx_parent, at - dir * 0.3, dir, Color(0.6, 0.95, 1.0, 0.9), 0.08, 0.14)


func _build_blade() -> void:
	_blade_root = Node3D.new()
	_blade_root.position = REST
	_blade_root.visible = false
	add_child(_blade_root)
	var holder := Node3D.new()  # blade points down -Z, grip toward the camera
	holder.rotation.x = -PI / 2.0
	holder.scale = Vector3.ONE * 1.3
	_blade_root.add_child(holder)

	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.86, 0.9, 0.95)
	steel.metallic = 0.55
	steel.roughness = 0.2
	steel.emission_enabled = true  # keeps the blade bright without reflections to catch
	steel.emission = Color(0.25, 0.28, 0.32)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.09, 0.09, 0.1)
	dark.roughness = 0.6
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.3, 0.95, 1.0)  # the pistol's LED cyan

	# Long, needle-thin diamond blade.
	var blade := CylinderMesh.new()
	blade.top_radius = 0.0
	blade.bottom_radius = 0.011
	blade.height = 0.22
	blade.radial_segments = 4
	blade.rings = 1
	blade.material = steel
	_part(holder, blade, Vector3(0, 0.13, 0), Vector3(1.0, 1.0, 0.35))
	# Fuller: a dark line down the middle of the blade.
	var fuller := BoxMesh.new()
	fuller.size = Vector3(0.002, 0.14, 0.0045)
	fuller.material = dark
	_part(holder, fuller, Vector3(0, 0.09, 0), Vector3.ONE)
	# Slim crossguard with a cyan inlay.
	var guard := BoxMesh.new()
	guard.size = Vector3(0.05, 0.007, 0.012)
	guard.material = steel
	_part(holder, guard, Vector3(0, 0.017, 0), Vector3.ONE)
	var inlay := BoxMesh.new()
	inlay.size = Vector3(0.03, 0.0035, 0.0125)
	inlay.material = glow
	_part(holder, inlay, Vector3(0, 0.017, 0), Vector3.ONE)
	# Wrapped grip and a pommel.
	var grip := CylinderMesh.new()
	grip.top_radius = 0.009
	grip.bottom_radius = 0.011
	grip.height = 0.1
	grip.radial_segments = 8
	grip.material = dark
	_part(holder, grip, Vector3(0, -0.037, 0), Vector3(1.0, 1.0, 0.8))
	var pommel := SphereMesh.new()
	pommel.radius = 0.012
	pommel.height = 0.02
	pommel.material = steel
	_part(holder, pommel, Vector3(0, -0.09, 0), Vector3.ONE)

	# Eco's left fist round the grip and her forearm running back off screen.
	var glove := StandardMaterial3D.new()
	glove.albedo_color = Color(0.32, 0.24, 0.18)
	glove.roughness = 0.8
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = Color(0.78, 0.78, 0.76)
	sleeve.roughness = 0.9
	var fist := BoxMesh.new()
	fist.size = Vector3(0.034, 0.06, 0.036)
	fist.material = glove
	_part(holder, fist, Vector3(0.004, -0.04, 0.0), Vector3.ONE)
	var arm := CylinderMesh.new()
	arm.top_radius = 0.022
	arm.bottom_radius = 0.032
	arm.height = 0.4
	arm.radial_segments = 8
	arm.material = sleeve
	var forearm := MeshInstance3D.new()
	forearm.mesh = arm
	forearm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	forearm.position = Vector3(0.0, -0.03, 0.24)
	forearm.rotation.x = PI / 2.0
	_blade_root.add_child(forearm)


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, scl: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
