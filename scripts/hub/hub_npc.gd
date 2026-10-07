extends Node3D
## One of the people who live in the hub with Eco (Mom, Ophelia, Biggie): their
## model (assets/models/npc/<who>.glb, built by tools/npc/build_npc.py), an
## idle loop, a "talk" loop while they speak, their mouth moving with their
## voice, and a slow turn toward Eco when she comes close. npc_talk.gd runs
## the conversations.
##
## Moods (mood()): a face from the VRoid expression shapes, a blush on the
## cheeks (npc_blush.gdshader) that fades slowly, and head gestures laid over
## whatever animation is playing:
##   faces     smile, joy, sad, angry, surprised, closed, plain
##   blush     blush, fluster (a deep one)
##   gestures  lookaway, down, tilt, nod, shake
##   shy       blush + lookaway + smile

## How close (m) Eco has to be before they turn to face her.
const NOTICE_RANGE := 4.5
const TURN_SPEED := 2.5
## The furthest (degrees) they turn from where they stand facing to follow
## Eco; past that they hold at the limit rather than spin round after her.
const MAX_TURN := 60.0
## Who has more than one outfit (body.png first, then body_<outfit>.png from
## tools/npc/build_npc.py). They change between runs.
const OUTFITS := {"ophelia": ["tee", "hoodie", "night"], "mom": ["home", "night"]}
## Outfits only worn on missions, never picked for the hub (Ophelia's
## detainee rags, and the colony's torn intake suit she's held in at Level 2's
## stasis column, "colony" for Teen and "colony_m" for Mature):
## body_<outfit>.png too. An outfit can bring its own face (face_<outfit>.png:
## the ruined make-up) and hair blend shape (MESS: frizzed from the fight).
const MISSION_OUTFITS := {"ophelia": ["prison", "colony", "colony_m"]}
## Outfits worn barefoot or in socks: the boots come off.
const NO_BOOTS := ["night", "prison", "colony", "colony_m"]
## The hair blend shape an outfit turns on (tools/npc/build_npc.py mess_colony()).
const MESS := {"colony": "mess_colony", "colony_m": "mess_colony"}

