extends RefCounted
## Where the hub people hang out between talks, and the poses they strike in
## their heart scenes. Each hub stay picks one of their spots (the first
## stay is always their plain stand, so first meetings happen on their feet):
## they're moved there, play that spot's pose from their poses file
## (assets/models/npc/<who>_poses.glb, tools/npc/build_poses.py) and hold it
## while they talk, turning only their head.
##
## Spots are in their room's coordinates (hub_rooms.gd), with any props the
## pose needs: a lit cigarette with its smoke, a book.

const Rooms := preload("res://scripts/hub/hub_rooms.gd")
const Kit := preload("res://scripts/hub/hub_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

const LIB := "poses"


## Ophelia's room, inside faces: x0 west wall, x1 east wall, zb back wall.
static func _oph() -> Dictionary:
	var r := Rooms.OPHELIA_ROOM
	var x0 := r.position.x + Rooms.T
	var x1 := r.end.x - Rooms.T
	var zb := r.position.y + Rooms.T
	var f := Rooms.F
	return {
		# where hub_rooms puts her, facing the door
		"stand": {"pos": Vector3(x0 + 4.6, f, zb + 3.4), "yaw": 180.0, "anim": ""},
		# on the mattress in the back corner, head on the pillows (west end)
		"lounge": {"pos": Vector3(x0 + 1.55, f, zb + 1.25), "yaw": -90.0, "anim": "idle_lounge", "talk": Vector3(x0 + 2.6, f, zb + 2.6)},
		# by the window on the back wall, looking into the room
		"smoke": {"pos": Vector3(x1 - 2.55, f, zb + 0.55), "yaw": 160.0, "anim": "idle_smoke", "props": ["cigarette"]},
		# cross-legged on the rug by her notebooks
		"read": {"pos": Vector3(x0 + 3.4, f, zb + 3.0), "yaw": 150.0, "anim": "idle_read", "props": ["book"]},
		# by the record player, eyes shut
		"sway": {"pos": Vector3(x1 - 1.4, f, zb + 4.4), "yaw": -110.0, "anim": "idle_sway", "mood": ["closed"]},
		# heart scenes
		"sit": {"pos": Vector3(x0 + 4.4, f, zb + 2.8), "yaw": 180.0, "anim": "scene_sit"},
		"mirror": {"pos": Vector3(x1 - 1.0, f, zb + 1.2), "yaw": 200.0, "anim": "scene_mirror"},
		"shy": {"pos": Vector3(x0 + 4.6, f, zb + 3.4), "yaw": 180.0, "anim": "scene_shy"},
	}


const IDLE_SPOTS := {"ophelia": ["lounge", "smoke", "read", "sway", "stand"]}


static func spots(who: String) -> Dictionary:
	return _oph() if who == "ophelia" else {}


## Picks and takes their spot for hub stay `run` (0: the first). Moves their
## "[F] Talk" spot in `info` with them. Returns the spot's name, or "".
static func settle(npc: Node3D, info: Dictionary, run: int) -> String:
	var list: Array = IDLE_SPOTS.get(npc.who, [])
	if list.is_empty():
		return ""
	var spot := "stand"
	if run > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s|%d" % [npc.who, run])
		spot = list[rng.randi_range(0, list.size() - 1)]
	take(npc, spot, info)
	return spot


## Moves them to `spot` and strikes its pose (props and all).
static func take(npc: Node3D, spot: String, info := {}) -> void:
	var s: Dictionary = spots(npc.who).get(spot, {})
	if s.is_empty():
		return
	npc.position = s["pos"]
	npc.home_yaw = deg_to_rad(s["yaw"])
	npc.rotation.y = npc.home_yaw
	npc.spot = spot
	for p in npc.find_children("*", "BoneAttachment3D", true, false):
		if p.has_meta("idle_prop"):
			p.get_parent().remove_child(p)
			p.queue_free()
	var anim: String = s["anim"]
	npc.posed = anim != ""
	if npc._anim != null:
		_load_poses(npc)
		var name := LIB + "/" + anim if anim != "" else "idle"
		if npc._anim.has_animation(name):
			npc._anim.play(name, 0.3)
	npc.rest_mood = s.get("mood", [])
	npc.calm()
	for prop in s.get("props", []):
		_prop(npc, prop)
	for spec in info.get("interactables", []):
		if spec.get("npc", "") == npc.who:
			spec["pos"] = s.get("talk", s["pos"])


static func _load_poses(npc: Node3D) -> void:
	if npc._anim.has_animation_library(LIB):
		return
	var path := "res://assets/models/npc/%s_poses.glb" % npc.who
	if not ResourceLoader.exists(path):
		return
	var src: Node = load(path).instantiate()
	var ap := src.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		var lib := AnimationLibrary.new()
		for a in ap.get_animation_list():
			var anim: Animation = ap.get_animation(a).duplicate()
			anim.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(a, anim)
		npc._anim.add_animation_library(LIB, lib)
	src.free()


## A prop on one of their bones.
static func _prop(npc: Node3D, kind: String) -> void:
	var skel := npc.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	var at := BoneAttachment3D.new()
	at.set_meta("idle_prop", true)
	skel.add_child(at)
	# props are built in metres; undo whatever scale the bone carries
	var bone := skel.find_bone("J_Bip_R_Index2" if kind == "cigarette" else "J_Bip_L_Hand")
	var unscale := Vector3.ONE
	if bone >= 0:
		var sc := (skel.global_transform * skel.get_bone_global_pose(bone)).basis.get_scale()
		unscale = Vector3(1.0 / sc.x, 1.0 / sc.y, 1.0 / sc.z)
	match kind:
		"cigarette":
			at.bone_name = "J_Bip_R_Index2"
			var cig := Node3D.new()
			cig.position = Vector3(0.0, 0.0, 0.0)
			cig.rotation_degrees = Vector3(0, 0, 90)
			cig.scale = unscale
			at.add_child(cig)
			Kit.mesh(cig, Vector3(0, 0.03, 0), Vector3(0.008, 0.075, 0.008), Art.material("canvas", Color(0.95, 0.93, 0.88)))
			Kit.glow(cig, Vector3(0, 0.07, 0), Vector3(0.009, 0.01, 0.009), Color(1.0, 0.35, 0.1))
			var smoke := CPUParticles3D.new()
			smoke.position = Vector3(0, 0.075, 0)
			smoke.amount = 24
			smoke.lifetime = 2.6
			# drifts up through the room, whichever way her hand holds it
			smoke.local_coords = false
			smoke.spread = 180.0
			smoke.gravity = Vector3(0.015, 0.1, 0)
			smoke.initial_velocity_min = 0.0
			smoke.initial_velocity_max = 0.015
			smoke.scale_amount_min = 0.5
			smoke.scale_amount_max = 1.4
			var grow := Curve.new()
			grow.add_point(Vector2(0, 0.4))
			grow.add_point(Vector2(1, 1.6))
			smoke.scale_amount_curve = grow
			var puff := QuadMesh.new()
			puff.size = Vector2(0.06, 0.06)
			var soft := GradientTexture2D.new()
			soft.fill = GradientTexture2D.FILL_RADIAL
			soft.fill_from = Vector2(0.5, 0.5)
			soft.fill_to = Vector2(1.0, 0.5)
			soft.width = 32
			soft.height = 32
			var falloff := Gradient.new()
			falloff.set_color(0, Color(1, 1, 1, 1))
			falloff.set_color(1, Color(1, 1, 1, 0))
			soft.gradient = falloff
			var m := StandardMaterial3D.new()
			m.albedo_texture = soft
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.albedo_color = Color(0.8, 0.8, 0.85, 0.35)
			m.vertex_color_use_as_albedo = true
			puff.material = m
			smoke.mesh = puff
			var fade := Gradient.new()
			fade.set_color(0, Color(1, 1, 1, 0.9))
			fade.set_color(1, Color(1, 1, 1, 0.0))
			smoke.color_ramp = fade
			cig.add_child(smoke)
			var ember := OmniLight3D.new()
			ember.light_color = Color(1.0, 0.45, 0.15)
			ember.light_energy = 0.35
			ember.omni_range = 0.5
			ember.position = Vector3(0, 0.07, 0)
			cig.add_child(ember)
		"book":
			at.bone_name = "J_Bip_L_Hand"
			var book := Node3D.new()
			book.position = Vector3(-0.07, -0.02, 0.0)
			book.scale = unscale
			at.add_child(book)
			Kit.mesh(book, Vector3.ZERO, Vector3(0.16, 0.025, 0.22), Art.material("canvas", Color(0.12, 0.08, 0.1)))
			Kit.mesh(book, Vector3(0, 0.014, 0), Vector3(0.15, 0.006, 0.21), Art.material("canvas", Color(0.86, 0.82, 0.72)))


## A moonlit window cut into Ophelia's back-wall drapes (for her smoking spot).
static func build_window(root: Node3D) -> void:
	var r := Rooms.OPHELIA_ROOM
	var x1 := r.end.x - Rooms.T
	var zb := r.position.y + Rooms.T
	var f := Rooms.F
	var c := Vector3(x1 - 1.7, f + 1.75, zb + 0.14)
	var frame := Art.material("timber", Color(0.35, 0.3, 0.32))
	Kit.glow(root, c, Vector3(0.95, 1.15, 0.02), Color(0.32, 0.4, 0.75))
	Kit.mesh(root, c + Vector3(0, 0.6, 0.02), Vector3(1.1, 0.08, 0.08), frame)
	Kit.mesh(root, c + Vector3(0, -0.6, 0.05), Vector3(1.2, 0.07, 0.18), frame)
	Kit.mesh(root, c + Vector3(-0.52, 0, 0.02), Vector3(0.08, 1.25, 0.08), frame)
	Kit.mesh(root, c + Vector3(0.52, 0, 0.02), Vector3(0.08, 1.25, 0.08), frame)
	Kit.mesh(root, c + Vector3(0, 0, 0.02), Vector3(0.04, 1.15, 0.04), frame)
	Kit.mesh(root, c + Vector3(0, 0.05, 0.02), Vector3(0.95, 0.04, 0.04), frame)
	var moon := SpotLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 2.2
	moon.spot_range = 6.0
	moon.spot_angle = 32.0
	moon.position = c + Vector3(0, 0.4, -0.05)
	root.add_child(moon)
	moon.look_at(c + Vector3(0.2, -1.6, 2.0))
