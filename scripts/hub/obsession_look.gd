extends RefCounted
## How Ophelia looks as her obsession (obsession.gd) deepens, put on her hub
## model each stay (run_manager.gd enter_hub, after her idle is picked):
##   0 calm       as she is
##   1 upset      Eco left without saying goodbye: arms-crossed hurt, won't look
##   2 clingy     (meter CLINGY_AT) in the hoodie, waiting on her tent's doorstep
##                for Eco to come back, watching the path
##   3 obsessed   (meter OBSESSED_AT) her violet streak gone rose, a rose glow in
##                her eyes, a smile that's a little too wide
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
			npc.rest_mood = ["smile"] if s == 3 else ["sad"]
			npc.calm()
			for spec in info.get("interactables", []):
				if spec.get("npc", "") == "ophelia":
					spec["pos"] = at


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
			var hair := n.contains("hair")
			var eye := n.contains("eye") and not n.contains("white") and not n.contains("line") and not n.contains("brow")
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
				mine.set_shader_parameter("albedo", Color(col.r * 1.35, col.g * 0.7, col.b * 0.9, col.a))
				mine.set_shader_parameter("emission", ROSE * 0.35)
				mine.set_shader_parameter("emission_energy", 0.3)
			else:
				mine.set_shader_parameter("emission", ROSE)
				mine.set_shader_parameter("emission_energy", 0.6)
			m3.set_surface_override_material(i, mine)
