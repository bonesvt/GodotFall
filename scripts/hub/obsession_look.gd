extends RefCounted
## How Ophelia looks as her obsession (obsession.gd) deepens, put on her hub
## model each stay (run_manager.gd enter_hub, after her idle is picked):
##   0 calm       as she is
##   1 upset      Eco left without saying goodbye: hurt, won't look, her makeup
##                run down her cheeks from crying (outfit "upset")
##   2 clingy     (meter CLINGY_AT) in a hoodie dyed Eco's red and teal with a
##                spanner-heart charm, waiting on her doorstep, watching the path
##                (outfit "clingy")
## Her outfits for these (hub_npc.gd MISSION_OUTFITS) are painted from her own
## textures by tools/npc/paint_ophelia_obsession.gd.
##   3 obsessed   (meter OBSESSED_AT) yandere: the light gone out of her eyes
##                (no highlights, irises dark rose), eyes held wide and unblinking
##                over a sweet, too-wide smile, a flush on her cheeks, head
##                tilted; her violet streak burning hot rose against the black;
##                her top deep rose-black under rose lace, black lace sleeves,
##                dark-rose liner and lips (outfit "obsessed").
##                It gets worse the higher the meter goes (stare())
## Mature only; once Eco's helped her and it's worn off, she's herself again.

const Obsession := preload("res://scripts/hub/obsession.gd")
const HubRooms := preload("res://scripts/hub/hub_rooms.gd")

const CLINGY_AT := 25.0
const OBSESSED_AT := 50.0
const ROSE := Color(1.0, 0.45, 0.68)


static func stage() -> int:
	if not Obsession.allowed():
		return 0
	if Obsession.meter >= OBSESSED_AT:
		return 3
	if Obsession.meter >= CLINGY_AT:
		return 2
	if Obsession.upset or Obsession.meter > 0.0:
		return 1
	return 0


## Puts this stay's look on her (`info`: the hub's, for her talk spot).
static func dress(npc: Node3D, info: Dictionary) -> void:
	var s := stage()
	_tint(npc, s >= 3)
	match s:
		1:
			npc.wear("upset")
			npc.rest_mood = ["sad", "lookaway"]
			npc.calm()
		2, 3:
			npc.wear("obsessed" if s == 3 else "clingy")
			var door: Array = HubRooms.doorstep("ophelia")
			var at: Vector3 = door[0] + (door[1] as Vector3) * -0.4  # just off the step, out front
			for p in npc.find_children("*", "Node3D", true, false):
				if p.has_meta("idle_prop"):
					p.get_parent().remove_child(p)
					p.queue_free()
			npc.position = at
			npc.home_yaw = PI  # facing out, down the path she'll come up
			npc.rotation.y = npc.home_yaw
			npc.posed = false
			npc.spot = "doorstep"
			if npc._anim != null and npc._anim.has_animation("idle"):
				npc._anim.play("idle", 0.3)
			# obsessed: chin down, looking up at you through her fringe, so her eyes sit in shadow
			npc.rest_mood = ["down", "blush"] if s == 3 else ["sad"]
			npc.calm()
			for spec in info.get("interactables", []):
				if spec.get("npc", "") == "ophelia":
					spec["pos"] = at
	_stare(npc, stare() if s >= 3 else 0.0)
	_pack(npc, s >= 3)


## How far gone the stare is, 0..1 (from OBSESSED_AT to full).
static func stare() -> float:
	return clampf((Obsession.meter - OBSESSED_AT) / (100.0 - OBSESSED_AT), 0.0, 1.0) * 0.6 + 0.4


## Dead eyes held wide over a sweet smile (her VRoid face shapes), k 0..1.
static func _stare(npc: Node3D, k: float) -> void:
	for mi in npc.find_children("*", "MeshInstance3D", true, false):
		var m3: MeshInstance3D = mi
		for shape in [["Fcl_EYE_Highlight_Hide", 1.0], ["Fcl_EYE_Spread", 0.7], ["Fcl_MTH_Joy", 0.75], ["Fcl_MTH_Up", 0.3]]:
			var b := m3.find_blend_shape_by_name(shape[0])
			if b >= 0:
				m3.set_blend_shape_value(b, float(shape[1]) * (1.0 if shape[0] == "Fcl_EYE_Highlight_Hide" and k > 0.0 else k))


## What she says the first time Eco comes to her each stay, once she's obsessed.
const GREETING := "Ophelia, not blinking: \"You came back. You always come back.\""


## A pack of her Night Owls in her right hand, turning over and over in her
## fingers (or gone).
static func _pack(npc: Node3D, on: bool) -> void:
	var skel := npc.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	var old := skel.get_node_or_null("KeepsakePack")
	if old != null:
		old.queue_free()
	if not on or skel.find_bone("J_Bip_R_Hand") < 0:
		return
	var att := BoneAttachment3D.new()
	att.name = "KeepsakePack"
	att.bone_name = "J_Bip_R_Hand"
	skel.add_child(att)
	var pack := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.055, 0.085, 0.022)
	pack.mesh = box
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.05, 0.05, 0.06)
	pack.material_override = black
	var band := MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3(0.057, 0.012, 0.024)
	band.mesh = strip
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.65, 0.25)
	gold.metallic = 0.8
	band.material_override = gold
	band.position = Vector3(0, 0.025, 0)
	pack.add_child(band)
	var hold := Node3D.new()
	hold.position = Vector3(0, -0.07, -0.02)
	att.add_child(hold)
	hold.add_child(pack)
	var spin := pack.create_tween().set_loops()
	spin.tween_property(pack, "rotation:y", TAU, 2.8).from(0.0)


## Her hair streak and eyes, rose (or back to her own).
static func _tint(npc: Node3D, rose: bool) -> void:
	for mi in npc.find_children("*", "MeshInstance3D", true, false):
		var m3: MeshInstance3D = mi
		if m3.mesh == null:
			continue
		for i in m3.mesh.get_surface_count():
			var base := m3.mesh.surface_get_material(i) as ShaderMaterial
			if base == null:
				continue
			var n := base.resource_name
			var hair := n.contains("hair_streak")
			var eye := n.contains("iris")
			if not (hair or eye):
				continue
			if not rose:
				if m3.get_surface_override_material(i) != null and m3.get_surface_override_material(i).has_meta("obsession"):
					m3.set_surface_override_material(i, null)
				continue
			var mine: ShaderMaterial = base.duplicate()
			mine.set_meta("obsession", true)
			if hair:
				var c = mine.get_shader_parameter("albedo")
				var col: Color = c if c is Color else Color.WHITE
				mine.set_shader_parameter("albedo", Color(1.0, 0.25, 0.5, col.a))
				mine.set_shader_parameter("emission", ROSE)
				mine.set_shader_parameter("emission_energy", 0.9)
			else:
				# the light gone out of them: dark, dull rose
				mine.set_shader_parameter("albedo", Color(0.42, 0.08, 0.16))
				mine.set_shader_parameter("emission", Color(0.5, 0.05, 0.15))
				mine.set_shader_parameter("emission_energy", 0.25)
			m3.set_surface_override_material(i, mine)
