extends "res://scripts/grunt.gd"
## A soldier of the Choir, the power across the border. Built on the grunt:
## the same senses (vision cone, cover, tall grass, footsteps, gunshots), the
## same "?" and "!" over its head, the same squad callouts and patrols. What
## changes is the body (assets/models/threats/<model_name>.glb, in Eco's toon
## style) and the tell: instead of a visor turning red, every slit and pipe
## flares from cold cyan to white while a chord rises (choir_chord.wav).
## They never speak, so the militia radio doesn't pick them up (on_radio).
## The units themselves are hush.gd, hound.gd, cantor.gd and seraph.gd.

const ThreatModel := preload("res://scripts/threats/threat_model.gd")
const MODELS := "res://assets/models/threats/%s.glb"
const CYAN := Color(0.55, 0.95, 1.0)

@export var model_name := "hush"
@export var gait := "biped"
@export var body_radius := 0.38
@export var body_height := 2.3
## Hits higher than this above the feet are headshots.
@export var head_y := 1.95

## The militia radio (radio_chatter.gd) leaves the Choir out: they never talk.
var on_radio := false
## Chord sound playing through the current wind-up.
var _chord: Node


func _ready() -> void:
	add_to_group("choir")
	super()


func _build_body() -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = body_radius
	cap.height = body_height
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position.y = body_height * 0.5
	add_child(col)

	model = Node3D.new()
	model.set_script(ThreatModel)
	model.gait = gait
	model.add_child(load(MODELS % model_name).instantiate())
	add_child(model)

	indicator = Label3D.new()
	indicator.name = "Awareness"
	indicator.position.y = body_height + 0.5
	indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	indicator.no_depth_test = true
	indicator.fixed_size = true
	indicator.pixel_size = 0.0022
	indicator.font_size = 64
	indicator.outline_size = 16
	indicator.outline_modulate = Color(0, 0, 0, 0.8)
	indicator.render_priority = 10
	indicator.visible = false
	add_child(indicator)


func _process(delta: float) -> void:
	hurt_timer -= delta
	if model == null:
		return
	model.hurt = hurt_timer > 0.0
	model.tell = _tell()
	_update_indicator(delta)


## 0 to 1: how far into its attack tell it is (cyan to white).
func _tell() -> float:
	if windup_timer < 0.0:
		return 0.15 if alerted else 0.0
	return 1.0 - windup_timer / windup


## The grunt's fire rhythm, with the chord sounding as each wind-up starts.
func _combat(delta: float) -> void:
	if windup_timer >= 0.0:
		windup_timer -= delta
		if windup_timer < 0.0:
			if has_sight:
				_attack()
			fire_timer = fire_interval + rng.randf() * 0.5
		return
	if not has_sight:
		return
	fire_timer -= delta
	if fire_timer <= 0.0:
		windup_timer = windup
		_start_tell()


func _start_tell() -> void:
	SFX.play_at(get_parent(), global_position + Vector3.UP * body_height * 0.8, "choir_chord", -4.0, SFX.vary(0.05))


## The unit's attack, at the end of the wind-up.
func _attack() -> void:
	_shoot()


func is_headshot(pos: Vector3) -> bool:
	return pos.y - global_position.y > head_y


## No words: a porcelain crack and a breath of the chord instead.
func _voice(base: String, volume_db: float) -> void:
	var now := Time.get_ticks_msec()
	if now - voice_at < 500:
		return
	voice_at = now
	var id := "choir_die" if base == "grunt_pain" else SFX.variant("choir_hurt")
	SFX.play_at(get_parent(), global_position + Vector3.UP * body_height * 0.8, id, volume_db, SFX.vary(0.07))


## The fall, and the glow going out.
func _die() -> void:
	super()
	set_process(false)
	if model == null:
		return
	model.set_process(false)
	for g in model.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).set_instance_shader_parameter("glow", 0.0)
		(g as GeometryInstance3D).set_instance_shader_parameter("flash", 0.0)
