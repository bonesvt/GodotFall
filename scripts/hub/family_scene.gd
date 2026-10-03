extends Node3D
## Stages the Motherly Love scenes (family.gd) in Mom's room: curling up with
## her on her bed, and Mom looking after Eco in it when she comes home sick.
## run_manager.gd adds one to the hub; its spot by Mom's bed opens a cuddle
## once the bond allows it (one a hub stay), and talking to Mom while Eco is
## sick tucks her into Mom's bed instead.
##
## While a scene plays, the pilot is parked and hidden, a camera frames the
## bed, Mom walks over (well, is there) in a held pose (family_poses.gd), a
## posed copy of Eco's model lies or sits with her, and the talk (npc_talk.gd
## cuddle() / care()) runs as usual. When the talk ends everything goes back.

const Family := preload("res://scripts/hub/family.gd")
const Poses := preload("res://scripts/hub/family_poses.gd")
const HubRooms := preload("res://scripts/hub/hub_rooms.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const ECO := preload("res://assets/models/eco.tscn")
const FamilyBed := preload("res://scripts/hub/family_bed.gd")

const SPOT_ID := "family_bed"
const SPOT_REACH := 1.8

## The run manager (player, hub_npcs, npc_talk, hud, pilot_hud, runs_ended).
var rm: Node
## "cuddle" or "sick" while one plays, else "".
var playing := ""
var eco: Node3D
var _props: Array = []
var _camera: Camera3D
var _mom_pose: SkeletonModifier3D
var _mom_saved := {}
var _cloth: Node3D
var _bowl: Node3D
## The bed's own quilt (hidden while a scene lays its own over them), and
## the bodies the scene's quilt still waits to drape over: {who: capsules}.
var _room_quilt: Node3D
var _drape := {}
var _drape_to := 0.0
var _f := HubRooms.F


## Mom's bed in hub coordinates: the middle of the mattress, head end at +Z.
static func bed() -> Vector3:
	var r: Rect2 = HubRooms.MOM_ROOM
	return Vector3(r.position.x + HubRooms.T + 1.1, HubRooms.F, r.end.y - HubRooms.T - 1.15)


## Adds the spot by Mom's bed to the hub's interactables.
func setup(p_rm: Node, info: Dictionary) -> void:
	rm = p_rm
	name = "FamilyScene"
	var at := bed() + Vector3(1.1, 0.1, -0.6)
	info["interactables"].append({"id": SPOT_ID, "pos": at, "range": SPOT_REACH, "prompt": "", "lines": [], "family": true})
	rm.npc_talk.finished.connect(_on_talk_finished)


func _mom() -> Node3D:
	return rm.hub_npcs.get("mom")


## What the bed spot says now ("" when there's nothing to do there).
func prompt() -> String:
	var mom := _mom()
	if mom == null or playing != "":
		return ""
	var talk = rm.npc_talk
	if Family.sick(talk.state, rm.runs_ended):
		return "[F] Crawl into Mom's bed (you're burning up)"
	if Family.can_cuddle(talk.state, talk.bank("mom"), "mom", rm.runs_ended):
		return "[F] Curl up with Mom"
	return ""


## F at the bed spot: the sick scene if Eco's sick, else a cuddle if one's open.
func use() -> bool:
	if Family.sick(rm.npc_talk.state, rm.runs_ended):
		return care()
	return cuddle()


func cuddle() -> bool:
	var mom := _mom()
	var talk = rm.npc_talk
	if mom == null or playing != "" or not Family.can_cuddle(talk.state, talk.bank("mom"), "mom", rm.runs_ended):
		return false
	_stage("cuddle")
	if not talk.cuddle(mom, rm.runs_ended):
		_unstage()
		return false
	return true


## Mom looks after Eco (talking to Mom while sick lands here too).
func care() -> bool:
	var mom := _mom()
	if mom == null or playing != "" or not Family.sick(rm.npc_talk.state, rm.runs_ended):
		return false
	_stage("sick")
	if not rm.npc_talk.care(mom, rm.runs_ended):
		_unstage()
		return false
	return true


func _on_talk_finished(_who: String) -> void:
	if playing != "":
		_unstage()


## The cloth on Eco's brow and the bowl in Mom's hands follow their poses.
func _place_cloth(skel: Skeleton3D) -> void:
	if _cloth != null and eco != null and eco.is_ancestor_of(skel):
		_cloth.global_position = _bone_world(skel, "J_Bip_C_Head") + Vector3(0, 0.13, 0.06)


## Lays the scene's quilt over the posed bodies once each pose has been on
## for an update (their bones only read back then), up to `head_z`. `arms`
## tucks Eco's arms under it too.
func _drape_over(poses: Dictionary, head_z: float, arms := false) -> void:
	_drape = {}
	_drape_to = head_z
	for who in poses:
		_drape[who] = null
		var hold = poses[who]
		hold.after = func(skel: Skeleton3D) -> void:
			if _drape.get(who, 0) == null:
				_drape[who] = FamilyBed.capsules(skel, arms and who == "eco")
				if not _drape.values().has(null):
					_lay_quilt.call_deferred()
			_place_cloth(skel)
			_place_bowl(skel)


func _lay_quilt() -> void:
	if playing == "" or _drape.is_empty():
		return
	var caps := []
	for who in _drape:
		caps.append_array(_drape[who])
	_drape = {}
	var quilt := FamilyBed.drape(bed(), _drape_to, caps)
	add_child(quilt)
	_props.append(quilt)


func _place_bowl(skel: Skeleton3D) -> void:
	if _bowl != null and _mom() != null and _mom().is_ancestor_of(skel):
		_bowl.global_position = (_bone_world(skel, "J_Bip_R_Hand") + _bone_world(skel, "J_Bip_L_Hand")) * 0.5 + Vector3(0, 0.03, 0)


static func _bone_world(skel: Skeleton3D, bone: String) -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(skel.find_bone(bone)).origin


# --- Staging -------------------------------------------------------------------

func _stage(kind: String) -> void:
	playing = kind
	var b := bed()
	var mom := _mom()
	var talk = rm.npc_talk
	talk.hold = true
	# Park the pilot out of shot.
	rm.player.visible = false
	rm.player.process_mode = Node.PROCESS_MODE_DISABLED
	rm.hud.visible = false
	rm.pilot_hud.visible = false
	# Mom to the bed.
	_mom_saved = {"xform": mom.global_transform, "home_yaw": mom.home_yaw, "look": mom.look_target}
	mom.look_target = null
	eco = ECO.instantiate()
	eco.name = "EcoScene"
	eco.set("idle_motion", false)
	add_child(eco)
	_dress(eco, "casual" if kind == "cuddle" else "sleep")
	_camera = Camera3D.new()
	_camera.fov = 55.0
	add_child(_camera)
	_room_quilt = get_parent().find_child("MomQuilt", true, false) if get_parent() != null else null
	if _room_quilt != null:
		_room_quilt.visible = false
	if kind == "cuddle":
		# Mom against the headboard, Eco sitting between her knees and lying back on her.
		_place(mom, Vector3(b.x, _f - 0.27, b.z + 0.62), 0.0)
		_mom_pose = Poses.hold(mom, "mom_cuddle")
		eco.global_position = Vector3(b.x, _f - 0.31, b.z + 0.05)
		eco.rotation = Vector3.ZERO
		var eco_pose := Poses.hold(eco, "eco_cuddle")
		_face(eco, {"Fcl_EYE_Close": 0.85, "Fcl_ALL_Fun": 0.35})
		_drape_over({"eco": eco_pose, "mom": _mom_pose}, b.z + 0.32, true)
		_look(Vector3(b.x + 1.4, _f + 1.55, b.z - 2.1), Vector3(b.x, _f + 1.0, b.z + 0.4))
	else:
		# Eco tucked in on her back, head on the pillows; Mom on a stool beside her.
		eco.global_position = Vector3(b.x + 0.28, _f + 0.69, b.z - 0.72)
		eco.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
		var eco_pose := Poses.hold(eco, "eco_sick")
		_face(eco, {"Fcl_EYE_Close": 0.75, "Fcl_ALL_Sorrow": 0.4})
		_drape_over({"eco": eco_pose}, b.z + 0.42, true)
		_cloth = MeshInstance3D.new()
		_cloth.mesh = FamilyBed.soft_box(Vector3(0.2, 0.035, 0.1), 0.015)
		_cloth.material_override = FamilyBed.linen()
		add_child(_cloth)
		_props.append(_cloth)
		var stool := b + Vector3(1.2, 0, -0.2)
		_box(stool + Vector3(0, 0.22, 0), Vector3(0.38, 0.44, 0.38), Art.material("wood"))
		var at := Vector3(stool.x, _f - 0.42, stool.z)
		var to := b + Vector3(0.1, 0, 0.55)
		_place(mom, at, atan2(-(to.x - at.x), -(to.z - at.z)))
		_mom_pose = Poses.hold(mom, "mom_sick")
		_mom_pose.after = _place_bowl
		_bowl = _bowl_of_soup()
		_look(Vector3(b.x + 1.85, _f + 1.65, b.z - 0.35), Vector3(b.x + 0.15, _f + 0.8, b.z + 0.45))


func _unstage() -> void:
	var mom := _mom()
	if mom != null and not _mom_saved.is_empty():
		mom.global_transform = _mom_saved["xform"]
		mom.home_yaw = _mom_saved["home_yaw"]
		mom.look_target = _mom_saved["look"]
	if _mom_pose != null:
		_mom_pose.queue_free()
	_mom_pose = null
	_mom_saved = {}
	for p in _props:
		if is_instance_valid(p):
			p.queue_free()
	_props = []
	_cloth = null
	_bowl = null
	_drape = {}
	if _room_quilt != null and is_instance_valid(_room_quilt):
		_room_quilt.visible = true
	_room_quilt = null
	if eco != null:
		eco.queue_free()
	eco = null
	if _camera != null:
		_camera.queue_free()
	_camera = null
	rm.npc_talk.hold = false
	rm.player.visible = true
	rm.player.process_mode = Node.PROCESS_MODE_INHERIT
	var cam := rm.player.get_node_or_null("Head/Camera3D") as Camera3D
	if cam != null:
		cam.make_current()
	rm.hud.visible = true
	rm.pilot_hud.visible = true
	var was := playing
	playing = ""
	if was == "sick":
		rm.hud.toast("The fever broke. Mom says eat something before you go anywhere.", 4.0)


func _place(mom: Node3D, at: Vector3, yaw: float) -> void:
	mom.global_position = at
	mom.home_yaw = yaw
	mom.rotation.y = yaw


func _look(from: Vector3, at: Vector3) -> void:
	_camera.global_position = from
	_camera.look_at(at, Vector3.UP)
	_camera.make_current()


func _box(pos: Vector3, size: Vector3, mat: Material, parent: Node = null) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	(parent if parent != null else self).add_child(mi)
	mi.position = pos
	if parent == null:
		_props.append(mi)
	return mi


## A wooden bowl with soup in it, for Mom's hands.
func _bowl_of_soup() -> MeshInstance3D:
	var cup := CylinderMesh.new()
	cup.top_radius = 0.085
	cup.bottom_radius = 0.055
	cup.height = 0.07
	cup.material = Art.material("wood", Color(0.85, 0.7, 0.55))
	var bowl := MeshInstance3D.new()
	bowl.mesh = cup
	add_child(bowl)
	_props.append(bowl)
	var top := CylinderMesh.new()
	top.top_radius = 0.075
	top.bottom_radius = 0.075
	top.height = 0.01
	top.material = Art.material("canvas", Color(0.9, 0.68, 0.38))
	var soup := MeshInstance3D.new()
	soup.mesh = top
	soup.position = Vector3(0, 0.03, 0)
	bowl.add_child(soup)
	return bowl


## Her nightclothes or casual wear when she has them (eco_model.gd wear(),
## Eco's outfits), else the bare suit without armour.
func _dress(model: Node, outfit: String) -> void:
	model.set("suit_tier", 0)
	if model.has_method("wear"):
		model.call("wear", outfit)


## Sets VRoid face shapes on every mesh that has them.
static func _face(model: Node, shapes: Dictionary) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		for s in shapes:
			var i: int = (mi as MeshInstance3D).find_blend_shape_by_name(s)
			if i >= 0:
				mi.set_blend_shape_value(i, shapes[s])