const NpcSprings := preload("res://scripts/hub/npc_springs.gd")
const Hair := preload("res://scripts/hub/hair.gd")
const Wardrobe := preload("res://scripts/hub/wardrobe.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

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
## The content rating the meshes were last shown for (the O key can change it in the hub).
var _rating_seen := ""
## The face mood on now ("" plain), how red the cheeks are (0..1, fading on
## its own), and the head gesture with how long it has run.
## Holding one of their poses (npc_idles.gd): they don't turn on the spot
## or switch to their talk loop, just talk from where they are.
var posed := false
var spot := ""
## The mood they settle back into (their spot's: eyes shut by the records).
var rest_mood: Array = []
var face := ""
var blush := 0.0
var gesture := ""
var _gesture_t := 0.0
var _faces: Array = []   # [[MeshInstance3D, {face: [[blend index, weight], ...]}]]
var _blush_mats: Array = []
var _head: HeadPose
## Their soft capsule (_add_body), when they were last bumped (_t), and how
## far (world space) a bump has rocked them off their feet, easing back.
var soft_body: AnimatableBody3D
var _bumped_at := -10.0
var _nudge := Vector3.ZERO
## How wide and soft that capsule is.
const BODY_RADIUS := 0.2
const BODY_SOFTNESS := 0.4

const FACES := {
	"smile": [["Fcl_ALL_Fun", 0.45]],
	"joy": [["Fcl_ALL_Joy", 0.8]],
	"sad": [["Fcl_ALL_Sorrow", 0.75]],
	"angry": [["Fcl_ALL_Angry", 0.7]],
	"surprised": [["Fcl_ALL_Surprised", 0.7]],
	"closed": [["Fcl_EYE_Close", 1.0]],
}
const BLUSH := {"blush": 0.55, "fluster": 1.0}
const GESTURES := ["lookaway", "down", "tilt", "nod", "shake"]
## Seconds for the blush to fade by half once nothing keeps it up.
const BLUSH_HALF_LIFE := 5.0


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
		var springs := NpcSprings.make(who, model.find_child("Skeleton3D", true, false) as Skeleton3D)
		if springs != null:
			add_child(springs)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			_fill_textures(mi)
			var b := (mi as MeshInstance3D).find_blend_shape_by_name("Fcl_MTH_A")
			if b >= 0:
				_mouth.append([mi, b])
			_add_faces(mi)
			_add_blush(mi)
		var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
		if skel != null and skel.find_bone("J_Bip_C_Head") >= 0:
			_head = HeadPose.new()
			_head.npc = self
			skel.add_child(_head)
		Hair.apply(model, who)  # their haircut from the salon in Solace (if they get one)
		_dress_meshes(OUTFITS.get(who, [""])[0])   # in what they're built in until wear()
	if _anim != null and _anim.has_animation("idle"):
		_anim.play("idle")
		_anim.seek(randf() * 3.0, true)   # so they don't breathe in step
	_add_body()
	voice = AudioStreamPlayer3D.new()
	voice.name = "Voice"
	voice.position = Vector3(0, 1.6, 0)
	voice.unit_size = 6.0
	voice.bus = "Voices"
	add_child(voice)


## Something soft for Eco to brush past and press into rather than walk
## through: a slim capsule about their middle, as soft as a padded wall
## (player.gd soft_press reads "softness"), in group "npc_body".
func _add_body() -> void:
	soft_body = AnimatableBody3D.new()
	soft_body.name = "Body"
	soft_body.sync_to_physics = false
	soft_body.set_meta("softness", BODY_SOFTNESS)
	soft_body.add_to_group("npc_body")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = BODY_RADIUS
	cap.height = 1.6
	col.shape = cap
	col.position = Vector3(0, 0.8, 0)
	soft_body.add_child(col)
	add_child(soft_body)


## Eco brushed or pressed into them (player.gd soft_press): they glance at
## her, a little surprised, and give a touch of ground. Not more than every
## couple of seconds.
func bumped(from: Vector3) -> bool:
	if _t - _bumped_at < 2.0:
		return false
	_bumped_at = _t
	if not posed:
		mood(["surprised", "tilt"])
		var away := global_position - from
		away.y = 0.0
		if away.length() > 0.01:
			_nudge = away.normalized() * 0.06
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(self) and face == "surprised":
			calm())
	return true


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


func _add_faces(mi: MeshInstance3D) -> void:
	var map := {}
	for f in FACES:
		var shapes := []
		for sw in FACES[f]:
			var i := mi.find_blend_shape_by_name(sw[0])
			if i >= 0:
				shapes.append([i, sw[1]])
		if not shapes.is_empty():
			map[f] = shapes
	if not map.is_empty():
		_faces.append([mi, map])


## Slots the blush pass in after the face material (before its ink outline),
## on a copy so the shared material from the model stays as it was.
func _add_blush(mi: MeshInstance3D) -> void:
	for i in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(i) as ShaderMaterial
		if mat == null or mat.resource_name != "npc_%s_face" % who:
			continue
		var mine: ShaderMaterial = mat.duplicate()
		var pass_ := ShaderMaterial.new()
		pass_.shader = preload("res://assets/shaders/npc_blush.gdshader")
		pass_.next_pass = mat.next_pass
		mine.next_pass = pass_
		mi.set_surface_override_material(i, mine)
		_blush_mats.append(pass_)


## Sets their mood from a list of words (see the top of this file); unknown
## words are ignored. The face and gesture hold until the next mood() or
## calm(); the blush only ever rises here and fades by itself.
func mood(words: Array) -> void:
	for w in words:
		w = String(w).strip_edges()
		if w == "shy":
			mood(["blush", "lookaway", "smile"])
		elif FACES.has(w) or w == "plain":
			face = "" if w == "plain" else w
		elif BLUSH.has(w):
			blush = maxf(blush, BLUSH[w])
		elif w in GESTURES:
			gesture = w
			_gesture_t = 0.0


## Where their head is now (for cameras), in world space.
func head_position() -> Vector3:
	var skel := find_child("Skeleton3D", true, false) as Skeleton3D
	if skel != null:
		var i := skel.find_bone("J_Bip_C_Head")
		if i >= 0:
			return skel.global_transform * skel.get_bone_global_pose(i).origin + Vector3(0, 0.08, 0)
	return global_position + Vector3(0, 1.45, 0)


