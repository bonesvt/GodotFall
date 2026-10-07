extends Node
## The titan's weapon, with a personality per part. The weapon part still sets
## damage per second (titan_parts.gd); this decides how that damage arrives:
##
##   XO-16 Chaingun   barrels wind up, then a relentless stream of rounds.
##   40mm Tracker     slow, heavy shells that land as explosions.
##   Splitter Rifle   a humming beam that heats from cyan to white-hot as
##                    its ramp builds.
##   Obelisk Rail     Precursor tech Eco found at the temple: a teal beam
##                    thread between two hovering obelisks. The old relic
##                    stutters (uneven rate of fire) and every so often
##                    stalls until she kicks it back to life.
##
## Each shot is worth damage-per-second times the time it took to fire, so a
## spin-up or an uneven rhythm keeps the part's damage per second. Only jams
## cost damage.

const FX := preload("res://scripts/fx.gd")
const SFX := preload("res://scripts/sfx.gd")

const PROFILES := {
	"xo16": {"rate": 14.0, "spin": 0.4, "spin_floor": 0.35, "spread": 0.7,
		"color": Color(1.0, 0.8, 0.35), "width": 0.09, "flash": 0.45, "shake": 0.09,
		"kick": 0.12, "sound": "xo16", "volume": -5.0, "muzzle": -2.9},
	"tracker": {"rate": 2.4, "spread": 0.15,
		"color": Color(1.0, 0.55, 0.2), "width": 0.25, "flash": 0.9, "shake": 0.55,
		"kick": 0.7, "sound": "tracker", "volume": 0.0, "muzzle": -3.4, "splash": 2.6},
	"splitter": {"rate": 18.0, "spread": 0.0, "beam": true,
		"color": Color(0.35, 0.9, 1.0), "width": 0.16, "flash": 0.35, "shake": 0.035,
		"kick": 0.03, "sound": "splitter", "volume": -9.0, "sound_every": 3, "muzzle": -3.0},
	"scrap": {"rate": 7.0, "jitter": 0.45, "spread": 1.4, "jam_after": Vector2i(16, 26), "jam_time": 0.7,
		"color": Color(0.35, 1.0, 0.9), "width": 0.11, "flash": 0.55, "shake": 0.16,
		"kick": 0.2, "sound": "scrap", "volume": -3.0, "muzzle": -2.6},
}

const RANGE := 200.0

var titan: CharacterBody3D
var id := "scrap"
var profile: Dictionary
var rng := RandomNumberGenerator.new()

var cooldown := 0.0
## 0..1 how far the chaingun barrels have wound up.
var spin := 0.0
## Seconds of jam left (the Obelisk Rail's stutter).
var jam_timer := 0.0
var shots := 0
var _until_jam := 0
var _interval := 0.0
var _since_shot := 10.0
## Seconds since the last shot that hit the enemy titan, for the hitmarker.
var since_hit := 10.0
var _gun_model: Node3D
var _arm: Node3D
var _arm_rest := Vector3.ZERO
var _arm_kick := 0.0
var _was_firing := false


func setup(p_titan: CharacterBody3D, weapon_id: String) -> void:
	titan = p_titan
	id = weapon_id if PROFILES.has(weapon_id) else "scrap"
	profile = PROFILES[id]
	_roll_jam()


func _ready() -> void:
	if titan.model != null:
		_arm = titan.model.get_node_or_null("ArmR")
		var mount: Node = titan.model.find_child("WeaponMount", true, false)
		if mount != null and mount.get_child_count() > 0:
			_gun_model = mount.get_child(0)
	if _arm != null:
		_arm_rest = _arm.position


## Seconds between shots right now.
func interval() -> float:
	var rate: float = profile["rate"]
	if profile.has("spin"):
		rate *= lerpf(profile["spin_floor"], 1.0, spin)
	return 1.0 / rate


func jammed() -> bool:
	return jam_timer > 0.0


func update(delta: float, firing: bool) -> void:
	cooldown -= delta
	since_hit += delta
	_since_shot += delta
	_arm_kick = lerpf(_arm_kick, 0.0, 1.0 - exp(-14.0 * delta))
	if _arm != null:
		_arm.position = _arm_rest + Vector3(0.0, _arm_kick * 0.15, _arm_kick)

	if profile.has("spin"):
		if firing and not _was_firing:
			SFX.play(self, "xo16_spin", -8.0)
		spin = clampf(spin + (delta / profile["spin"] if firing else -delta / profile["spin"] * 0.6), 0.0, 1.0)
	_was_firing = firing

	if jam_timer > 0.0:
		jam_timer -= delta
		if jam_timer <= 0.0:
			# Eco kicks it back into life.
			titan.shake += 0.25
			_arm_kick = 0.6
			SFX.play(self, "whack", -2.0, 0.6)
		return

	if not firing:
		return
	if cooldown > 0.0:
		return
	_interval = interval()
	if profile.has("jitter"):
		_interval *= 1.0 + rng.randf_range(-profile["jitter"], profile["jitter"])
	cooldown = maxf(cooldown, 0.0) + _interval
	# Credit the time this shot actually took (physics ticks round it up a bit).
	var dt := clampf(_since_shot, _interval, _interval + 0.02)
	_since_shot = 0.0
	_shoot(dt)


