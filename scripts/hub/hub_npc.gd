extends Node3D
## One of the people who live in the hub with Eco (Mom, Ophelia, Biggie): their
## model (assets/models/npc/<who>.glb, built by tools/npc/build_npc.py), an
## idle loop, a "talk" loop while they speak, their mouth moving with their
## voice, and a slow turn toward Eco when she comes close. npc_talk.gd runs
## the conversations.

## How close (m) Eco has to be before they turn to face her.
const NOTICE_RANGE := 4.5
const TURN_SPEED := 2.5
## Who has more than one outfit (body.png first, then body_<outfit>.png from
## tools/npc/build_npc.py). They change between runs.
const OUTFITS := {"ophelia": ["tee", "hoodie", "night"]}
const Hair := preload("res://scripts/hub/hair.gd")

var who := ""
var outfit := ""
var home_yaw := 0.0
var voice: AudioStreamPlayer3D
var talking := false
## Who they turn toward when close (the pilot).
var look_target: Node3D
var _anim: AnimationPlayer
var _mouth: Array = []   # [[MeshInstance3D, blend shape index]]
var _t := 0.0


static func create(p_who: String, pos: Vector3, yaw_deg: float) -> Node3D:
	var npc: Node3D = load("res://scripts/hub/hub_npc.gd").new()
	npc.who = p_who
	npc.name = "NPC_" + p_who.capitalize()
	npc.position = pos
	npc.home_yaw = deg_to_rad(yaw_deg)
	npc.rotation.y = npc.home_yaw
	return npc


func _ready() -> void:
	var path := "res://assets/models/npc/%s.glb" % who
	if ResourceLoader.exists(path):
		var model: Node3D = load(path).instantiate()
		model.name = "Model"
		add_child(model)
		_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			_fill_textures(mi)
			var b := (mi as MeshInstance3D).find_blend_shape_by_name("Fcl_MTH_A")
			if b >= 0:
				_mouth.append([mi, b])
		Hair.apply(model, who)  # their haircut from the salon in Solace (if they get one)
	if _anim != null and _anim.has_animation("idle"):
		_anim.play("idle")
		_anim.seek(randf() * 3.0, true)   # so they don't breathe in step
	voice = AudioStreamPlayer3D.new()
	voice.name = "Voice"
	voice.position = Vector3(0, 1.6, 0)
	voice.unit_size = 6.0
	voice.bus = "Master"
	add_child(voice)


## The import script (npc_import.gd) names each material npc_<who>_<part> and
## gives it its texture, but on a fresh import the glb can be imported before
## its textures are, leaving them out. Fill any gaps from the same paths.
func _fill_textures(mi: MeshInstance3D) -> void:
	for i in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(i) as ShaderMaterial
		if mat == null or mat.get_shader_parameter("albedo_tex") != null:
			continue
		var part := mat.resource_name.trim_prefix("npc_%s_" % who)
		var path := "res://assets/textures/npc/%s/%s.png" % [who, part]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		mat.set_shader_parameter("albedo_tex", tex)
		mat.set_shader_parameter("albedo", Color.WHITE)
		var ink := mat.next_pass as ShaderMaterial
		var cut = mat.get_shader_parameter("alpha_cut")
		if ink != null and cut != null and cut > 0.0:
			ink.set_shader_parameter("albedo_tex", tex)


## Puts on their outfit for run number `run` (the same all through a stay in
## the hub, a different one after each run).
func wear_for_run(run: int) -> void:
	var list: Array = OUTFITS.get(who, [])
	if not list.is_empty():
		wear(list[run % list.size()])


func wear(p_outfit: String) -> void:
	var list: Array = OUTFITS.get(who, [])
	if not list.has(p_outfit):
		return
	var path := "res://assets/textures/npc/%s/%s.png" % [who, "body" if p_outfit == list[0] else "body_" + p_outfit]
	if not ResourceLoader.exists(path):
		return
	outfit = p_outfit
	var tex: Texture2D = load(path)
	for mi in find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as ShaderMaterial
			if mat == null or mat.resource_name != "npc_%s_body" % who:
				continue
			var mine := mi.get_surface_override_material(i) as ShaderMaterial
			if mine == null:
				mine = mat.duplicate()
				mi.set_surface_override_material(i, mine)
			mine.set_shader_parameter("albedo_tex", tex)


func say(stream: AudioStream) -> void:
	talking = true
	if _anim != null and _anim.has_animation("talk") and _anim.current_animation != "talk":
		_anim.play("talk", 0.3)
	if stream != null:
		voice.stream = stream
		voice.play()


func hush() -> void:
	talking = false
	voice.stop()
	if _anim != null and _anim.has_animation("idle") and _anim.current_animation != "idle":
		_anim.play("idle", 0.4)


func _process(delta: float) -> void:
	_t += delta
	# Turn toward Eco when she's close, back to their spot when she leaves.
	var want := home_yaw
	if look_target != null and is_instance_valid(look_target):
		var d := look_target.global_position - global_position
		if Vector2(d.x, d.z).length() < NOTICE_RANGE or talking:
			want = atan2(-d.x, -d.z)   # the model faces -Z
	rotation.y = lerp_angle(rotation.y, want, minf(1.0, delta * TURN_SPEED))
	# Mouth flaps while their voice plays.
	var open := 0.0
	if voice != null and voice.playing:
		open = clampf(0.35 + 0.4 * sin(_t * 17.0) * sin(_t * 5.3 + 1.0), 0.0, 0.8)
	for m in _mouth:
		var mi: MeshInstance3D = m[0]
		mi.set_blend_shape_value(m[1], lerpf(mi.get_blend_shape_value(m[1]), open, minf(1.0, delta * 20.0)))