## Back to their resting face and head (the blush keeps fading on its own).
func calm() -> void:
	face = ""
	gesture = ""
	mood(rest_mood)


## Puts on their outfit for run number `run`: the one picked for them at
## Eco's wardrobe (wardrobe.gd), or else the same all through a stay in the
## hub and a different one after each run.
func wear_for_run(run: int) -> void:
	var list: Array = OUTFITS.get(who, [])
	if list.is_empty():
		return
	var pick := Wardrobe.choice(who)
	wear(pick if list.has(pick) else list[run % list.size()])


func wear(p_outfit: String) -> void:
	var list: Array = OUTFITS.get(who, [])
	if not list.has(p_outfit) and not MISSION_OUTFITS.get(who, []).has(p_outfit):
		return
	var path := "res://assets/textures/npc/%s/%s.png" % [who, "body" if p_outfit == list[0] else "body_" + p_outfit]
	if not ResourceLoader.exists(path):
		return
	outfit = p_outfit
	_dress_meshes(p_outfit)
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
	_dress_face(p_outfit)


## The outfit's own face texture (face_<outfit>.png) or their usual one, and
## its hair blend shape on (any other outfit's off).
func _dress_face(p_outfit: String) -> void:
	var path := "res://assets/textures/npc/%s/face_%s.png" % [who, p_outfit]
	if not ResourceLoader.exists(path):
		path = "res://assets/textures/npc/%s/face.png" % who
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	for mi in find_children("*", "MeshInstance3D", true, false):
		for shape in MESS.values():
			var b: int = mi.find_blend_shape_by_name(shape)
			if b >= 0:
				mi.set_blend_shape_value(b, 1.0 if MESS.get(p_outfit, "") == shape else 0.0)
		if tex == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as ShaderMaterial
			if mat == null or mat.resource_name != "npc_%s_face" % who:
				continue
			var mine := mi.get_surface_override_material(i) as ShaderMaterial
			if mine == null:
				mine = mat.duplicate()
				mi.set_surface_override_material(i, mine)
			mine.set_shader_parameter("albedo_tex", tex)


## Shows an outfit's own meshes (Outfit_<outfit>_*: Mom's nightgown,
## Ophelia's pajama legs) and hides every other outfit's, and the boots when
## the outfit has none. Ophelia's piercings ("Piercings") show only with the
## content rating on Mature (or above), and never in a mission outfit.
func _dress_meshes(p_outfit: String) -> void:
	_rating_seen = ContentRating.current()
	for mi in find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		if n.begins_with("Piercings"):
			# never on a captive (mission outfits): nothing on her chest shows through
			mi.visible = mature() and not MISSION_OUTFITS.get(who, []).has(p_outfit)
		elif n.begins_with("Outfit_"):
			mi.visible = n.begins_with("Outfit_%s_" % p_outfit)
		elif n.begins_with("Boots"):
			mi.visible = not p_outfit in NO_BOOTS


## Whether the content rating lets mature details show (anything above Teen).
static func mature() -> bool:
	return not ContentRating.current() in ["E", "T"]


func say(stream: AudioStream) -> void:
	talking = true
	if _anim != null and not posed and _anim.has_animation("talk") and _anim.current_animation != "talk":
		_anim.play("talk", 0.3)
	if stream != null:
		voice.stream = stream
		voice.play()


func hush() -> void:
	talking = false
	voice.stop()
	if _anim != null and not posed and _anim.has_animation("idle") and _anim.current_animation != "idle":
		_anim.play("idle", 0.4)