func _shoot(dt: float) -> void:
	shots += 1
	var cam: Camera3D = titan.camera
	var basis: Basis = titan.head.global_basis
	var r := tan(deg_to_rad(profile["spread"])) * sqrt(rng.randf())
	var a := rng.randf() * TAU
	var dir := (-basis.z + basis.x * cos(a) * r + basis.y * sin(a) * r).normalized()
	var from := cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * RANGE)
	query.exclude = [titan.get_rid()]
	var hit := titan.get_world_3d().direct_space_state.intersect_ray(query)
	var end := from + dir * RANGE
	var normal := -dir
	var target: Node = null
	if not hit.is_empty():
		end = hit.position
		normal = hit.normal
		if hit.collider.is_in_group("titan_target"):
			target = hit.collider
			while target != null and not target.has_method("take_damage"):
				target = target.get_parent()
	var on_enemy := target != null
	if on_enemy:
		titan.hit_enemy(target, float(titan.stats["dps"]) * dt)
		since_hit = 0.0

	var fx_parent: Node = titan.get_parent()
	var muzzle := _muzzle()
	_shot_fx(fx_parent, muzzle, end, normal, on_enemy)

	if profile.has("jam_after"):
		_until_jam -= 1
		if _until_jam <= 0:
			_jam(fx_parent, muzzle)


func _shot_fx(fx_parent: Node, muzzle: Vector3, end: Vector3, normal: Vector3, on_enemy: bool) -> void:
	var color: Color = profile["color"]
	var heat := 0.0
	if profile.get("beam", false):
		# Splitter heats up as its ramp builds: cyan, then white, then hot pink.
		var ramp_max := maxf(float(titan.stats.get("ramp", 0.0)), 0.01)
		heat = clampf(titan.ramp_bonus / ramp_max, 0.0, 1.0)
		color = color.lerp(Color(1.0, 1.0, 1.0), clampf(heat * 2.0, 0.0, 1.0)).lerp(Color(1.0, 0.35, 0.75), clampf(heat * 2.0 - 1.0, 0.0, 1.0))
		FX.tracer(fx_parent, muzzle, end, Color(color, 0.9), profile["width"] * (1.0 + heat), 0.07)
		FX.tracer(fx_parent, muzzle, end, Color(1, 1, 1, 0.9), profile["width"] * 0.3, 0.05)
	else:
		FX.tracer(fx_parent, muzzle, end, Color(color, 0.95), profile["width"], 0.07)

	FX.star(fx_parent, muzzle, Color(color, 0.95), profile["flash"] * (1.0 + heat * 0.5), 0.05, 6)
	if shots % 2 == 0 or not profile.has("spin"):
		FX.light(fx_parent, muzzle, color, 3.0, 12.0, 0.06)

	if profile.has("splash"):
		FX.blast(fx_parent, end + normal * 0.3, Color(1.0, 0.5, 0.15), profile["splash"], 0.4)
		FX.debris(fx_parent, end, normal, Color(0.35, 0.3, 0.28), 8, 9.0, 0.25, 0.7)
		FX.puff(fx_parent, muzzle, Color(0.6, 0.58, 0.55, 0.5), 0.5, 0.9, Vector3(0, 1.5, 0))
		SFX.play_at(fx_parent, end, "tracker_boom", 2.0, SFX.vary(0.1))
	elif on_enemy:
		FX.star(fx_parent, end + normal * 0.2, Color(1.0, 0.9, 0.5), 0.8, 0.06, 5)
		FX.debris(fx_parent, end, normal, Color(1.0, 0.65, 0.25), 2, 6.0, 0.08, 0.35)
	else:
		FX.puff(fx_parent, end + normal * 0.3, Color(0.75, 0.68, 0.56, 0.6), 0.35, 0.6, normal * 1.2)
		FX.debris(fx_parent, end, normal, Color(0.55, 0.5, 0.44), 2, 6.0, 0.12, 0.45)

	if on_enemy and (profile.has("splash") or shots % 3 == 0):
		SFX.play(self, "titan_hit", -10.0, SFX.vary(0.12))
	var every: int = profile.get("sound_every", 1)
	if shots % every == 0:
		var pitch := SFX.vary(0.05) * (1.0 + heat * 0.6)
		if profile.has("spin"):
			pitch *= lerpf(0.85, 1.05, spin)
		SFX.play(self, profile["sound"], profile["volume"], pitch)

	titan.shake += profile["shake"]
	_arm_kick = minf(_arm_kick + profile["kick"], 1.2)
	titan.camera.fov -= profile["kick"] * 2.0


func _jam(fx_parent: Node, muzzle: Vector3) -> void:
	jam_timer = profile["jam_time"]
	_roll_jam()
	SFX.play(self, "scrap_jam", -2.0)
	FX.puff(fx_parent, muzzle, Color(0.3, 0.3, 0.3, 0.7), 0.4, 1.2, Vector3(0, 2.0, 0))
	for i in 4:
		FX.star(fx_parent, muzzle + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.2, 0.3), rng.randf_range(-0.3, 0.3)), Color(0.55, 0.85, 1.0), 0.25, 0.12, 4)


func _roll_jam() -> void:
	if profile.has("jam_after"):
		var span: Vector2i = profile["jam_after"]
		_until_jam = rng.randi_range(span.x, span.y)


func _muzzle() -> Vector3:
	if _gun_model != null:
		return _gun_model.global_transform * Vector3(0.0, 0.05, profile["muzzle"])
	return titan.camera.global_transform * Vector3(1.2, -1.0, -3.0)
