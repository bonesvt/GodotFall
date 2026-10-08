extends RefCounted
## How Ophelia looks as her obsession (obsession.gd) deepens, put on her hub
## model each stay (run_manager.gd enter_hub, after her idle is picked):
##   0 calm       as she is
##   1 upset      Eco left without saying goodbye: arms-crossed hurt, won't look
##   2 clingy     (meter CLINGY_AT) in the hoodie, waiting on her tent's doorstep
##                for Eco to come back, watching the path
##   3 obsessed   (meter OBSESSED_AT) yandere: the light gone out of her eyes
##                (no highlights, irises dark rose), eyes held wide and unblinking
##                over a sweet, too-wide smile, a flush on her cheeks, head
##                tilted; her violet streak burning hot rose against the black.
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
			npc.rest_mood = ["sad", "lookaway"]
			npc.calm()
		2, 3:
			npc.wear("hoodie")
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
			npc.rest_mood = ["tilt", "blush"] if s == 3 else ["sad"]
			npc.calm()
			for spec in info.get("interactables", []):
				if spec.get("npc", "") == "ophelia":
					spec["pos"] = at
	_stare(npc, stare() if s >= 3 else 0.0)


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