func _process(delta: float) -> void:
	if _rating_seen != ContentRating.current():
		_dress_meshes(outfit if outfit != "" else OUTFITS.get(who, [""])[0])
	_t += delta
	# Turn toward Eco when she's close, back to their spot when she leaves.
	var want := home_yaw
	if look_target != null and is_instance_valid(look_target):
		var d := look_target.global_position - global_position
		if not posed and (Vector2(d.x, d.z).length() < NOTICE_RANGE or talking):
			var toward := angle_difference(home_yaw, atan2(-d.x, -d.z))   # the model faces -Z
			var most := deg_to_rad(MAX_TURN)
			want = home_yaw + clampf(toward, -most, most)
	rotation.y = lerp_angle(rotation.y, want, minf(1.0, delta * TURN_SPEED))
	# Mouth flaps while their voice plays.
	var open := 0.0
	if voice != null and voice.playing:
		open = clampf(0.35 + 0.4 * sin(_t * 17.0) * sin(_t * 5.3 + 1.0), 0.0, 0.8)
	for m in _mouth:
		var mi: MeshInstance3D = m[0]
		mi.set_blend_shape_value(m[1], lerpf(mi.get_blend_shape_value(m[1]), open, minf(1.0, delta * 20.0)))
	# Faces ease in and out; the blush fades.
	var k := minf(1.0, delta * 6.0)
	for fm in _faces:
		var mi: MeshInstance3D = fm[0]
		for f in fm[1]:
			for sw in fm[1][f]:
				var w := float(sw[1]) if f == face else 0.0
				mi.set_blend_shape_value(sw[0], lerpf(mi.get_blend_shape_value(sw[0]), w, k))
	blush *= pow(0.5, delta / BLUSH_HALF_LIFE)
	if blush < 0.01:
		blush = 0.0
	for b in _blush_mats:
		b.set_shader_parameter("amount", blush)
	_gesture_t += delta
	# a bump rocks them a few centimetres off their feet and back
	var model := get_node_or_null("Model") as Node3D
	if model != null and (_nudge != Vector3.ZERO or model.position != Vector3.ZERO):
		model.position = model.position.lerp(global_basis.inverse() * _nudge, minf(1.0, delta * 12.0))
		_nudge = _nudge.move_toward(Vector3.ZERO, delta * 0.15)
		if _nudge == Vector3.ZERO and model.position.length() < 0.001:
			model.position = Vector3.ZERO


## How the head sits for the gesture on now, as (yaw, pitch, roll) radians:
## + yaw turns to their left, + pitch looks down, + roll tips toward their
## right shoulder. Nod and shake play once and settle.
func gesture_angles() -> Vector3:
	var t := _gesture_t
	match gesture:
		"lookaway":
			return Vector3(0.45, 0.22, 0.08) * smoothstep(0.0, 0.5, t)
		"down":
			return Vector3(0.0, 0.32, 0.0) * smoothstep(0.0, 0.5, t)
		"tilt":
			return Vector3(0.05, 0.03, 0.22) * smoothstep(0.0, 0.45, t)
		"nod":
			return Vector3(0.0, 0.2 * sin(t * TAU * 1.6) * maxf(0.0, 1.0 - t / 1.3), 0.0)
		"shake":
			return Vector3(0.24 * sin(t * TAU * 1.8) * maxf(0.0, 1.0 - t / 1.4), 0.0, 0.0)
	return Vector3.ZERO


## Lays the gesture over the head and neck after the animation has posed them.
class HeadPose extends SkeletonModifier3D:
	var npc
	var _now := Vector3.ZERO

	func _process_modification() -> void:
		var skel := get_skeleton()
		if skel == null or npc == null:
			return
		_now = _now.lerp(npc.gesture_angles(), minf(1.0, get_process_delta_time() * 8.0))
		if _now.length() < 0.001:
			return
		# Two thirds in the head, a third in the neck; the axes are the
		# model's (it faces -Z), whatever the bones' own rest rotations.
		for bone in [["J_Bip_C_Head", 0.67], ["J_Bip_C_Neck", 0.33]]:
			var i := skel.find_bone(bone[0])
			if i < 0:
				continue
			var a: Vector3 = _now * float(bone[1])
			var turn := Basis(Vector3.UP, a.x) * Basis(Vector3.RIGHT, -a.y) * Basis(Vector3.BACK, -a.z)
			var global_pose := skel.get_bone_global_pose(i)
			var parent := skel.get_bone_parent(i)
			var parent_pose := skel.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
			global_pose.basis = Basis(turn.get_rotation_quaternion()) * global_pose.basis
			skel.set_bone_pose_rotation(i, (parent_pose.basis.inverse() * global_pose.basis).get_rotation_quaternion())
