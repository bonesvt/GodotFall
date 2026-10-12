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
##                It gets worse the higher the meter goes (stare()).
##                Watching: she turns to track Eco anywhere near her tent
##                (WATCH_RANGE), with a photo strip of Eco on her belt
##   4 lacing     (meter LACING_AT) a lighter on a cord, a candle burning on
##                her doorstep, gold-stained fingertips, ECO in pen on the back
##                of her left hand and dark circles under her eyes (textures
##                baked by tools/npc/obsession_textures.gd over "obsessed")
##   5 keeper     (meter KEEPER_AT) her hair all Eco's red, Eco's pilot patches
##                on her shoulders, and Eco's titan key in her hand in place of
##                the pack
## Clingy smiles softly; its spanner-heart charm is painted on (props: _props()).
## Mature only; once Eco's helped her and it's worn off, she's herself again.

const Obsession := preload("res://scripts/hub/obsession.gd")
const HubRooms := preload("res://scripts/hub/hub_rooms.gd")

const CLINGY_AT := 25.0
const OBSESSED_AT := 50.0
const LACING_AT := 75.0
const KEEPER_AT := 90.0
## How far off obsessed Ophelia notices Eco, and how far round she turns.
const WATCH_RANGE := 30.0
const WATCH_TURN := 100.0
## Her lacing-stage skin (tools/npc/obsession_textures.gd).
const LACING_BODY := "res://assets/textures/npc/ophelia/body_obsessed_lacing.png"
const LACING_FACE := "res://assets/textures/npc/ophelia/face_obsessed_lacing.png"
## Eco's red.
const ECO_RED := Color(0.72, 0.1, 0.1)
const ROSE := Color(1.0, 0.45, 0.68)


static func stage() -> int:
	if Obsession.meter >= KEEPER_AT:
		return 5
	if Obsession.meter >= LACING_AT:
		return 4
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
	_tint(npc, s >= 3, s >= 5)
	match s:
		1:
			npc.wear("upset")
			npc.rest_mood = ["sad", "lookaway"]
			npc.calm()
		2, 3, 4, 5:
			npc.wear("obsessed" if s >= 3 else "clingy")
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
			npc.rest_mood = ["down", "blush"] if s >= 3 else ["smile"]
			npc.calm()
			for spec in info.get("interactables", []):
				if spec.get("npc", "") == "ophelia":
					spec["pos"] = at
	_stare(npc, stare() if s >= 3 else 0.0)
	_pack(npc, s >= 3 and s < 5)
	npc.notice_range = WATCH_RANGE if s >= 3 else npc.NOTICE_RANGE
	npc.max_turn = WATCH_TURN if s >= 3 else npc.MAX_TURN
	_props(npc, s)
	_skin(npc, s >= 4)


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


## What she carries and wears at each stage, rebuilt each stay: a photo strip of Eco on her belt (obsessed on), a lighter on a
## cord and a candle on her step (lacing on), Eco's pilot patches and her
## titan key in hand (keeper).
static func _props(npc: Node3D, s: int) -> void:
	for old in npc.find_children("ObsessionProp*", "Node3D", true, false):
		old.get_parent().remove_child(old)
		old.queue_free()
	var skel := npc.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null or s < 2:
		return
	if s >= 3:
		# a strip of four photos of Eco, hanging off her belt on her right
		var strip := _on(skel, "J_Bip_C_Hips", Vector3(0.13, -0.06, -0.04))
		if strip != null:
			_box(strip, Vector3(0, -0.06, 0), Vector3(0.04, 0.14, 0.003), _flat(Color(0.95, 0.93, 0.88)))
			for i in 4:
				_box(strip, Vector3(0, -0.012 - i * 0.032, -0.002), Vector3(0.032, 0.026, 0.002), _flat(Color(0.55, 0.12, 0.1)))
	if s >= 4:
		# a lighter on a cord, and a candle burning on her step
		var cord := _on(skel, "J_Bip_C_UpperChest", Vector3(0, 0.0, -0.12))
		if cord != null:
			_box(cord, Vector3(0, -0.03, 0), Vector3(0.022, 0.036, 0.012), _flat(Color(0.85, 0.65, 0.25)))
			_box(cord, Vector3(0, 0.03, 0.01), Vector3(0.003, 0.08, 0.003), _flat(Color(0.1, 0.1, 0.1)))
		var candle := Node3D.new()
		candle.name = "ObsessionPropCandle"
		candle.position = Vector3(0.45, 0, -0.25)
		npc.add_child(candle)
		_box(candle, Vector3(0, 0.05, 0), Vector3(0.05, 0.1, 0.05), _flat(Color(0.92, 0.88, 0.8)))
		_box(candle, Vector3(0, 0.115, 0), Vector3(0.012, 0.025, 0.012), _flat(Color(1.0, 0.6, 0.2), 3.0))
		var flame := OmniLight3D.new()
		flame.position = Vector3(0, 0.16, 0)
		flame.light_color = Color(1.0, 0.6, 0.3)
		flame.light_energy = 0.6
		flame.omni_range = 1.6
		candle.add_child(flame)
	if s >= 5:
		# Eco's pilot patches on her shoulders, Eco's titan key in her hand
		for side in [["J_Bip_L_UpperArm", -1.0], ["J_Bip_R_UpperArm", 1.0]]:
			var patch := _on(skel, side[0], Vector3(0.06 * float(side[1]), 0.0, 0.0))
			if patch != null:
				_box(patch, Vector3.ZERO, Vector3(0.004, 0.04, 0.05), _flat(Color(0.9, 0.45, 0.1)))
		var key := _on(skel, "J_Bip_R_Hand", Vector3(0, -0.06, -0.02))
		if key != null:
			_box(key, Vector3(0, 0, 0), Vector3(0.03, 0.05, 0.01), _flat(Color(0.15, 0.15, 0.17)))
			_box(key, Vector3(0, -0.045, 0), Vector3(0.008, 0.04, 0.004), _flat(Color(0.75, 0.75, 0.78)))
			_box(key, Vector3(0, 0.012, -0.006), Vector3(0.01, 0.01, 0.002), _flat(Color(1.0, 0.3, 0.2), 2.0))


## The lacing textures (gold fingertips, the pen on her hand, dark circles)
## over her hoodie and face, or her own back. wear() puts her own back each
## stay; this only has to lay them on.
static func _skin(npc: Node3D, on: bool) -> void:
	if not on:
		return
	var swaps := {"npc_ophelia_body": LACING_BODY, "npc_ophelia_face": LACING_FACE}
	for mi in npc.find_children("*", "MeshInstance3D", true, false):
		var m3: MeshInstance3D = mi
		if m3.mesh == null:
			continue
		for i in m3.mesh.get_surface_count():
			var base := m3.mesh.surface_get_material(i)
			if base == null or not swaps.has(base.resource_name):
				continue
			var mine := m3.get_surface_override_material(i) as ShaderMaterial
			if mine == null:
				mine = base.duplicate()
				m3.set_surface_override_material(i, mine)
			mine.set_shader_parameter("albedo_tex", load(swaps[base.resource_name]))


## A prop holder on her bone, `at` metres off it, unscaled from the bone.
static func _on(skel: Skeleton3D, bone_name: String, at: Vector3) -> Node3D:
	var bone := skel.find_bone(bone_name)
	if bone < 0:
		return null
	var att := BoneAttachment3D.new()
	att.name = "ObsessionProp" + bone_name
	att.bone_name = bone_name
	skel.add_child(att)
	var sc := skel.get_bone_global_pose(bone).basis.get_scale()
	var holder := Node3D.new()
	holder.position = at
	holder.scale = Vector3(1.0 / maxf(sc.x, 0.001), 1.0 / maxf(sc.y, 0.001), 1.0 / maxf(sc.z, 0.001))
	att.add_child(holder)
	return holder


static func _box(parent: Node3D, at: Vector3, size: Vector3, m: Material, roll := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	mi.rotation_degrees.z = roll
	parent.add_child(mi)


static func _flat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


## Her hair streak and eyes, rose (or back to her own); at keeper (`all_red`)
## the rest of her hair goes Eco's red too.
static func _tint(npc: Node3D, rose: bool, all_red := false) -> void:
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
			var rest_hair := all_red and not hair and n.to_lower().contains("hair")
			if rest_hair:
				var dyed: ShaderMaterial = base.duplicate()
				dyed.set_meta("obsession", true)
				dyed.set_shader_parameter("albedo", ECO_RED)
				m3.set_surface_override_material(i, dyed)
				continue
			if not (hair or eye):
				# the rest of her hair: back to her own unless it's dyed
				if n.to_lower().contains("hair") and m3.get_surface_override_material(i) != null \
						and m3.get_surface_override_material(i).has_meta("obsession"):
					m3.set_surface_override_material(i, null)
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
